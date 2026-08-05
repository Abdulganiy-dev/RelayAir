import Foundation
@testable import RelayAirCore

/// Stand-in for the Mac's `PairingManager` in tests.
@MainActor
final class TestAuthority: RelayLink.DeviceAuthority {
    var records: [DeviceRecord] = []
    var isAcceptingNewDevices = true
    private(set) var seen: [(id: UUID, name: String)] = []

    init(acceptingNewDevices: Bool = true) {
        self.isAcceptingNewDevices = acceptingNewDevices
    }

    func key(for deviceID: UUID) -> Data? {
        records.first { $0.id == deviceID }?.key
    }

    func enroll(name: String) -> DeviceCredential? {
        let record = DeviceRecord(
            id: UUID(), name: name, key: DeviceAuth.newDeviceKey(),
            enrolledAt: Date(), lastSeenAt: Date()
        )
        records.append(record)
        return record.credential
    }

    func markSeen(deviceID: UUID, name: String) {
        seen.append((deviceID, name))
    }

    /// Pre-enrols a device without going over the wire.
    func preEnroll(name: String = "Test iPhone") -> DeviceRecord {
        let record = DeviceRecord(
            id: UUID(), name: name, key: DeviceAuth.newDeviceKey(),
            enrolledAt: Date(), lastSeenAt: Date()
        )
        records.append(record)
        return record
    }

    func revokeAll() { records.removeAll() }
}

/// A listener and a client, already connected and authenticated.
@MainActor
struct ConnectedPair {
    let listener: RelayLink
    let client: RelayLink
    let authority: TestAuthority
    let device: DeviceRecord

    func stop() {
        listener.stop()
        client.stop()
    }
}

@MainActor
enum TestLink {

    /// Brings up an authenticated pair, or returns `nil` if they never connect.
    ///
    /// The device is pre-enrolled so tests exercise the command path rather
    /// than re-testing enrolment each time.
    static func connectedPair(
        handler: @escaping @MainActor (RelayCommand) async -> RelayResponse,
        timeout: Double = 25
    ) async -> ConnectedPair? {
        let pairing = PairingPayload.generate(displayName: "Test Mac")
        let authority = TestAuthority(acceptingNewDevices: false)
        let device = authority.preEnroll()

        let listener = RelayLink(role: .listener)
        listener.authority = authority
        listener.commandHandler = handler
        listener.start(pairing: pairing)

        let client = RelayLink(role: .client)
        client.start(pairing: pairing, credential: device.credential, deviceName: device.name)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline && !client.state.isConnected {
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard client.state.isConnected else {
            listener.stop()
            client.stop()
            return nil
        }
        return ConnectedPair(listener: listener, client: client, authority: authority, device: device)
    }
}
