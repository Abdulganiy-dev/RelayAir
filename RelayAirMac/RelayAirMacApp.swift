import SwiftUI
import RelayAirCore

/// Relay Air's Mac receiver — step three of *Send. Approve. Fill.*
///
/// It runs as a menu-bar agent: `LSUIElement` is `YES`, so there is no Dock icon
/// and no main window. The menu bar item is the whole UI surface, plus a one-off
/// onboarding window when permissions are missing.
@main
struct RelayAirMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(services: appDelegate.services)
        } label: {
            MenuBarLabel(services: appDelegate.services)
        }
        // A panel rather than a menu, so the pairing QR can be shown inline.
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar glyph, which tracks the relay state.
///
/// A separate `View` rather than an inline `Image` so SwiftUI's observation
/// tracking reliably invalidates it when the state changes — `@Observable`
/// reads are not dependable directly inside an `App`'s body.
private struct MenuBarLabel: View {
    let services: AppServices

    var body: some View {
        Image(systemName: symbol)
    }

    private var symbol: String {
        guard services.permissions.canControlInput else { return "exclamationmark.triangle" }
        return services.relay.state.symbol
    }
}
