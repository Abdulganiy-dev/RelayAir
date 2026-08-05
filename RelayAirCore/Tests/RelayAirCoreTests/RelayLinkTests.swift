import Testing
import Foundation
@testable import RelayAirCore

/// End-to-end exercise of ``RelayLink``: real Bonjour discovery, real TLS-PSK,
/// real command routing — both ends inside one process.
///
/// This needs working mDNS on the host. In a sandboxed CI runner without Local
/// Network access, discovery silently never resolves, which is exactly how the
/// permission failure presents in the apps too.
@Suite("RelayLink over Bonjour", .serialized)
struct RelayLinkTests {

    @Test("A paired client finds the listener and gets a reply", .timeLimit(.minutes(1)))
    @MainActor
    func pairedRoundTrip() async throws {
        let pairing = PairingPayload.generate(displayName: "Test Mac")

        let listener = RelayLink(role: .listener)
        listener.commandHandler = { command in
            switch command {
            case .ping: return .pong
            case .fill(let request): return .failed("saw fill: \(request.text)")
            case .captureScreen: return .failed("no screen in tests")
            }
        }
        listener.start(pairing: pairing)
        defer { listener.stop() }

        let client = RelayLink(role: .client)
        client.start(pairing: pairing)
        defer { client.stop() }

        try await waitUntil("the client connects", timeout: 25) { client.state.isConnected }

        let response = try await client.send(.ping, timeout: .seconds(10))
        #expect(response == .pong)

        // The listener should see the connection from its side too.
        #expect(listener.state.isConnected)
    }

    @Test("Commands route to the handler and responses correlate", .timeLimit(.minutes(1)))
    @MainActor
    func commandRouting() async throws {
        let pairing = PairingPayload.generate(displayName: "Test Mac")

        let listener = RelayLink(role: .listener)
        listener.commandHandler = { command in
            guard case .fill(let request) = command else { return .failed("wrong command") }
            return .failed("echo:\(request.text)")
        }
        listener.start(pairing: pairing)
        defer { listener.stop() }

        let client = RelayLink(role: .client)
        client.start(pairing: pairing)
        defer { client.stop() }

        try await waitUntil("the client connects", timeout: 25) { client.state.isConnected }

        // Several in flight at once; each must get its own answer back.
        async let first = client.send(.fill(FillRequest(text: "one")), timeout: .seconds(10))
        async let second = client.send(.fill(FillRequest(text: "two")), timeout: .seconds(10))
        async let third = client.send(.fill(FillRequest(text: "three")), timeout: .seconds(10))

        let results = try await [first, second, third]
        #expect(results == [.failed("echo:one"), .failed("echo:two"), .failed("echo:three")])
    }

    @Test("Sending without a pairing throws rather than hanging")
    @MainActor
    func unpairedSendFails() async {
        let client = RelayLink(role: .client)
        client.start(pairing: nil)
        #expect(client.state == .unpaired)

        await #expect(throws: RelayLink.LinkError.notPaired) {
            try await client.send(.ping, timeout: .seconds(1))
        }
    }

    @Test("A client keyed to a different secret never connects", .timeLimit(.minutes(1)))
    @MainActor
    func mismatchedPairingNeverConnects() async throws {
        let macPairing = PairingPayload.generate(displayName: "Test Mac")

        let listener = RelayLink(role: .listener)
        listener.commandHandler = { _ in .pong }
        listener.start(pairing: macPairing)
        defer { listener.stop() }

        // Same service name, so it is found — but a different secret, so the
        // TLS handshake must fail.
        var impostorPairing = macPairing
        impostorPairing.secret = Data(repeating: 0xFF, count: 32)

        let client = RelayLink(role: .client)
        client.start(pairing: impostorPairing)
        defer { client.stop() }

        // Long enough to have connected if the PSK were not enforced.
        try? await Task.sleep(for: .seconds(15))
        #expect(!client.state.isConnected, "An unpaired client connected — the PSK is not being enforced")
    }
}

/// Polls `condition` until it holds or the deadline passes.
///
/// Network.framework reports readiness through callbacks rather than anything
/// awaitable, so polling is the honest way to wait on it.
@MainActor
private func waitUntil(
    _ what: String,
    timeout seconds: Double,
    interval: Duration = .milliseconds(100),
    _ condition: @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if condition() { return }
        try await Task.sleep(for: interval)
    }
    Issue.record("Timed out after \(seconds)s waiting for \(what)")
    throw CancellationError()
}
