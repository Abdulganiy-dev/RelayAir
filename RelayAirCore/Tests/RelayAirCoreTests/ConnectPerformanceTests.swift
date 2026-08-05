import Testing
import Foundation
@testable import RelayAirCore

/// Guards against pairing and reconnection getting slow.
///
/// The numbers are printed as well as asserted, so a regression shows *where*
/// the time went rather than just that a bound was breached.
@Suite("Connect performance", .serialized)
struct ConnectPerformanceTests {

    /// Times discovery + TLS + authentication for an already-enrolled device.
    @MainActor
    private func timeConnect(credential: DeviceCredential?, authority: TestAuthority) async -> (total: Double, connected: Bool) {
        let pairing = PairingPayload.generate(displayName: "Test Mac")

        let listener = RelayLink(role: .listener)
        listener.authority = authority
        listener.commandHandler = { _ in .done }
        listener.start(pairing: pairing)
        defer { listener.stop() }

        let client = RelayLink(role: .client)
        let started = Date()
        client.start(pairing: pairing, credential: credential, deviceName: "Bench iPhone")
        defer { client.stop() }

        let deadline = started.addingTimeInterval(30)
        while Date() < deadline && !client.state.isConnected {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return (Date().timeIntervalSince(started), client.state.isConnected)
    }

    @Test("A returning device reconnects quickly", .timeLimit(.minutes(1)))
    @MainActor
    func reconnectIsFast() async throws {
        let authority = TestAuthority(acceptingNewDevices: false)
        let device = authority.preEnroll()

        var samples: [Double] = []
        for _ in 0..<3 {
            let result = await timeConnect(credential: device.credential, authority: authority)
            #expect(result.connected)
            samples.append(result.total)
        }

        let best = samples.min() ?? .infinity
        let median = samples.sorted()[samples.count / 2]
        print("  reconnect: best \(String(format: "%.2f", best))s, median \(String(format: "%.2f", median))s, samples \(samples.map { String(format: "%.2f", $0) })")

        #expect(best < 5.0, "Reconnect took \(best)s at best — discovery or the handshake has regressed")
    }

    @Test("First-time pairing completes quickly", .timeLimit(.minutes(1)))
    @MainActor
    func firstPairingIsFast() async throws {
        let authority = TestAuthority(acceptingNewDevices: true)

        var samples: [Double] = []
        for _ in 0..<3 {
            let result = await timeConnect(credential: nil, authority: authority)
            #expect(result.connected)
            samples.append(result.total)
        }

        let best = samples.min() ?? .infinity
        print("  first pairing: best \(String(format: "%.2f", best))s, samples \(samples.map { String(format: "%.2f", $0) })")

        // Enrolment adds one round trip over reconnect; on a LAN that's noise.
        #expect(best < 6.0, "First pairing took \(best)s at best")
    }

    @Test("Enrolment costs about one extra round trip, not seconds", .timeLimit(.minutes(1)))
    @MainActor
    func enrolmentOverheadIsSmall() async throws {
        let enrolling = TestAuthority(acceptingNewDevices: true)
        let returning = TestAuthority(acceptingNewDevices: false)
        let device = returning.preEnroll()

        let first = await timeConnect(credential: nil, authority: enrolling)
        let repeat_ = await timeConnect(credential: device.credential, authority: returning)

        let overhead = first.total - repeat_.total
        print("  enrolment overhead: \(String(format: "%.2f", overhead))s")

        // If the two-layer handshake were the bottleneck, this would be large.
        #expect(abs(overhead) < 2.0, "Enrolment added \(overhead)s — the handshake is the bottleneck")
    }
}
