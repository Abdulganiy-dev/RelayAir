import Testing
import Foundation
@testable import RelayAirCore

/// End-to-end exercise of ``RelayLink``: real Bonjour discovery, real TLS-PSK,
/// real device authentication, real command routing — both ends in one process.
///
/// This needs working mDNS on the host. In a sandboxed CI runner without Local
/// Network access, discovery silently never resolves, which is exactly how the
/// permission failure presents in the apps too.
@Suite("RelayLink over Bonjour", .serialized)
struct RelayLinkTests {

    @Test("An enrolled client finds the listener and gets a reply", .timeLimit(.minutes(1)))
    @MainActor
    func pairedRoundTrip() async throws {
        guard let pair = await TestLink.connectedPair(handler: { command in
            switch command {
            case .ping: return .pong
            case .fill(let request): return .failed("saw fill: \(request.text)")
            default: return .failed("unexpected")
            }
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        #expect(try await pair.client.send(.ping, timeout: .seconds(10)) == .pong)
        #expect(pair.listener.state.isConnected)
    }

    @Test("Commands route to the handler and responses correlate", .timeLimit(.minutes(1)))
    @MainActor
    func commandRouting() async throws {
        guard let pair = await TestLink.connectedPair(handler: { command in
            guard case .fill(let request) = command else { return .failed("wrong command") }
            return .failed("echo:\(request.text)")
        }) else {
            Issue.record("The pair never connected")
            return
        }
        defer { pair.stop() }

        // Several in flight at once; each must get its own answer back.
        async let first = pair.client.send(.fill(FillRequest(text: "one")), timeout: .seconds(10))
        async let second = pair.client.send(.fill(FillRequest(text: "two")), timeout: .seconds(10))
        async let third = pair.client.send(.fill(FillRequest(text: "three")), timeout: .seconds(10))

        let results = try await [first, second, third]
        #expect(results == [.failed("echo:one"), .failed("echo:two"), .failed("echo:three")])
    }

    @Test("Sending without a pairing throws rather than hanging")
    @MainActor
    func unpairedSendFails() async {
        let client = RelayLink(role: .client)
        client.start(pairing: nil)
        defer { client.stop() }

        #expect(client.state == .unpaired)
        await #expect(throws: RelayLink.LinkError.notPaired) {
            try await client.send(.ping, timeout: .seconds(1))
        }
    }

    @Test("A client keyed to a different secret never connects", .timeLimit(.minutes(1)))
    @MainActor
    func mismatchedPairingNeverConnects() async throws {
        let macPairing = PairingPayload.generate(displayName: "Test Mac")
        let authority = TestAuthority()
        let device = authority.preEnroll()

        let listener = RelayLink(role: .listener)
        listener.authority = authority
        listener.commandHandler = { _ in .pong }
        listener.start(pairing: macPairing)
        defer { listener.stop() }

        // Same service name so it is found — but a different secret, so the TLS
        // handshake must fail before any application data exists.
        var impostorPairing = macPairing
        impostorPairing.secret = Data(repeating: 0xFF, count: 32)

        let client = RelayLink(role: .client)
        client.start(pairing: impostorPairing, credential: device.credential)
        defer { client.stop() }

        try? await Task.sleep(for: .seconds(15))
        #expect(!client.state.isConnected, "An unpaired client connected — the PSK is not being enforced")
    }
}
