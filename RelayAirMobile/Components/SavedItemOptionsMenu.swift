import SwiftUI

struct SavedItemOptionsMenu: View {
    let item: RelayItem
    let onSelect: (SavedItemOption) -> Void
    let onClose: () -> Void

    private var options: [RelayMenuOption] {
        SavedItemOption.allCases.map { option in
            RelayMenuOption(label: option.title, iconName: option.artworkAsset) {
                onSelect(option)
            }
        }
    }

    var body: some View {
        RelayPopupMenu(
            title: "\(item.displayName) Options",
            options: options,
            onClose: onClose
        )
    }
}

enum SavedItemOption: String, CaseIterable, Identifiable {
    case delete
    case relay
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .delete: "Delete"
        case .relay: "Relay"
        case .edit: "Edit"
        }
    }

    var artworkAsset: RelayArtworkAsset {
        switch self {
        case .delete: .savedItemDelete
        case .relay: .savedItemSend
        case .edit: .savedItemEdit
        }
    }
}
