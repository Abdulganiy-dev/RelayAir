//
//  CardFinish.swift
//  RelayAirMobile
//
//  How a card's edge and depth are built — the third axis, after gradient and texture.
//  Nothing here touches the fill.
//

//
//  Two deliberate departures from the source:
//
//  · The rim uses the card's own light and dark gradient stops. Screen and multiply
//    blending lift and shade those colours without a fixed white border.
//
//  · The ambient shadow is radius ~30 / y ~15, not the article's 206 / 58. Those are
//    hero-image numbers. At card scale in a scrolling app they swamp everything
//    underneath; this keeps the proportion and loses the bloat.
//

import SwiftUI

enum CardFinish: String, CaseIterable, Identifiable, Codable {
    /// One rim, one shadow. The original card, and the default.
    case flat

    /// The article's edge: four inset strokes, two light, two dark, over a deep
    /// ambient shadow.
    case machined

    /// A quieter version of the machined rim, without a bright bloom over the face.
    case frosted

    var id: String { rawValue }

    var name: String {
        switch self {
        case .flat:     "Flat"
        case .machined: "Machined"
        case .frosted:  "Frosted"
        }
    }
}

// MARK: - Rim

extension CardFinish {

    struct RimLayer: Identifiable {
        let id: Int
        let inset: CGFloat
        let width: CGFloat
        let colors: [Color]
        let start: UnitPoint
        let end: UnitPoint
        let blendMode: BlendMode

        var style: LinearGradient {
            LinearGradient(colors: colors, startPoint: start, endPoint: end)
        }
    }

    /// Outermost first. Light strokes run top-leading to bottom-trailing so they are
    /// brightest where the light lands; dark strokes run the opposite way so shadow
    /// gathers on the far edge. Alternating them is what makes an edge look milled
    /// rather than outlined.
    func rim(for background: CardGradient) -> [RimLayer] {
        let light = background.colors.first ?? background.deepest
        let dark = background.deepest
        let strength = self == .frosted ? 0.65 : 1.0

        return switch self {
        case .flat:
            [
                RimLayer(id: 0, inset: 0, width: 1,
                         colors: [light.opacity(0.45), light.opacity(0.08)],
                         start: .topLeading, end: .bottomTrailing,
                         blendMode: .screen),
            ]

        case .machined, .frosted:
            [
                RimLayer(id: 0, inset: 0, width: 0.7,
                         colors: [light.opacity(0.72 * strength), light.opacity(0.10 * strength)],
                         start: .topLeading, end: .bottomTrailing,
                         blendMode: .screen),

                RimLayer(id: 1, inset: 0.7, width: 0.6,
                         colors: [dark.opacity(0.38 * strength), dark.opacity(0.03 * strength)],
                         start: .bottomTrailing, end: .topLeading,
                         blendMode: .multiply),

                RimLayer(id: 2, inset: 1.3, width: 0.5,
                         colors: [light.opacity(0.38 * strength), light.opacity(0.04 * strength)],
                         start: .top, end: .bottom,
                         blendMode: .screen),

                RimLayer(id: 3, inset: 1.8, width: 0.5,
                         colors: [dark.opacity(0.28 * strength), dark.opacity(0)],
                         start: .bottom, end: .top,
                         blendMode: .multiply),
            ]
        }
    }
}

// MARK: - Depth

extension CardFinish {

    struct ShadowSpec {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    /// Tight, directly under the card. What tells you it is resting on something.
    var contactShadow: ShadowSpec {
        switch self {
        case .flat:               ShadowSpec(opacity: 0.15, radius: 16, y: 4)
        case .machined, .frosted: ShadowSpec(opacity: 0.13, radius: 6, y: 2)
        }
    }

    /// Wide and faint, straight down. Carries the weight without reading as a shadow —
    /// and the second half of that sentence is the whole job. The first pass at
    /// 0.22 / 44 / 26 pooled into a visible dark smudge under the card, which is the
    /// opposite of "felt before it's seen".
    var ambientShadow: ShadowSpec {
        switch self {
        // Zero opacity is a no-op, so flat keeps its single shadow.
        case .flat:               ShadowSpec(opacity: 0, radius: 0, y: 0)
        case .machined, .frosted: ShadowSpec(opacity: 0.13, radius: 30, y: 15)
        }
    }

}
