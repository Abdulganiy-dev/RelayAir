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
//        store.sweepOrphanedSecrets()
        itemStore = store
    }

    var body: some Scene {
        WindowGroup {
            PortalContainer {
                NavigationStack {
                    EntryView()
                        .fontDesign(Tokens.fontDesign)
                        
                
                }
            }
            .environment(itemStore)
           

        }
    }
}

struct EntryView: View {
    @AppStorage("appearance") private var appearanceRawValue = RelayAppearance.system.rawValue

    private var appearance: RelayAppearance {
        RelayAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        ZStack {
            MainView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .relayAppBackground()
        .customTextStyle(.body)
        .preferredColorScheme(appearance.colorScheme)
        .fontDesign(Tokens.fontDesign)
    }
}

struct AppScreenBackground: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("appearance") private var appearanceRawValue = RelayAppearance.system.rawValue

    private var effectiveColorScheme: ColorScheme {
        RelayAppearance(rawValue: appearanceRawValue)?.colorScheme ?? systemColorScheme
    }

    var body: some View {
        AppColors.background(colorScheme: effectiveColorScheme)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                BlurredTopBackgroundView(blurRadius: 170)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
