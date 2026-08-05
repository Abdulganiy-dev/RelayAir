import Testing
import Foundation
@testable import RelayAirCore

/// Exercises the shape of the approval gate over a real link: the Mac holds the
/// `.fill` response open until a decision is made, so the phone learns the true
/// outcome instead of an optimistic "delivered".
///
/// The Mac's real gate lives in `RelayController`, which is in the app target.
/// This stands in a handler with the same contract — respond only after the
/// decision — to prove the transport tolerates a slow, user-paced reply.
@Suite("Approval gate", .serialized)
struct ApprovalGateTests {

    /// A decision made some time after the command arrives.
    private actor Decision {
        private var continuation: CheckedContinuation<RelayResponse, Never>?
        private var queued: RelayResponse?

        func awaitDecision() async -> RelayResponse {
            if let queued {
                self.queued = nil
                return queued
            }
            return await withCheckedContinuation { continuation = $0 }
        }

        func resolve(_ response: RelayResponse) {
            if let continuation {
                self.continuation = nil
                continuation.resume(returning: response)
            } else {
                queued = response
            }
        }
    }

    @MainActor
    private func connectedPair(
        handler: @escaping @MainActor (RelayCommand) async -> RelayResponse
    ) async throws -> (listener: RelayLink, client: RelayLink) {
        let pairing = PairingPayload.generate(displayName: "Test Mac")

        let listener = RelayLink(role: .listener)
        listener.commandHandler = handler
        listener.start(pairing: pairing)

        let client = RelayLink(role: .client)
        client.start(pairing: pairing)

        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline && !client.state.isConnected {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard client.state.isConnected else {
            listener.stop(); client.stop()
            Issue.record("The pair never connected")
            throw CancellationError()
        }
        return (listener, client)
    }

    @Test("An approved fill reports .done, not before the decision", .timeLimit(.minutes(1)))
    @MainActor
    func approvalReportsDone() async throws {
        let decision = Decision()
        let (listener, client) = try await connectedPair { command in
            guard case .fill = command else { return .failed("wrong command") }
            return await decision.awaitDecision()
        }
        defer { listener.stop(); client.stop() }

        let sendTask = Task { try await client.send(.fill(FillRequest(text: "hunter2")), timeout: .seconds(30)) }

        // The phone must still be waiting a beat later — no optimistic success.
        try await Task.sleep(for: .milliseconds(600))
        #expect(!sendTask.isCancelled)

        await decision.resolve(.done)
        #expect(try await sendTask.value == .done)
    }

    @Test("A rejected fill reports .rejected", .timeLimit(.minutes(1)))
    @MainActor
    func rejectionIsReported() async throws {
        let decision = Decision()
        let (listener, client) = try await connectedPair { _ in await decision.awaitDecision() }
        defer { listener.stop(); client.stop() }

        let sendTask = Task { try await client.send(.fill(FillRequest(text: "nope")), timeout: .seconds(30)) }
        try await Task.sleep(for: .milliseconds(300))
        await decision.resolve(.rejected)

        #expect(try await sendTask.value == .rejected)
    }

    @Test("A decision that never comes times out rather than hanging", .timeLimit(.minutes(1)))
    @MainActor
    func silenceTimesOut() async throws {
        let decision = Decision()  // deliberately never resolved
        let (listener, client) = try await connectedPair { _ in await decision.awaitDecision() }
        defer { listener.stop(); client.stop() }

        await #expect(throws: RelayLink.LinkError.timedOut) {
            try await client.send(.fill(FillRequest(text: "ignored")), timeout: .seconds(2))
        }
    }

    @Test("A screenshot is unaffected by a fill waiting on approval", .timeLimit(.minutes(1)))
    @MainActor
    func otherCommandsAreNotBlocked() async throws {
        let decision = Decision()
        let (listener, client) = try await connectedPair { command in
            switch command {
            case .fill: return await decision.awaitDecision()
            case .ping: return .pong
            case .captureScreen: return .failed("no screen in tests")
            }
        }
        defer { listener.stop(); client.stop() }

        let blocked = Task { try await client.send(.fill(FillRequest(text: "waiting")), timeout: .seconds(30)) }
        try await Task.sleep(for: .milliseconds(300))

        // A pending approval must not stall unrelated traffic.
        #expect(try await client.send(.ping, timeout: .seconds(10)) == .pong)

        await decision.resolve(.done)
        #expect(try await blocked.value == .done)
    }
}
