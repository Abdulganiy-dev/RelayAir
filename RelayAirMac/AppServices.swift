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
    let pairing = PairingManager()

    init() {
        let permissions = PermissionsModel()
        let screenCapture = ScreenCaptureService()
        self.permissions = permissions
        self.screenCapture = screenCapture
        self.relay = RelayController(
            permissions: permissions,
            screenCapture: screenCapture,
            pairing: pairing
        )
    }

    /// Called from `applicationDidFinishLaunching`.
    func begin() {
        // The pairing has to exist before the relay advertises, since the
        // secret is what the listener's TLS is keyed on.
        pairing.loadOrCreate()
        permissions.startPolling()
        relay.startIfPermitted()
    }

    /// Called from `applicationWillTerminate` — leave nothing running.
    func end() {
        relay.stop()
        permissions.stopPolling()
    }
}
