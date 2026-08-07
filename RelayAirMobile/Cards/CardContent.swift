//
//  CardContent.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  What sits on top of a card's background: four corner slots, all optional.
//
//      top-leading      mark             bottom-leading   the write-up
//      top-trailing     short note       bottom-trailing  mark
//
//  Both mark slots take the same thing — an SF Symbol with a tint, or imported
//  artwork — and both are bounded by the same 50 × 50 ceiling.
//
//  Artwork is held as image `Data` and tints as hex, so a dressed card encodes and
//  restores whole — the same choice `CardStyle` makes for backgrounds.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Content

struct CardContent: Equatable, Codable {
    /// Top-leading.
    var image: CardMark?

    /// Top-trailing. Short, right-aligned — an issuer, a label, a date.
    var topNote: String = ""

    /// Bottom-leading. The main write-up.
    var bottomNote: String = ""

    /// Bottom-trailing.
    var icon: CardMark?

    var isEmpty: Bool {
        image == nil
            && icon == nil
            && topNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bottomNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Mark

/// Whatever sits in a mark slot. Both slots take the same thing, so a card can carry
/// a symbol top-left and a photo bottom-right, or the reverse, without either slot
/// needing its own model.
enum CardMark: Equatable, Codable {
    /// An SF Symbol and the tint chosen for it.
    case symbol(name: String, tint: CardMarkTint)

    /// Artwork the user imported instead.
    case imported(Data)

    var isSymbol: Bool {
        if case .symbol = self { return true }
        return false
    }
}

extension CardMark {

    /// The hard ceiling from the brief, and the same for both slots. Applied in
    /// exactly one place — the frame in `CardContentLayer` — so it cannot drift.
    static let maxSize: CGFloat = 50
}

struct CardMarkTint: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let hex: String

    var color: Color { Color(hex: hex) }
}

extension CardMarkTint {

    /// Twelve tints that hold up against both the dark and the light backgrounds in
    /// the palette. White and Ink lead because a symbol most often wants to sit in
    /// the card's own ink rather than fight it.
    static let palette: [CardMarkTint] = [
        CardMarkTint(id: "white",  name: "White",  hex: "#FFFFFF"),
        CardMarkTint(id: "ink",    name: "Ink",    hex: "#16171B"),
        CardMarkTint(id: "silver", name: "Silver", hex: "#C9CDD4"),
        CardMarkTint(id: "gold",   name: "Gold",   hex: "#E3C88A"),

        CardMarkTint(id: "amber",  name: "Amber",  hex: "#F2A65A"),
        CardMarkTint(id: "coral",  name: "Coral",  hex: "#F0785F"),
        CardMarkTint(id: "rose",   name: "Rose",   hex: "#E88BA6"),
        CardMarkTint(id: "violet", name: "Violet", hex: "#A98BE8"),

        CardMarkTint(id: "sky",    name: "Sky",    hex: "#6FB1F0"),
        CardMarkTint(id: "teal",   name: "Teal",   hex: "#46C4C0"),
        CardMarkTint(id: "mint",   name: "Mint",   hex: "#5FCBA4"),
        CardMarkTint(id: "lime",   name: "Lime",   hex: "#B6D46B"),
    ]

    static let `default` = palette[0]
}

// MARK: - Artwork

@MainActor
enum CardArtwork {

    /// Longest edge kept for imported artwork in either slot. Both draw at 50pt, so
    /// this is already generous at 5×; the point is that a card never carries a
    /// full-resolution capture around.
    static let markMaxPixels: CGFloat = 256

    private static var cache: [Data: Image] = [:]

    /// Decoding on every body pass is visible during the portal animation, so
    /// decoded artwork is memoised against the data it came from.
    static func image(_ data: Data) -> Image? {
        if let cached = cache[data] { return cached }

        #if canImport(UIKit)
        guard let decoded = UIImage(data: data) else { return nil }
        let image = Image(uiImage: decoded)
        #elseif canImport(AppKit)
        guard let decoded = NSImage(data: data) else { return nil }
        let image = Image(nsImage: decoded)
        #else
        return nil
        #endif

        // A card holds at most two pieces of artwork; anything beyond a couple of
        // dozen means the user has been swapping, and the old entries are dead.
        if cache.count > 24 { cache.removeAll() }
        cache[data] = image
        return image
    }

    /// Re-encodes as PNG at a bounded size. PNG rather than JPEG because logos and
    /// icons routinely carry alpha, and flattening that onto white would show.
    nonisolated static func downsampled(_ data: Data, maxPixels: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let output = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  output, UTType.png.identifier as CFString, 1, nil
              )
        else { return nil }

        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
