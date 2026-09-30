import PortalTransitions
import SwiftUI

struct SavedItemOverlayView: View {
    let item: RelayItem
    let portalNamespace: Namespace.ID
    @Binding var isSavedItemTransitioning: Bool

    let onClose: () -> Void
    
    

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .contentShape(Rectangle())
                .ignoresSafeArea()

            SavedItemCard(item: item, showText: false, isSavedItemTransitioning: $isSavedItemTransitioning)
                .portal(item: item, as: .destination, in: portalNamespace)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top) {
            SavedItemOverlayCloseBar(isDisabled: false, onClose: onClose)
        }
    }
}

private struct SavedItemOverlayCloseBar: View {
    let isDisabled: Bool
    let onClose: () -> Void

    var body: some View {
        HStack {
            Spacer()

            CircularButton(icon: "xmark", iconColor: .black, action: onClose)
                .accessibilityLabel("Close card")
                .disabled(isDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview("Saved card overlay") {
    @Previewable @Namespace var portalNamespace

    PortalContainer {
        SavedItemOverlayView(
            item: RelayItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                type: .creditCard,
                tag: "Everyday Card",
                gradientID: "sapphire",
                texture: .brushed,
                finish: .machined,
                content: CardContent(
                    image: .symbol(name: "creditcard.fill"),
                    topNote: "RELAY AIR",
                    bottomNote: "•••• 4821",
                    icon: .symbol(name: "wave.3.right")
                )
            ),
            portalNamespace: portalNamespace,
            isSavedItemTransitioning: .constant(false),
            onClose: {}
        )
    }
}
