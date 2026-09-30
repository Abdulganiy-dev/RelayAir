import SwiftUI

struct RelayMenuOption: Identifiable {
    let label: String
    let iconName: RelayArtworkAsset
    let action: () -> Void

    var id: String { "\(iconName.rawValue).\(label)" }
}

struct RelayMenuOptionsList: View {
    let options: [RelayMenuOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(options) { option in
                RelayMenuOptionItem(
                    label: option.label,
                    iconName: option.iconName,
                    action: option.action
                )
            }
        }
    }
}

struct RelayMenuOptionItem: View {
    let label: String
    let iconName: RelayArtworkAsset
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let iconSize: CGFloat = 68

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RelayArtworkIcon(asset: iconName, size: iconSize)

                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hapticFeedback(style: .soft)
    }
}
