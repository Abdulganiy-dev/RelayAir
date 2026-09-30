import SwiftUI

struct SavedItemCard: View {
    let item: RelayItem

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            EditableCard(
                background: item.background,
                content: item.content,
                texture: item.texture,
                finish: item.finish,
                size: EditableCard.standard
            )
            Text(item.displayName)
                .customTextStyle(.supportingEmphasis, color: .inverted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: EditableCard.standard.width, alignment: .center)
        }
    }
}
