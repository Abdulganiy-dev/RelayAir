import PortalTransitions
import SwiftUI

struct SavedItemOverlayView: View {
    let item: RelayItem
    let portalID: String
    let portalNamespace: Namespace.ID
    @Binding var isSavedItemTransitioning: Bool
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        ZStack {


            SavedItemCard(item: item, showText: false, isSavedItemTransitioning: $isSavedItemTransitioning)
                .portal(id: portalID, as: .destination, in: portalNamespace)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                SavedItemActionArtwork(title: "Delete", imageName: "SavedItemActionDelete")
                SavedItemActionArtwork(title: "Relay", imageName: "SavedItemActionRelay")
                SavedItemActionArtwork(title: "Edit", imageName: "SavedItemActionEdit")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .safeAreaBar(edge: .top) {
            SavedItemOverlayCloseBar(isDisabled: false, onClose: closeSavedItem)
        }
    }

    private func closeSavedItem() {
        isSavedItemTransitioning = true
        dismiss()
    }
}

private struct SavedItemActionArtwork: View {
    let title: String
    let imageName: String
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(spacing: 4) {
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 84, height: 84)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
            portalID: "savedItem.00000000-0000-0000-0000-000000000101",
            portalNamespace: portalNamespace,
            isSavedItemTransitioning: .constant(false)
        )
    }
}
