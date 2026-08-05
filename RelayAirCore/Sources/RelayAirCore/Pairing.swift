import Foundation
import CryptoKit

/// Everything the iPhone needs to find and authenticate one specific Mac.
///
/// The Mac generates this once, renders it as a QR code, and the iPhone scans
/// it. The `secret` becomes the TLS pre-shared key, so a device that has not
/// scanned the code cannot complete the handshake — it is not merely refused
/// after connecting, it never gets a connection at all.
public struct PairingPayload: Codable, Hashable, Sendable {
    /// Format version, so a future change can be detected rather than misparsed.
    public static let currentVersion = 1

    public var version: Int
    /// Bonjour instance name the Mac advertises under.
    public var serviceName: String
    /// Human-readable Mac name, shown on the phone after pairing.
    public var displayName: String
    /// 256 bits of shared entropy. Never leaves the two devices.
    public var secret: Data

    public init(version: Int = PairingPayload.currentVersion, serviceName: String, displayName: String, secret: Data) {
        self.version = version
        self.serviceName = serviceName
        self.displayName = displayName
        self.secret = secret
    }

    /// Mints a fresh pairing for this Mac. Call once, then persist.
    public static func generate(displayName: String) -> PairingPayload {
        PairingPayload(
            // A random instance name keeps the Mac from being trivially
            // identifiable on the network by its hostname.
            serviceName: "relay-" + randomBytes(6).base32Lowercase(),
            displayName: displayName,
            secret: randomBytes(32)
        )
    }

    public var symmetricKey: SymmetricKey { SymmetricKey(data: secret) }

    // MARK: - QR representation

    /// URL form carried by the QR code:
    /// `relayair://pair?v=1&s=<service>&n=<name>&k=<base64url secret>`
    public var qrURL: URL {
        var components = URLComponents()
        components.scheme = "relayair"
        components.host = "pair"
        components.queryItems = [
            URLQueryItem(name: "v", value: String(version)),
            URLQueryItem(name: "s", value: serviceName),
            URLQueryItem(name: "n", value: displayName),
            URLQueryItem(name: "k", value: secret.base64URLEncodedString()),
        ]
        // Force-unwrap is safe: every component above is either a literal or
        // percent-encoded by URLComponents.
        return components.url!
    }

    public enum ParseError: LocalizedError {
        case notARelayAirCode
        case unsupportedVersion(Int)
        case malformed

        public var errorDescription: String? {
            switch self {
            case .notARelayAirCode: "That isn't a Relay Air pairing code."
            case .unsupportedVersion(let version): "This code uses format v\(version), which this app doesn't understand."
            case .malformed: "That pairing code is damaged or incomplete."
            }
        }
    }

    /// Parses a scanned string back into a payload.
    public static func parse(_ string: String) throws -> PairingPayload {
        guard let components = URLComponents(string: string),
              components.scheme == "relayair",
              components.host == "pair"
        else { throw ParseError.notARelayAirCode }

        let items = Dictionary(
            (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        let version = items["v"].flatMap(Int.init) ?? 0
        guard version == currentVersion else { throw ParseError.unsupportedVersion(version) }

        guard let serviceName = items["s"], !serviceName.isEmpty,
              let encodedKey = items["k"],
              let secret = Data(base64URLEncoded: encodedKey),
              secret.count == 32
        else { throw ParseError.malformed }

        return PairingPayload(
            version: version,
            serviceName: serviceName,
            displayName: items["n"] ?? "Mac",
            secret: secret
        )
    }

    // MARK: - Randomness

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with \(status)")
        return Data(bytes)
    }
}

// MARK: - Encoding helpers

extension Data {
    /// base64url (RFC 4648 §5): URL-safe alphabet, no padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Restore the padding base64url strips.
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }

    /// Lowercase base32-ish encoding, for a Bonjour name that survives DNS.
    func base32Lowercase() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
        return String(map { alphabet[Int($0 % 32)] })
    }
}
