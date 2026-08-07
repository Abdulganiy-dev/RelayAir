//
//  CardStyle.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  What a card is wearing. Gradients only — a flat colour never looked like a
//  material next to these, and carrying a second background kind meant a mode switch
//  in the picker that earned nothing.
//
//  Stops are hex strings rather than `Color` so a chosen gradient can be encoded and
//  restored without a custom coder.
//

import SwiftUI

// MARK: - Gradient

struct CardGradient: Identifiable, Hashable {
    let id: String
    let name: String
    let stops: [String]

    var colors: [Color] { stops.map(Color.init(hex:)) }

    /// Every gradient runs the same way — top-leading to bottom-trailing — so a
    /// card reads as lit from one direction no matter which one is chosen.
    var style: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The darkest stop, for anything that needs to sit against the card — a
    /// knocked-out mark, a divider, an inner shadow.
    var deepest: Color { Color(hex: stops.last ?? "#000000") }
}

extension CardGradient {

    /// Three stops each: a lit face, a body, and a shadow. Two-stop gradients go
    /// chalky across a card this size — the middle stop is what keeps them rich.
    static let palette: [CardGradient] = [
        CardGradient(id: "obsidian",  name: "Obsidian",  stops: ["#3C424C", "#1B1D22", "#101114"]),
        CardGradient(id: "midnight",  name: "Midnight",  stops: ["#2E4370", "#182742", "#0B1220"]),
        CardGradient(id: "sapphire",  name: "Sapphire",  stops: ["#4C8DF0", "#2454C4", "#16307E"]),
        CardGradient(id: "lagoon",    name: "Lagoon",    stops: ["#2BB0B8", "#1A6E9C", "#123F6E"]),

        CardGradient(id: "emerald",   name: "Emerald",   stops: ["#3FA97A", "#1E6E52", "#0F3A2C"]),
        CardGradient(id: "meadow",    name: "Meadow",    stops: ["#AED46E", "#4C9153", "#1D4F38"]),
        CardGradient(id: "champagne", name: "Champagne", stops: ["#F7E7BC", "#D4B06A", "#8A6423"]),
        CardGradient(id: "ember",     name: "Ember",     stops: ["#F2A65A", "#D2603F", "#8A2733"]),

        CardGradient(id: "sunset",    name: "Sunset",    stops: ["#F79A7B", "#E0567F", "#8E3070"]),
        CardGradient(id: "blush",     name: "Blush",     stops: ["#F2BCC4", "#C97A98", "#8A456B"]),
        CardGradient(id: "oxblood",   name: "Oxblood",   stops: ["#8E4A55", "#56242F", "#2A1119"]),
        CardGradient(id: "amethyst",  name: "Amethyst",  stops: ["#A98BE8", "#6B4BC4", "#33215E"]),
    ]

    static let `default` = palette[1]   // Midnight
}

// MARK: - Ink

extension CardGradient {

    /// Content ink, taken from the gradient's own luminance rather than assumed
    /// white. Champagne, Blush and Meadow are light enough that white on them is
    /// unreadable — this is what lets them stay in the palette now that cards carry
    /// content.
    var ink: Color {
        isLight ? Color(hex: "#1A1A1C") : .white
    }

    var secondaryInk: Color {
        ink.opacity(isLight ? 0.60 : 0.68)
    }

    /// Cast behind content in the opposite direction to the ink. One ink cannot serve
    /// both ends of a gradient running light to dark — the corners sit at opposite
    /// ends of exactly that sweep — so the shadow carries the legibility where the
    /// ink alone would fail.
    var inkShadow: Color {
        isLight ? .white.opacity(0.55) : .black.opacity(0.30)
    }

    var isLight: Bool { luminance > 0.55 }

    private var luminance: Double {
        guard !stops.isEmpty else { return 0 }
        return stops.map(Self.relativeLuminance).reduce(0, +) / Double(stops.count)
    }

    private static func relativeLuminance(_ hex: String) -> Double {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let packed = UInt32(value, radix: 16) else { return 0 }

        let red = Double((packed >> 16) & 0xFF) / 255
        let green = Double((packed >> 8) & 0xFF) / 255
        let blue = Double(packed & 0xFF) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
