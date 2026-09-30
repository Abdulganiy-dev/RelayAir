//
//  Enums.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 07/08/2026.
//

import SwiftUI

enum RelayType: String, Identifiable, CaseIterable {
    case creditCard
    case passport
    case address
    case custom

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

enum EntryPage: Hashable {
    case main
    case add(RelayType)
}
