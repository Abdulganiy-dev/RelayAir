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
//  · Strokes are white and black at low opacity rather than the article's literal
//    greys (#FBFCFE, #252D33). Those are tuned for one steel button; the palette here
//    is fourteen gradients from Obsidian to Blush, and a fixed grey rim goes muddy on
//    the warm ones. Opacity rides whatever it sits on.
//
//  · The ambient shadow is radius ~30 / y ~15, not the article's 206 / 58. Those are
//    hero-image numbers. At card scale in a scrolling app they swamp everything
//    underneath; this keeps the proportion and loses the bloat.
//

import SwiftUI

enum CardFinish: String, CaseIterable, Identifiable, Codable {
    /// One rim, one shadow. The original card, and the default — existing cards look
    /// exactly as they did.
    case flat

    /// The article's edge: four inset strokes, two light, two dark, over a deep
    /// ambient shadow.
    case machined

    /// Machined, plus a soft bloom where the light lands. The nearest honest
    /// translation of "frosted": the article frosts by blurring a backdrop through the
    /// shape, and an opaque card has no backdrop to blur — so the softness has to be
    /// light diffusing *in* the material rather than scenery showing through it.
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

        var style: LinearGradient {
            LinearGradient(colors: colors, startPoint: start, endPoint: end)
        }
    }

    /// Outermost first. Light strokes run top-leading to bottom-trailing so they are
    /// brightest where the light lands; dark strokes run the opposite way so shadow
    /// gathers on the far edge. Alternating them is what makes an edge look milled
    /// rather than outlined.
    var rim: [RimLayer] {
        switch self {
        case .flat:
            [
                RimLayer(id: 0, inset: 0, width: 1,
                         colors: [.white.opacity(0.28), .white.opacity(0.05)],
                         start: .topLeading, end: .bottomTrailing),
            ]

        case .machined, .frosted:
            [
                RimLayer(id: 0, inset: 0, width: 0.7,
                         colors: [.white.opacity(0.62), .white.opacity(0.06)],
                         start: .topLeading, end: .bottomTrailing),

                RimLayer(id: 1, inset: 0.7, width: 0.6,
                         colors: [.black.opacity(0.30), .black.opacity(0.02)],
                         start: .bottomTrailing, end: .topLeading),

                RimLayer(id: 2, inset: 1.3, width: 0.5,
                         colors: [.white.opacity(0.26), .white.opacity(0.02)],
                         start: .top, end: .bottom),

                RimLayer(id: 3, inset: 1.8, width: 0.5,
                         colors: [.black.opacity(0.20), .black.opacity(0)],
                         start: .bottom, end: .top),
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

    var hasBloom: Bool { self == .frosted }
}
