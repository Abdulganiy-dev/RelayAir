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
}

enum EntryPage: Hashable {
    case main
    case add(RelayType)
}

enum CardBackground: Identifiable, Hashable {
    case solid(CardSolid)
    case gradient(CardGradient)

    var id: String {
        switch self {
        case .solid(let solid):       "solid.\(solid.id)"
        case .gradient(let gradient): "gradient.\(gradient.id)"
        }
    }

    var name: String {
        switch self {
        case .solid(let solid):       solid.name
        case .gradient(let gradient): gradient.name
        }
    }

    var style: AnyShapeStyle {
        switch self {
        case .solid(let solid):       AnyShapeStyle(solid.color)
        case .gradient(let gradient): AnyShapeStyle(gradient.style)
        }
    }

    /// The darkest stop, for anything that needs to sit against the background —
    /// a knocked-out mark, a divider, an inner shadow.
    var deepest: Color {
        switch self {
        case .solid(let solid):       solid.color
        case .gradient(let gradient): Color(hex: gradient.stops.last ?? "#000000")
        }
    }

    var kind: CardBackgroundKind {
        switch self {
        case .solid:    .colour
        case .gradient: .gradient
        }
    }
}

enum CardBackgroundKind: String, CaseIterable, Identifiable {
    case colour
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colour:   "Colour"
        case .gradient: "Gradient"
        }
    }
}
