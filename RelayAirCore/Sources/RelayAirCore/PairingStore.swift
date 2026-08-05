import Foundation

/// Keychain-backed storage for pairing state.
///
/// Three separate items, because the two ends keep different things:
///
/// - **Mac**: its own ``PairingPayload`` (the QR secret) plus the
///   ``DeviceRecord`` list of every enrolled phone.
/// - **Phone**: the Mac's ``PairingPayload`` it scanned, plus the
///   ``DeviceCredential`` the Mac issued it.
public enum PairingStore {

    private enum Account {
        static let pairing = "pairing.primary"
        static let credential = "pairing.credential"
        static let devices = "pairing.devices"
    }

    // MARK: - Pairing payload (both ends)

    public static func load() -> PairingPayload? {
        Keychain.load(PairingPayload.self, account: Account.pairing)
    }

    @discardableResult
    public static func save(_ payload: PairingPayload) -> Bool {
        Keychain.save(payload, account: Account.pairing)
    }

    @discardableResult
    public static func clear() -> Bool {
        Keychain.delete(account: Account.pairing)
            && Keychain.delete(account: Account.credential)
    }

    // MARK: - Device credential (phone)

    /// The credential this phone was issued when it enrolled.
    public static func loadCredential() -> DeviceCredential? {
        Keychain.load(DeviceCredential.self, account: Account.credential)
    }

    @discardableResult
    public static func saveCredential(_ credential: DeviceCredential) -> Bool {
        Keychain.save(credential, account: Account.credential)
    }

    // MARK: - Enrolled devices (Mac)

    public static func loadDevices() -> [DeviceRecord] {
        Keychain.load([DeviceRecord].self, account: Account.devices) ?? []
    }

    @discardableResult
    public static func saveDevices(_ devices: [DeviceRecord]) -> Bool {
        Keychain.save(devices, account: Account.devices)
    }

    @discardableResult
    public static func clearDevices() -> Bool {
        Keychain.delete(account: Account.devices)
    }
}
