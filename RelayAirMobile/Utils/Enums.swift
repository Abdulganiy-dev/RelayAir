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

    var iconAssetName: String {
        switch self {
        case .creditCard: "RelayTypeCreditCard"
        case .passport: "RelayTypePassport"
        case .address: "RelayTypeAddress"
        case .custom: "RelayTypeCustom"
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
