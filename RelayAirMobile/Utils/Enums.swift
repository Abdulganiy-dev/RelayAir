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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .creditCard: "Credit Card"
        case .passport: "Passport"
        case .address: "Address"
        }
    }

    var systemImage: String {
        switch self {
        case .creditCard: "creditcard"
        case .passport: "person.text.rectangle"
        case .address: "mappin.and.ellipse"
        }
    }

    
    var tagExample: String {
        switch self {
        case .creditCard: "e.g. GTBank debit"
        case .passport: "e.g. My work passport"
        case .address: "e.g. Work address"
        }
    }
}

enum EntryPage: Hashable {
    case main
    case add(RelayType)
}

