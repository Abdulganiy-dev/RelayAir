import SwiftUI

struct RelayMenuOption: Identifiable {
    let label: String
    let iconName: RelayArtworkAsset
    var isSelected = false
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
                    isSelected: option.isSelected,
                    action: option.action
                )
            }
        }
    }
}

struct RelayMenuOptionItem: View {
    let label: String
    let iconName: RelayArtworkAsset
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let iconSize: CGFloat = 68

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RelayArtworkIcon(asset: iconName, size: iconSize)

                Text(label)
                    .customTextStyle(.supportingEmphasis, color: .inverted)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppColors.iconBrand(colorScheme: colorScheme))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}
