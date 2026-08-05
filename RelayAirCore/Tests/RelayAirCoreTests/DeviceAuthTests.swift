import Testing
import Foundation
@testable import RelayAirCore

/// Covers the per-device layer that makes "Unpair this iPhone" enforceable.
///
/// The QR secret only keys TLS — it says two devices have met, not *which*
/// device this is. Identity comes from a key the Mac mints per device and can
/// delete, which these tests exercise.
@Suite("Device authentication")
struct DeviceAuthTests {

    private func makeRecord(name: String = "Test iPhone") -> DeviceRecord {
        DeviceRecord(
            id: UUID(),
            name: name,
            key: DeviceAuth.newDeviceKey(),
            enrolledAt: Date(),
            lastSeenAt: Date()
        )
    }

    @Test("A device's own proof verifies")
    func validProof() {
        let record = makeRecord()
        let proof = DeviceAuth.makeProof(credential: record.credential, deviceName: record.name)
        #expect(DeviceAuth.verify(proof, key: record.key) == .valid)
    }

    @Test("Revoking a device makes its proof stop verifying")
    func revokedDeviceFails() {
        let record = makeRecord()
        let proof = DeviceAuth.makeProof(credential: record.credential, deviceName: record.name)

        // Revocation is the Mac forgetting the key, so lookup returns nil.
        #expect(DeviceAuth.verify(proof, key: nil) == .unknownDevice)
    }

    @Test("One device cannot impersonate another")
    func noCrossDeviceImpersonation() {
        let alice = makeRecord(name: "Alice's iPhone")
        let mallory = makeRecord(name: "Mallory's iPhone")

        // Mallory claims Alice's id but can only sign with her own key.
        let forged = DeviceAuth.makeProof(
            credential: DeviceCredential(deviceID: alice.id, key: mallory.key),
            deviceName: "Alice's iPhone"
        )
        #expect(DeviceAuth.verify(forged, key: alice.key) == .badSignature)
    }

    @Test("Knowing the QR secret does not let you forge a device")
    func qrSecretDoesNotGrantIdentity() {
        // The whole point of not deriving device keys from the pairing secret.
        let pairing = PairingPayload.generate(displayName: "Mac")
        let record = makeRecord()

        let forged = DeviceAuth.makeProof(
            credential: DeviceCredential(deviceID: record.id, key: pairing.secret),
            deviceName: record.name
        )
        #expect(DeviceAuth.verify(forged, key: record.key) == .badSignature)
    }

    @Test("A tampered MAC is rejected")
    func tamperedMACFails() {
        let record = makeRecord()
        var proof = DeviceAuth.makeProof(credential: record.credential, deviceName: record.name)
        proof.mac[0] ^= 0x01
        #expect(DeviceAuth.verify(proof, key: record.key) == .badSignature)
    }

    @Test("An old proof is rejected once it falls outside the tolerance")
    func staleProofFails() {
        let record = makeRecord()
        let old = Date().addingTimeInterval(-(DeviceAuth.clockTolerance + 60))
        let proof = DeviceAuth.makeProof(
            credential: record.credential,
            deviceName: record.name,
            issuedAt: old
        )
        #expect(DeviceAuth.verify(proof, key: record.key) == .staleTimestamp)
    }

    @Test("A proof from a slightly-off clock still verifies")
    func smallClockSkewIsTolerated() {
        let record = makeRecord()
        for offset in [-30.0, -5.0, 5.0, 30.0] {
            let proof = DeviceAuth.makeProof(
                credential: record.credential,
                deviceName: record.name,
                issuedAt: Date().addingTimeInterval(offset)
            )
            #expect(DeviceAuth.verify(proof, key: record.key) == .valid, "offset \(offset)s should be tolerated")
        }
    }

    @Test("Proofs survive the JSON round trip they take on the wire")
    func proofSurvivesEncoding() throws {
        let record = makeRecord()
        let proof = DeviceAuth.makeProof(credential: record.credential, deviceName: record.name)

        let message = RelayMessage.command(.authenticate(proof))
        let decoded = try RelayMessage.decode(message.encoded())
        guard case .command(.authenticate(let received)) = decoded.payload else {
            Issue.record("Expected an authenticate command")
            return
        }
        #expect(DeviceAuth.verify(received, key: record.key) == .valid)
    }

    @Test("Every minted device key is distinct")
    func keysAreUnique() {
        let keys = (0..<100).map { _ in DeviceAuth.newDeviceKey() }
        #expect(Set(keys).count == 100)
        #expect(keys.allSatisfy { $0.count == 32 })
    }
}
