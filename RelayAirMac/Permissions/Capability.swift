import Foundation

/// What Relay Air needs to be able to do on the Mac, in the user's terms.
///
/// Three capabilities, backed by two system permissions — granting
/// Accessibility once unlocks both cursor control and typing.
enum Capability: String, CaseIterable, Identifiable, Sendable {
    /// Move the pointer and click, via `CursorController`.
    case cursorControl

    /// Synthesize keystrokes into the focused field, via `TextInjector`.
    case textTyping

    /// Take screenshots, via `ScreenCaptureService`.
    case screenCapture

    var id: String { rawValue }

    /// The macOS permission that gates this capability.
    var permission: SystemPermission {
        switch self {
        case .cursorControl, .textTyping: .accessibility
        case .screenCapture: .screenRecording
        }
    }

    var title: String {
        switch self {
        case .cursorControl: "Move the cursor"
        case .textTyping: "Type text"
        case .screenCapture: "Capture the screen"
        }
    }

    var detail: String {
        switch self {
        case .cursorControl: "Position the pointer and click on your behalf."
        case .textTyping: "Enter approved text into the field you're in."
        case .screenCapture: "Take a screenshot to see what's on screen."
        }
    }

    var symbol: String {
        switch self {
        case .cursorControl: "cursorarrow.motionlines"
        case .textTyping: "keyboard"
        case .screenCapture: "camera.viewfinder"
        }
    }
}
