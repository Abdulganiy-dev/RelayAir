import Chronicle
import PortalTransitions
import SQLiteData
import SwiftUI


@main
struct RelayAirMobileApp: App {
    @State private var screenType: EntryPage = .main
    @State private var itemStore: RelayItemStore
    @State private var hideStatusBar = false

    init() {

        PortalLogs.configure(allowedLevels: [.notice, .warning, .error, .fault])

     
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }

        let store = RelayItemStore()
//        store.sweepOrphanedSecrets()
        itemStore = store
    }

    var body: some Scene {
        WindowGroup {
            PortalContainer {
                NavigationStack {
                    EntryView(screenType: $screenType, hideStatusBar: $hideStatusBar)
                        .fontDesign(Tokens.fontDesign)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            .environment(itemStore)
           
            .adaptiveStatusBarHidden(hideStatusBar)
        }
    }
}


struct EntryView: View {
    @Binding var screenType: EntryPage
    @Binding var hideStatusBar: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            AppColors.background(colorScheme: colorScheme)
                .ignoresSafeArea()

            Group {
                switch screenType {
                case .main:
                    MainView(screenType: $screenType, hideStatusBar: $hideStatusBar)
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
