import Chronicle
import PortalTransitions
import SQLiteData
import SwiftUI


@main
struct RelayAirMobileApp: App {
    @State private var screenType: EntryPage = .main
    @State private var itemStore: RelayItemStore

    init() {

        PortalLogs.configure(allowedLevels: [.notice, .warning, .error, .fault])

     
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }

        let store = RelayItemStore()
        store.sweepOrphanedSecrets()
        itemStore = store
    }

    var body: some Scene {
        WindowGroup {
            PortalContainer {
                EntryView(screenType: $screenType)
                    .fontDesign(Tokens.fontDesign)
            }
            .environment(itemStore)
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
