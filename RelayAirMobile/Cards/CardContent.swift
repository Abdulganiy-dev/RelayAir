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
//  Both mark slots take the same thing — an SF Symbol or imported artwork — and both
//  are bounded by the same 50 × 50 ceiling.
//
//  Artwork is held as image `Data`, so a dressed card encodes and restores whole — the
//  same choice `CardStyle` makes for backgrounds.
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
    /// An SF Symbol, cut into the card. It carries no colour of its own: it is a
    /// recess in the material, and a hole is whatever the card is made of. The tint
    /// palette that used to live here went with it — picking a colour for a hole was
    /// asking a question with no meaningful answer.
    case symbol(name: String)

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
