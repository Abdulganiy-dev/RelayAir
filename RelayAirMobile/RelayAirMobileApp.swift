import SwiftUI

/// Relay Air's iPhone sender. Requests no permissions — see `ContentView` for scope.
@main
struct RelayAirMobileApp: App {
  
    @State private var screenType: EntryPage = .main
    var body: some Scene {
        WindowGroup {
            EntryView(screenType: $screenType)
                
        }
    }
}


struct EntryView: View {
    @Binding var screenType: EntryPage
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            AppColors.background(colorScheme: colorScheme)
                .ignoresSafeArea()

            Group {
                switch screenType {
                case .main:
                    MainView(screenType: $screenType)
                        .transition(.move(edge: .bottom))
                case .add(let relayType):
                    CreateRelayItem(type: relayType, screenType: $screenType)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.light)
    }
}
