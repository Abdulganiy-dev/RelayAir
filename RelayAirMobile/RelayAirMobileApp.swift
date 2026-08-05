import SwiftUI

/// Relay Air's iPhone sender. Requests no permissions — see `ContentView` for scope.
@main
struct RelayAirMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
