import Testing
import Foundation
@testable import RelayAirCore

/// Command handling over a real link, now that approval lives on the phone.
///
/// The Mac acts on a `.fill` the moment it arrives — the user already said yes
/// before it was transmitted — so these cover prompt completion, isolation
/// between concurrent commands, and what happens when a handler misbehaves.
@Suite("Command handling", .serialized)
struct CommandHandlingTests {

    @Test("A fill is acted on immediately, without waiting on a person", .timeLimit(.minutes(1)))
    @MainActor
    func fillCompletesPromptly() async throws {
        guard let pair = await TestLink.connectedPair(handler: { command in
            guard case .fill = command else { return .failed("wrong command") }
            return .done
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        let started = Date()
        let response = try await pair.client.send(
            .fill(FillRequest(text: "hunter2")),
            timeout: .seconds(30)
        )
        let elapsed = Date().timeIntervalSince(started)

        #expect(response == .done)
        // Generous, but far below anything that implies a human was consulted.
        #expect(elapsed < 3, "A fill took \(elapsed)s — something is waiting that shouldn't be")
    }

    @Test("A failed fill reports why", .timeLimit(.minutes(1)))
    @MainActor
    func failureIsReported() async throws {
        guard let pair = await TestLink.connectedPair(handler: { _ in
            .failed("The Mac couldn't type into the focused field.")
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        let response = try await pair.client.send(
            .fill(FillRequest(text: "nope")),
            timeout: .seconds(30)
        )
        #expect(response == .failed("The Mac couldn't type into the focused field."))
    }

    @Test("A handler that never answers times out rather than hanging", .timeLimit(.minutes(1)))
    @MainActor
    func silenceTimesOut() async throws {
        guard let pair = await TestLink.connectedPair(handler: { _ in
            // Longer than the send timeout below, so the send has to give up.
            try? await Task.sleep(for: .seconds(30))
            return .done
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        await #expect(throws: RelayLink.LinkError.timedOut) {
            try await pair.client.send(.fill(FillRequest(text: "ignored")), timeout: .seconds(2))
        }
    }

    @Test("A slow command doesn't block unrelated ones", .timeLimit(.minutes(1)))
    @MainActor
    func slowCommandDoesNotBlockOthers() async throws {
        guard let pair = await TestLink.connectedPair(handler: { command in
            switch command {
            // Stands in for a screen capture, which genuinely takes a moment.
            case .captureScreen:
                try? await Task.sleep(for: .seconds(2))
                return .failed("no screen in tests")
            case .ping:
                return .pong
            default:
                return .done
            }
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        let slow = Task { try await pair.client.send(.captureScreen, timeout: .seconds(30)) }
        try await Task.sleep(for: .milliseconds(300))

        // The quick one must not queue behind the slow one.
        let started = Date()
        #expect(try await pair.client.send(.ping, timeout: .seconds(10)) == .pong)
        #expect(Date().timeIntervalSince(started) < 1.5)

        _ = try await slow.value
    }

    @Test("Concurrent fills each get their own answer", .timeLimit(.minutes(1)))
    @MainActor
    func concurrentFillsCorrelate() async throws {
        guard let pair = await TestLink.connectedPair(handler: { command in
            guard case .fill(let request) = command else { return .failed("wrong command") }
            return .failed("echo:\(request.text)")
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        async let first = pair.client.send(.fill(FillRequest(text: "one")), timeout: .seconds(20))
        async let second = pair.client.send(.fill(FillRequest(text: "two")), timeout: .seconds(20))
        async let third = pair.client.send(.fill(FillRequest(text: "three")), timeout: .seconds(20))

        let results = try await [first, second, third]
        #expect(results == [.failed("echo:one"), .failed("echo:two"), .failed("echo:three")])
    }
}
