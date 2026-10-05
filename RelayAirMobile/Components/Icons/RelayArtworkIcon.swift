import SwiftUI

enum RelayArtworkAsset: String, CaseIterable {
    case relayTypeCreditCard = "RelayTypeCreditCard"
    case relayTypePassport = "RelayTypePassport"
    case relayTypeAddress = "RelayTypeAddress"
    case relayTypeCustom = "RelayTypeCustom"

    case savedItemDelete = "SavedItemActionDelete"
    case savedItemSend = "SavedItemActionRelay"
    case savedItemEdit = "SavedItemActionEdit"

    case appearanceSystem = "AppearanceSystem"
    case appearanceLight = "AppearanceLight"
    case appearanceDark = "AppearanceDark"

    case scannerRelatedDocuments = "ScannerRelatedDocuments"
}

enum RelayArtworkStyle {
    static let iconSize: CGFloat = 84
}

struct RelayArtworkIcon: View {
    let asset: RelayArtworkAsset
    var size: CGFloat = RelayArtworkStyle.iconSize

    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
