import Chronicle
import PortalTransitions
import SQLiteData
import SwiftUI


@main
struct RelayAirMobileApp: App {
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
                    EntryView(hideStatusBar: $hideStatusBar)
                        .fontDesign(Tokens.fontDesign)
                
                }
            }
            .environment(itemStore)
           

        }
    }
}

struct EntryView: View {
    @Binding var hideStatusBar: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            AppColors.background(colorScheme: colorScheme)
                .ignoresSafeArea()

            MainView(hideStatusBar: $hideStatusBar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.light)
        .fontDesign(Tokens.fontDesign)
    }
}
