import Chronicle
import PortalTransitions
import SQLiteData
import SwiftUI


@main
struct RelayAirMobileApp: App {
    @State private var itemStore: RelayItemStore

    init() {

        PortalLogs.configure(allowedLevels: [.notice, .warning, .error, .fault])

     
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }

        let store = RelayItemStore()
        itemStore = store
    }

    var body: some Scene {
        WindowGroup {
            PortalContainer {
                EntryView()
                    .fontDesign(AppDesignTokens.fontDesign)
            }
            .environment(itemStore)
           

        }
    }
}
