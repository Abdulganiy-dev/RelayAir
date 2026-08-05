import AppKit
import SwiftUI

/// Handles the parts of the lifecycle SwiftUI does not expose for agent apps:
/// forcing accessory activation policy, showing onboarding on first launch, and
/// guaranteeing teardown on quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let services = AppServices()

    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt and braces alongside `LSUIElement`: no Dock icon, no menu bar menus.
        NSApp.setActivationPolicy(.accessory)

        services.begin()

        // The only time we show a window unprompted is when we cannot work at all.
        if !services.permissions.canControlInput {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Per the brief: nothing observes the user once the app is closed.
        services.end()
    }

    /// Agent apps have no windows to restore, so re-opening should surface the
    /// onboarding panel rather than doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showOnboarding() }
        return true
    }

    // MARK: - Onboarding window

    /// Shows (or re-focuses) the permissions window. Built with AppKit rather
    /// than a SwiftUI `Window` scene because `openWindow` is unreliable from an
    /// `.accessory` app that has never been activated.
    func showOnboarding() {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Relay Air Setup"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: PermissionsView(services: services) { [weak window] in
                window?.close()
            }
        )

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
