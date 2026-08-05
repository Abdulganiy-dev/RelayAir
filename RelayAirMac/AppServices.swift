import Foundation
import Observation

/// Single container for the app's long-lived objects, so views can reach them
/// without a web of singletons.
@MainActor
@Observable
final class AppServices {
    let permissions: PermissionsModel

    /// Drives Send → Approve → Fill, and owns the TextInjector
    /// (`Capability.textTyping`).
    let relay: RelayController

    let cursor = CursorController()            // Capability.cursorControl
    let screenCapture: ScreenCaptureService    // Capability.screenCapture

    init() {
        let permissions = PermissionsModel()
        let screenCapture = ScreenCaptureService()
        self.permissions = permissions
        self.screenCapture = screenCapture
        self.relay = RelayController(permissions: permissions, screenCapture: screenCapture)
    }

    /// Called from `applicationDidFinishLaunching`.
    func begin() {
        permissions.startPolling()
        relay.startIfPermitted()
    }

    /// Called from `applicationWillTerminate` — leave nothing running.
    func end() {
        relay.stop()
        permissions.stopPolling()
    }
}
