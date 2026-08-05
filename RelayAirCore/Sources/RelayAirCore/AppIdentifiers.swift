import Foundation

/// Identifiers shared by the Mac receiver and the iPhone sender.
public enum AppIdentifiers {
    public static let macBundleID = "com.ladulghanneey.RelayAir"
    public static let iOSBundleID = "com.ladulghanneey.RelayAir.ios"

    /// Subsystem used for `Logger` across both apps.
    public static let loggingSubsystem = "com.ladulghanneey.RelayAir"

    /// User-facing product name and tagline.
    public static let displayName = "Relay Air"
    public static let tagline = "Send. Approve. Fill."

    /// Bonjour service type for the iPhone ↔ Mac link.
    ///
    /// Must match `NSBonjourServices` in both targets' Info.plist. The name
    /// portion is limited to 15 characters: lowercase letters, numbers, hyphens.
    public static let bonjourServiceType = "_relayair._tcp"
}
