import Foundation
import CryptoKit

/// What the phone keeps after enrolling: its own identity and the key the Mac
/// issued it.
///
/// This is deliberately **not** derived from the QR secret. If it were, anyone
/// holding the QR secret could forge any device's identity, and "unpair this
/// iPhone" would be unenforceable. The Mac mints a fresh random key per device
/// and stores its copy; revoking is deleting the Mac's copy.
public struct DeviceCredential: Codable, Hashable, Sendable {
    public var deviceID: UUID
    /// 32 random bytes issued by the Mac.
    public var key: Data

    public init(deviceID: UUID, key: Data) {
        self.deviceID = deviceID
        self.key = key
    }
}

/// The Mac's record of one enrolled phone.
public struct DeviceRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// The Mac's copy of the device's key. Deleting this record revokes it.
    public var key: Data
    public var enrolledAt: Date
    public var lastSeenAt: Date

    public init(id: UUID, name: String, key: Data, enrolledAt: Date, lastSeenAt: Date) {
        self.id = id
        self.name = name
        self.key = key
        self.enrolledAt = enrolledAt
        self.lastSeenAt = lastSeenAt
    }

    public var credential: DeviceCredential {
        DeviceCredential(deviceID: id, key: key)
    }
}

/// A phone's claim to be a particular enrolled device.
///
/// Sent as the first command on every connection. The MAC covers the device id
/// and a timestamp, so a captured proof can't be replayed indefinitely.
public struct DeviceProof: Codable, Hashable, Sendable {
    public var deviceID: UUID
    public var deviceName: String
    public var issuedAt: Date
    public var mac: Data

    public init(deviceID: UUID, deviceName: String, issuedAt: Date, mac: Data) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.issuedAt = issuedAt
        self.mac = mac
    }
}

/// Builds and checks ``DeviceProof``s.
public enum DeviceAuth {

    /// Domain-separation label, so this MAC can't be confused with the PSK one.
    private static let label = "RelayAir-device-auth-v1"

    /// How far out of step a proof's clock may be. Generous enough for two
    /// devices that haven't synced recently, tight enough to bound replay.
    public static let clockTolerance: TimeInterval = 120

    public static func makeProof(
        credential: DeviceCredential,
        deviceName: String,
        issuedAt: Date = Date()
    ) -> DeviceProof {
        let mac = HMAC<SHA256>.authenticationCode(
            for: signedBytes(deviceID: credential.deviceID, issuedAt: issuedAt),
            using: SymmetricKey(data: credential.key)
        )
        return DeviceProof(
            deviceID: credential.deviceID,
            deviceName: deviceName,
            issuedAt: issuedAt,
            mac: Data(mac)
        )
    }

    public enum Verdict: Equatable, Sendable {
        case valid
        /// No such device, or it has been unpaired.
        case unknownDevice
        case badSignature
        case staleTimestamp
    }

    /// Checks `proof` against the key the Mac holds for that device.
    ///
    /// - Parameter key: `nil` when the device is unknown or revoked.
    public static func verify(
        _ proof: DeviceProof,
        key: Data?,
        now: Date = Date()
    ) -> Verdict {
        guard let key else { return .unknownDevice }

        guard abs(now.timeIntervalSince(proof.issuedAt)) <= clockTolerance else {
            return .staleTimestamp
        }

        // `isValidAuthenticationCode` compares in constant time; a plain `==`
        // on Data would leak timing.
        let matches = HMAC<SHA256>.isValidAuthenticationCode(
            proof.mac,
            authenticating: signedBytes(deviceID: proof.deviceID, issuedAt: proof.issuedAt),
            using: SymmetricKey(data: key)
        )
        return matches ? .valid : .badSignature
    }

    /// Fresh key material for a newly enrolled device.
    public static func newDeviceKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with \(status)")
        return Data(bytes)
    }

    private static func signedBytes(deviceID: UUID, issuedAt: Date) -> Data {
        var data = Data(label.utf8)
        data.append(Data(deviceID.uuidString.utf8))
        // Whole seconds, so both sides sign an identical representation.
        data.append(Data(String(Int(issuedAt.timeIntervalSince1970)).utf8))
        return data
    }
}
