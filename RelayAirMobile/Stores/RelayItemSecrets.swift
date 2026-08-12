//
//  RelayItemSecrets.swift
//  RelayAirMobile
//
//  The sensitive half of a relay item. One Keychain entry per item, holding the whole
//  `RelayItemDetails` as JSON, behind Face ID.
//
//  This is deliberately separate from RelayAirCore's `Keychain`, which is the Mac's
//  pairing store: different service, different accessibility, and different rules about
//  when the user has to authenticate. Nothing here belongs in Core.
//
//  The split against `RelayItem` is what keeps the wallet cheap: a row carries the tag,
//  the design and nothing private, so listing every card touches no Keychain entry and
//  raises no prompt. Only relaying or editing one asks for a face.
//

import Foundation
import LocalAuthentication
import OSLog
import RelayAirCore
import Security

enum RelayItemSecrets {

    enum Failure: Error {
        /// No entry for that id. A row whose details went missing — recoverable by
        /// re-entering them, so it is worth telling apart from a Keychain error.
        case notFound
        /// The user dismissed Face ID, or it failed. Not an error to report as a fault.
        case notAuthenticated
        /// The device has no passcode or biometrics, so a protected entry cannot be
        /// created at all.
        case protectionUnavailable
        case keychain(OSStatus)
        case coding
    }

    /// Distinct from Core's service string, so item details and the pairing credential
    /// can never collide or be swept up by each other's queries.
    private static let service = "com.ladulghanneey.RelayAir.ios.items"

    private static let prefix = "relayItem."

    private static let logger = Logger(
        subsystem: AppIdentifiers.loggingSubsystem,
        category: "ItemSecrets"
    )

    static func account(for id: UUID) -> String { prefix + id.uuidString }

    // MARK: - Write

    /// Stores the details for an item, replacing anything already there.
    ///
    /// Replace rather than `SecItemUpdate`: updating a presence-protected entry makes
    /// the system authenticate first, which would put a Face ID prompt in the middle of
    /// *saving* a card. Deleting does not authenticate, so delete-then-add keeps writes
    /// silent and leaves the prompt where it belongs — on the read.
    static func store(_ details: RelayItemDetails, for id: UUID) throws {
        guard let data = try? JSONEncoder().encode(details) else { throw Failure.coding }

        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            // Read only while the device is unlocked, and never carried to another device.
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            // Biometrics, and *only* biometrics. `.userPresence` — the obvious choice —
            // accepts the device passcode as an equal alternative, which is why unlocking a
            // card was asking for one.
            //
            // `.biometryAny` and not `.biometryCurrentSet`: the latter invalidates the
            // entry whenever the enrolled set changes, so re-enrolling Face ID would
            // silently destroy every saved card. This one survives that.
            .biometryAny,
            &accessError
        ) else {
            logger.error("Access control unavailable: \(String(describing: accessError))")
            throw Failure.protectionUnavailable
        }

        try? delete(for: id)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: id),
            kSecValueData as String: data,
            // Note: no `kSecAttrAccessible` alongside this — the access control carries
            // the accessibility, and passing both is rejected.
            kSecAttrAccessControl as String: access,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Store failed: \(status, privacy: .public)")
            throw Failure.keychain(status)
        }
    }

    // MARK: - Read

    /// Reads the details back, putting up the Face ID sheet on the way.
    ///
    /// `async` is not decoration. `SecItemCopyMatching` blocks its thread for as long as
    /// the sheet is up, so on the main thread the UI freezes *behind* the prompt. The
    /// work goes to a background queue and the caller suspends instead.
    static func load(for id: UUID, reason: String) async throws -> RelayItemDetails {
        let account = account(for: id)

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let context = LAContext()
                context.localizedReason = reason
                // Empty title removes the fallback button from the sheet. The access
                // control already refuses a passcode; without this the sheet still offers
                // one, and tapping it just fails.
                context.localizedFallbackTitle = ""

                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecUseAuthenticationContext as String: context,
                ]

                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)

                switch status {
                case errSecSuccess:
                    if let data = item as? Data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: Failure.coding)
                    }
                case errSecItemNotFound:
                    continuation.resume(throwing: Failure.notFound)
                case errSecUserCanceled, errSecAuthFailed:
                    continuation.resume(throwing: Failure.notAuthenticated)
                default:
                    logger.error("Load failed: \(status, privacy: .public)")
                    continuation.resume(throwing: Failure.keychain(status))
                }
            }
        }

        guard let details = try? JSONDecoder().decode(RelayItemDetails.self, from: data) else {
            throw Failure.coding
        }
        return details
    }

    // MARK: - Delete

    /// Deleting a protected entry does not authenticate, so this never prompts.
    static func delete(for id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: id),
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Delete failed: \(status, privacy: .public)")
            throw Failure.keychain(status)
        }
    }

    // MARK: - Sweep

    /// Every id that currently has an entry.
    ///
    /// This is what makes orphans a non-problem. It asks for *attributes* only — no
    /// `kSecReturnData` — and attribute queries do not authenticate, so the whole set
    /// can be listed and diffed against the table without a single Face ID prompt.
    static func storedIDs() -> Set<UUID> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            if status != errSecItemNotFound {
                logger.error("Enumerate failed: \(status, privacy: .public)")
            }
            return []
        }

        return Set(
            items.compactMap { item in
                guard let account = item[kSecAttrAccount as String] as? String,
                      account.hasPrefix(prefix)
                else { return nil }
                return UUID(uuidString: String(account.dropFirst(prefix.count)))
            }
        )
    }
}
