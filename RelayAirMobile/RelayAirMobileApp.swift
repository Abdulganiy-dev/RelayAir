import SwiftUI

/// Relay Air's iPhone sender. Requests no permissions — see `ContentView` for scope.
@main
struct RelayAirMobileApp: App {
    @Environment(\.colorScheme) var colorScheme
    var body: some Scene {
        WindowGroup {
            MainView()
                .background(AppColors.background(colorScheme: colorScheme).ignoresSafeArea())
                .preferredColorScheme(.light)
        }
    }
}
