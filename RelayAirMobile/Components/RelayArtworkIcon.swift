import SwiftUI

enum RelayArtworkAsset: String, CaseIterable {
    case relayTypeCreditCard = "RelayTypeCreditCard"
    case relayTypePassport = "RelayTypePassport"
    case relayTypeAddress = "RelayTypeAddress"
    case relayTypeCustom = "RelayTypeCustom"

    case savedItemDelete = "SavedItemActionDelete"
    case savedItemSend = "SavedItemActionRelay"
    case savedItemEdit = "SavedItemActionEdit"
}

enum RelayArtworkStyle {
    static let iconSize: CGFloat = 84
    static let reflectionHeightRatio: CGFloat = 0.18 // about 15 pt at 84 pt
    static let reflectionOpacity: CGFloat = 0.32

    static func reflectionHeight(for iconSize: CGFloat) -> CGFloat {
        iconSize * reflectionHeightRatio
    }
}

struct RelayArtworkIcon: View {
    let asset: RelayArtworkAsset
    var size: CGFloat = RelayArtworkStyle.iconSize

    private var reflectionHeight: CGFloat {
        RelayArtworkStyle.reflectionHeight(for: size)
    }

    private var artwork: some View {
        Image(asset.rawValue)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    var body: some View {
        VStack(spacing: 0) {
            artwork

            artwork
                .scaleEffect(x: 1, y: -1, anchor: .center)
                .frame(width: size, height: reflectionHeight, alignment: .top)
                .clipped()
                .opacity(RelayArtworkStyle.reflectionOpacity)
                .mask {
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .frame(width: size, height: size + reflectionHeight, alignment: .top)
        .accessibilityHidden(true)
    }
}
