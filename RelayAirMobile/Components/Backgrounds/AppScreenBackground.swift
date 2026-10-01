import SwiftUI

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
