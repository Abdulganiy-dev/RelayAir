import Foundation
import Security
import OSLog

/// Keychain-backed storage for the pairing secret.
///
/// The secret is the only thing standing between a stranger on the network and
/// your Mac's keyboard, so it lives in the Keychain rather than
/// `UserDefaults` — encrypted at rest and excluded from backups that would
/// carry it to another device.
///
/// The Mac app is unsandboxed, so it uses the default Keychain without needing
/// a keychain-access-group entitlement. iOS uses the app's own keychain.
public enum PairingStore {

    private static let service = "com.ladulghanneey.RelayAir.pairing"
    private static let account = "primary"
    private static let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "PairingStore")

    /// Reads the stored pairing, or `nil` if the devices have never been paired.
    public static func load() -> PairingPayload? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                logger.error("Keychain read failed: \(status, privacy: .public)")
            }
            return nil
        }

        return try? JSONDecoder().decode(PairingPayload.self, from: data)
    }

    /// Writes (or replaces) the stored pairing.
    @discardableResult
    public static func save(_ payload: PairingPayload) -> Bool {
        guard let data = try? JSONEncoder().encode(payload) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Never syncs to iCloud and never leaves this device — a pairing is
        // between two specific machines.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        guard updateStatus == errSecItemNotFound else {
            logger.error("Keychain update failed: \(updateStatus, privacy: .public)")
            return false
        }

        let addStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("Keychain add failed: \(addStatus, privacy: .public)")
        }
        return addStatus == errSecSuccess
    }

    /// Forgets the pairing. Both devices have to re-scan afterwards.
    @discardableResult
    public static func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
