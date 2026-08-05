import ApplicationServices
import CoreGraphics
import AppKit

/// The macOS privacy permissions Relay Air needs.
///
/// There are only two, even though the app has three distinct capabilities:
/// moving the cursor and typing text are both "post a `CGEvent`", which the
/// system gates behind a single Accessibility grant. See ``Capability`` for the
/// capability → permission mapping.
///
/// Neither permission has an Info.plist usage-description key; both are checked
/// and requested purely in code.
enum SystemPermission: String, CaseIterable, Identifiable, Sendable {
    /// Lets the app post mouse and keyboard events into other applications.
    /// Requires the app to be **unsandboxed** — see `RelayAirMac.entitlements`.
    case accessibility

    /// Lets the app read screen pixels. macOS gates screenshots behind the
    /// screen-*recording* permission.
    case screenRecording

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        }
    }

    /// Where the user finds this in System Settings, for the "already denied" path.
    var settingsLocation: String {
        switch self {
        case .accessibility: "Privacy & Security ▸ Accessibility"
        case .screenRecording: "Privacy & Security ▸ Screen & System Audio Recording"
        }
    }

    /// The capabilities this permission unlocks.
    var capabilities: [Capability] {
        Capability.allCases.filter { $0.permission == self }
    }

    // MARK: - State

    /// Current grant state. Cheap enough to poll.
    nonisolated var isGranted: Bool {
        switch self {
        case .accessibility: AXIsProcessTrusted()
        case .screenRecording: CGPreflightScreenCaptureAccess()
        }
    }

    /// Shows the system prompt.
    ///
    /// `nonisolated` because `CGRequestScreenCaptureAccess` blocks until the
    /// prompt is dismissed and therefore belongs off the main actor.
    ///
    /// - Returns: `true` if access is available now. A `false` result from
    ///   `.accessibility` is not a failure — that prompt is asynchronous, so keep
    ///   polling ``isGranted``.
    @discardableResult
    nonisolated func request() -> Bool {
        switch self {
        case .accessibility:
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        case .screenRecording:
            return CGRequestScreenCaptureAccess()
        }
    }

    /// Whether ``request()`` will block the calling thread.
    var requestBlocks: Bool {
        self == .screenRecording
    }

    // MARK: - System Settings

    /// Deep link into the relevant Privacy & Security pane.
    ///
    /// Once a permission has been denied the app can never re-prompt, so this is
    /// the only recovery path.
    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private var settingsAnchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        }
    }
}
