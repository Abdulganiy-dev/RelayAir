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

    /// Three stops each — a lit face, a body, and a shadow. Two-stop gradients go
    /// chalky across a card this size; the middle stop is what keeps them rich.
    ///
    /// The metals are the exception, and deliberately so: see `Platinum` below.
    /// Grouped by family rather than in even rows, because that is what you actually
    /// scan for when adding one.
    static let palette: [CardGradient] = [
        // Neutrals and metal
        CardGradient(id: "obsidian",  name: "Obsidian",  stops: ["#3C424C", "#1B1D22", "#101114"]),

        // A metal is not a fade from light to dark — it is a sequence of specular
        // bands, bright then dark then bright again, because the surface catches the
        // light more than once across its width. Six alternating stops is the least
        // that reads as metal rather than as grey. Pair either with the `brushed`
        // texture and it stops looking like a gradient at all.
        //
        // The alternation is what reads as metal, not the contrast: the first pass
        // swung ~90 points between adjacent stops and the bands came out hard-edged
        // and glary. Both metals now sit inside a ~60 point range, which keeps the
        // banding and loses the glare.
        CardGradient(id: "platinum",  name: "Platinum",  stops: ["#F2F5F8", "#D6DCE4", "#E9EDF2", "#BFC7D2", "#DEE4EB", "#C6CEDA"]),
        CardGradient(id: "gold",      name: "Gold",      stops: ["#F4EAD3", "#DCC796", "#EEE1C0", "#C9AE76", "#E6D6AC", "#D0B984"]),

        // Blues
        CardGradient(id: "midnight",  name: "Midnight",  stops: ["#2E4370", "#182742", "#0B1220"]),
        CardGradient(id: "sapphire",  name: "Sapphire",  stops: ["#4C8DF0", "#2454C4", "#16307E"]),
        CardGradient(id: "lagoon",    name: "Lagoon",    stops: ["#2BB0B8", "#1A6E9C", "#123F6E"]),

        // Greens
        CardGradient(id: "emerald",   name: "Emerald",   stops: ["#3FA97A", "#1E6E52", "#0F3A2C"]),
        CardGradient(id: "meadow",    name: "Meadow",    stops: ["#AED46E", "#4C9153", "#1D4F38"]),

        // Warms
        CardGradient(id: "champagne", name: "Champagne", stops: ["#F7E7BC", "#D4B06A", "#8A6423"]),
        CardGradient(id: "ember",     name: "Ember",     stops: ["#F2A65A", "#D2603F", "#8A2733"]),
        CardGradient(id: "sunset",    name: "Sunset",    stops: ["#F79A7B", "#E0567F", "#8E3070"]),

        // Reds and violet
        CardGradient(id: "blush",     name: "Blush",     stops: ["#F2BCC4", "#C97A98", "#8A456B"]),
        CardGradient(id: "oxblood",   name: "Oxblood",   stops: ["#8E4A55", "#56242F", "#2A1119"]),
        CardGradient(id: "amethyst",  name: "Amethyst",  stops: ["#A98BE8", "#6B4BC4", "#33215E"]),
    ]

    /// Looked up by id, not by index — inserting Platinum silently moved `palette[1]`
    /// and changed the default out from under everything that used it.
    static let `default` = named("midnight")

    static func named(_ id: String) -> CardGradient {
        palette.first { $0.id == id } ?? palette[0]
    }
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
