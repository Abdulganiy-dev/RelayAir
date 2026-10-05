import SwiftUI

struct RelayPopupMenu: View {
    static let presentationAnimation: Animation = .spring(response: 0.53, dampingFraction: 0.8, blendDuration: 0.1)
    static let presentationTransition: AnyTransition = AnyTransition(
        AsymmetricTransition(
            insertion: depthTransition(blurConfiguration: .upUp),
            removal: depthTransition(blurConfiguration: .downUp)
        )
    )

    private static func depthTransition(
        blurConfiguration: BlurReplaceTransition.Configuration
    ) -> some Transition {
        MoveTransition(edge: .bottom)
//            .combined(with: OffsetTransition(CGSize(width: 0, height: 180)))
            .combined(with: ScaleTransition(0.7, anchor: .bottom))
            .combined(with: BlurReplaceTransition(configuration: blurConfiguration))
    }

    let title: String
    var subtitle: String? = nil
    let options: [RelayMenuOption]
    let onClose: () -> Void
    var maxHeight: CGFloat? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var menuShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 28), isUniform: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .customTextStyle(.title, color: .inverted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle {
                        Text(subtitle)
                            .customTextStyle(.supporting, color: .muted)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.06), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .hapticFeedback(style: .light)
                .accessibilityLabel("Close menu")
            }

            RelayMenuOptionsList(options: options)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .top)
        .background {
            menuShape
                .fill(colorScheme == .dark ? AppColors.backgroundSurfaceLayer(colorScheme: colorScheme) : .white)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
        .compositingGroup()
        .padding(.bottom)
     
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }
}
