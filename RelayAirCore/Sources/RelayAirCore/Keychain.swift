import Foundation
import Security
import OSLog

/// Minimal Keychain wrapper for the app's own secrets.
///
/// Everything here is `ThisDeviceOnly` and never synced: a pairing is between
/// two specific machines, so carrying it to a restored device would silently
/// widen who can drive the Mac.
enum Keychain {

    private static let service = "com.ladulghanneey.RelayAir"
    private static let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Keychain")

    static func loadData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error("Read of \(account, privacy: .public) failed: \(status, privacy: .public)")
            }
            return nil
        }
        return item as? Data
    }

    @discardableResult
    static func save(_ data: Data, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else {
            logger.error("Update of \(account, privacy: .public) failed: \(updateStatus, privacy: .public)")
            return false
        }

        let addStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("Add of \(account, privacy: .public) failed: \(addStatus, privacy: .public)")
        }
        return addStatus == errSecSuccess
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Codable convenience

    static func load<T: Decodable>(_ type: T.Type, account: String) -> T? {
        guard let data = loadData(account: account) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    @discardableResult
    static func save<T: Encodable>(_ value: T, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return save(data, account: account)
    }
}
