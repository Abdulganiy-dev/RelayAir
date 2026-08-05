import Testing
import Foundation
@testable import RelayAirCore

/// End-to-end enrolment and revocation over a real link.
@Suite("Enrolment and revocation", .serialized)
@MainActor
final class EnrolmentTests {

    private var links: [RelayLink] = []

    deinit {
        // `links` is main-actor state; capture the array first.
        let toStop = links
        Task { @MainActor in toStop.forEach { $0.stop() } }
    }

    private func makeListener(_ authority: TestAuthority, pairing: PairingPayload) -> RelayLink {
        let listener = RelayLink(role: .listener)
        listener.authority = authority
        listener.commandHandler = { command in
            if case .ping = command { return .pong }
            return .failed("unexpected")
        }
        listener.start(pairing: pairing)
        links.append(listener)
        return listener
    }

    private func makeClient(
        pairing: PairingPayload,
        credential: DeviceCredential?,
        name: String = "Test iPhone"
    ) -> RelayLink {
        let client = RelayLink(role: .client)
        client.start(pairing: pairing, credential: credential, deviceName: name)
        links.append(client)
        return client
    }

    private func wait(
        upTo seconds: Double = 25,
        for condition: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test("A new phone enrols while the code is showing and gets a credential", .timeLimit(.minutes(1)))
    func enrolsInPairingMode() async throws {
        let pairing = PairingPayload.generate(displayName: "Test Mac")
        let authority = TestAuthority()
        authority.isAcceptingNewDevices = true

        let listener = makeListener(authority, pairing: pairing)

        var issued: DeviceCredential?
        let client = RelayLink(role: .client)
        client.onEnrolled = { issued = $0 }
        client.start(pairing: pairing, credential: nil, deviceName: "Abdul's iPhone")
        links.append(client)

        await wait { client.state.isConnected }

        #expect(client.state.isConnected)
        #expect(issued != nil)
        #expect(authority.records.count == 1)
        #expect(authority.records.first?.name == "Abdul's iPhone")
        #expect(listener.state.isConnected)

        // The phone can now actually do something.
        #expect(try await client.send(.ping, timeout: .seconds(10)) == .pong)
    }

    @Test("A new phone is refused when the code isn't showing", .timeLimit(.minutes(1)))
    func refusedOutsidePairingMode() async throws {
        let pairing = PairingPayload.generate(displayName: "Test Mac")
        let authority = TestAuthority()
        // The Mac is running but nobody is looking at the pairing code.
        authority.isAcceptingNewDevices = false

        _ = makeListener(authority, pairing: pairing)
        let client = makeClient(pairing: pairing, credential: nil)

        await wait(upTo: 12) { client.state.isConnected }

        #expect(!client.state.isConnected, "A phone enrolled while the Mac wasn't in pairing mode")
        #expect(authority.records.isEmpty)
    }

    @Test("An unpaired phone is refused even though it still has the QR secret", .timeLimit(.minutes(1)))
    func revokedDeviceIsRefused() async throws {
        let pairing = PairingPayload.generate(displayName: "Test Mac")
        let authority = TestAuthority()
        let record = DeviceRecord(
            id: UUID(), name: "Old iPhone", key: DeviceAuth.newDeviceKey(),
            enrolledAt: Date(), lastSeenAt: Date()
        )
        authority.records = [record]
        // Enrolment is closed, so it can't simply re-enrol.
        authority.isAcceptingNewDevices = false

        _ = makeListener(authority, pairing: pairing)

        // The device still holds the pairing secret, so TLS will succeed.
        authority.revokeAll()
        let client = makeClient(pairing: pairing, credential: record.credential)

        await wait(upTo: 12) { client.state.isConnected }

        #expect(!client.state.isConnected, "A revoked device connected")
        await #expect(throws: RelayLink.LinkError.notConnected) {
            try await client.send(.ping, timeout: .seconds(3))
        }
    }

    @Test("An authenticated phone stays usable across commands", .timeLimit(.minutes(1)))
    func authenticatedDevicePersists() async throws {
        let pairing = PairingPayload.generate(displayName: "Test Mac")
        let authority = TestAuthority()
        let record = DeviceRecord(
            id: UUID(), name: "Good iPhone", key: DeviceAuth.newDeviceKey(),
            enrolledAt: Date(), lastSeenAt: Date()
        )
        authority.records = [record]
        authority.isAcceptingNewDevices = false

        _ = makeListener(authority, pairing: pairing)
        let client = makeClient(pairing: pairing, credential: record.credential, name: "Good iPhone")

        await wait { client.state.isConnected }
        #expect(client.state.isConnected)

        for _ in 0..<3 {
            #expect(try await client.send(.ping, timeout: .seconds(10)) == .pong)
        }
        #expect(authority.seen.first?.1 == "Good iPhone")
    }
}
