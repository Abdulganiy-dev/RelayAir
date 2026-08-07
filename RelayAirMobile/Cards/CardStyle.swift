//
//  CardStyle.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  What a card is wearing. Colours and gradients for now; background images and
//  textures land as further cases on `CardBackground`.
//
//  Everything is stored as hex strings rather than `Color` so a chosen background
//  can be encoded and restored later without a custom coder.
//

import SwiftUI

// MARK: - Solids

struct CardSolid: Identifiable, Hashable {
    let id: String
    let name: String
    let hex: String

    var color: Color { Color(hex: hex) }
}

extension CardSolid {

    /// Twelve deep, saturated-but-not-loud tones, walking the wheel from cool
    /// neutrals through blues and greens into warms, reds and violet. All are dark
    /// enough to carry white content, which is what keeps the set feeling like one
    /// family rather than a box of crayons.
    static let palette: [CardSolid] = [
        CardSolid(id: "onyx",     name: "Onyx",     hex: "#16171B"),
        CardSolid(id: "graphite", name: "Graphite", hex: "#383D45"),
        CardSolid(id: "storm",    name: "Storm",    hex: "#4E5B6B"),
        CardSolid(id: "midnight", name: "Midnight", hex: "#1B2A4A"),

        CardSolid(id: "sapphire", name: "Sapphire", hex: "#27488F"),
        CardSolid(id: "lagoon",   name: "Lagoon",   hex: "#10534E"),
        CardSolid(id: "forest",   name: "Forest",   hex: "#1D4635"),
        CardSolid(id: "moss",     name: "Moss",     hex: "#525E24"),

        CardSolid(id: "ochre",    name: "Ochre",    hex: "#8A5B18"),
        CardSolid(id: "ember",    name: "Ember",    hex: "#8B3E20"),
        CardSolid(id: "oxblood",  name: "Oxblood",  hex: "#5F2231"),
        CardSolid(id: "plum",     name: "Plum",     hex: "#452750"),
    ]
}

// MARK: - Gradients

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
}

// MARK: - Defaults

extension CardBackground {
    static let `default` = CardBackground.gradient(CardGradient.palette[1])   // Midnight
}
