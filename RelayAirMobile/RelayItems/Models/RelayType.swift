import SwiftUI

enum RelayType: String, Identifiable, CaseIterable {
    case creditCard
    case passport
    case address
    case custom

    /// Types that users can add from the current product flow.
    static let availableForCreation: [RelayType] = [.address, .custom]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .creditCard: "Credit Card"
        case .passport: "Passport"
        case .address: "Address"
        case .custom: "Custom"
        }
    }

    var artworkAsset: RelayArtworkAsset {
        switch self {
        case .creditCard: .relayTypeCreditCard
        case .passport: .relayTypePassport
        case .address: .relayTypeAddress
        case .custom: .relayTypeCustom
        }
    }

    
    var tagExample: String {
        switch self {
        case .creditCard: "e.g. GTBank debit"
        case .passport: "e.g. My work passport"
        case .address: "e.g. Work address"
        case .custom: "e.g. Wi-Fi password"
        }
    }
}
