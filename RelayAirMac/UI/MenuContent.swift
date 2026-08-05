import SwiftUI
import AppKit
import RelayAirCore

/// The menu-bar menu — the app's entire everyday UI.
///
/// The top line always answers "what is Relay Air doing right now" in the
/// vocabulary of *Send. Approve. Fill.*
struct MenuContent: View {
    let services: AppServices

    private var relay: RelayController { services.relay }

    var body: some View {
        Group {
            if services.permissions.canControlInput {
                Label(relay.state.statusText, systemImage: relay.state.symbol)

                if relay.state == .awaitingApproval {
                    Button("Approve & Fill") {
                        Task { await relay.approve() }
                    }
                    Button("Reject") { relay.reject() }
                }

                if case .failed = relay.state {
                    Button("Dismiss") { relay.clearError() }
                }

                Divider()
                Toggle("Relay active", isOn: relayBinding)
            } else {
                Label("Accessibility permission required", systemImage: "exclamationmark.triangle")
                Button("Open Setup…") { openSetup() }
            }

            Divider()
            Button("Permissions & Setup…") { openSetup() }
            Button("Quit Relay Air") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var relayBinding: Binding<Bool> {
        Binding(
            get: { relay.isActive },
            set: { shouldRun in
                if shouldRun {
                    relay.start()
                } else {
                    relay.stop()
                }
            }
        )
    }

    private func openSetup() {
        (NSApp.delegate as? AppDelegate)?.showOnboarding()
    }
}
