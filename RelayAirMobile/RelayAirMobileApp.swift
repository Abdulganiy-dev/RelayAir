import SwiftUI
import PortalTransitions

/// Relay Air's iPhone sender. Requests no permissions — see `ContentView` for scope.
@main
struct RelayAirMobileApp: App {
  
    @State private var screenType: EntryPage = .main
    var body: some Scene {
        WindowGroup {
            PortalContainer {
                EntryView(screenType: $screenType)
                    .fontDesign(Tokens.fontDesign)
            }
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
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)).combined(with: .opacity))
                case .add(let relayType):
                    CreateRelayItem(type: relayType, screenType: $screenType)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.light)
        .fontDesign(Tokens.fontDesign)
    }
}
