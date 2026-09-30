import SwiftUI

struct SavedItemCard: View {
    let item: RelayItem
    var displayNameColor: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditableCard(
                background: item.background,
                content: item.content,
                texture: item.texture,
                finish: item.finish,
                size: EditableCard.standard
            )
            Text(item.displayName)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(displayNameColor ?? AppColors.textPrimary(colorScheme: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: EditableCard.standard.width, alignment: .leading)
        }
    }
}
