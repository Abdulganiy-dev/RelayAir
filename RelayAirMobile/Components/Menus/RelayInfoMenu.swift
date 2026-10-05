import SwiftUI

struct RelayInfoMenu: View {
    static let presentationAnimation = RelayPopupMenu.presentationAnimation
    static let presentationTransition = RelayPopupMenu.presentationTransition

    let artwork: RelayArtworkAsset
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let buttonTitle: LocalizedStringResource
    let onAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            RelayArtworkIcon(asset: artwork, size: 112)

            VStack(spacing: 8) {
                Text(title)
                    .customTextStyle(.title, color: .inverted)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .customTextStyle(.supporting, color: .muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onAction) {
                Text(buttonTitle)
                    .customTextStyle(.action, color: .custom(.white))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            

            }
             .buttonStyle(.plain)
                        .glassEffect(
                            .regular.tint(AppColors.lightColors.primaryPrimaryDefault).interactive(),
                            in: .capsule
            )
            .hapticFeedback()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .background {
            ConcentricRectangle(corners: .concentric(minimum: 28), isUniform: true)
                .fill(colorScheme == .dark ? AppColors.backgroundSurfaceLayer(colorScheme: colorScheme) : .white)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
        .compositingGroup()
        .padding(.bottom)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onAction)
    }
}
