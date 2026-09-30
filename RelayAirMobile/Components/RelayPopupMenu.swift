import SwiftUI

struct RelayPopupMenu: View {
    let title: String
    var subtitle: String? = nil
    let options: [RelayMenuOption]
    let onClose: () -> Void
    var maxHeight: CGFloat? = nil

    private var menuShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 28), isUniform: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(colorScheme: .light))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppColors.textMute(colorScheme: .light))
                    }
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(colorScheme: .light))
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.06), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .hapticFeedback(style: .soft)
                .accessibilityLabel("Close menu")
            }

            RelayMenuOptionsList(options: options)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .top)
        .background {
            menuShape
                .fill(Color(hex: "#F8F7F2"))
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
        .compositingGroup()
    }
}
