import SwiftUI

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
        .fontDesign(AppDesignTokens.fontDesign)
    }
}
