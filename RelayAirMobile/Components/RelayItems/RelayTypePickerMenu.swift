import SwiftUI

struct RelayTypePickerMenu: View {
    let onSelect: (RelayType) -> Void
    let onClose: () -> Void

    private var options: [RelayMenuOption] {
        RelayType.availableForCreation.map { type in
            RelayMenuOption(label: type.title, iconName: type.artworkAsset) {
                onSelect(type)
            }
        }
    }

    var body: some View {
        RelayPopupMenu(
            title: "Create a relay item",
            subtitle: "What would you like to save?",
            options: options,
            onClose: onClose,
        )
    }
}

#Preview("Relay type picker") {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.14)
            .ignoresSafeArea()

        RelayTypePickerMenu(onSelect: { _ in }, onClose: {})
            .frame(height: 360)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
