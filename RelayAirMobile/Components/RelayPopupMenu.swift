import SwiftUI

struct RelayPopupMenu: View {
    static let presentationAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    static let presentationTransition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)

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
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
        .compositingGroup()
    }
}
