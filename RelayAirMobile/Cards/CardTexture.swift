//
//  CardTexture.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 07/08/2026.
//
//  Selectable procedural textures and the values used by their picker and renderer.
//  SwiftUI drawing lives in `Components/Cards/CardTextureLayer.swift`.
//

import SwiftUI

enum CardTexture: String, CaseIterable, Identifiable {
    case grain
    // Guilloché and topographic sit together: they are the two that draw a
    // *composition* across the card. The other four are uniform fields.
    case guilloche
    case topographic
    case brushed
    case carbon
    case pinstripe

    /// Named after the hide rather than by coarseness — "grain" is already taken by
    /// the film grain at the top of this list.
    case buffalo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .grain:       "Grain"
        case .guilloche:   "Guilloché"
        case .topographic: "Topographic"
        case .brushed:     "Brushed"
        case .carbon:      "Carbon"
        case .pinstripe:   "Pinstripe"
        case .buffalo:     "Buffalo"
        }
    }

    /// Which part of itself the picker swatch should show.
    ///
    /// A swatch is a 1:1 crop, not a shrunken card — at 52pt the fine textures fall
    /// below a pixel and vanish entirely. So the crop has to land somewhere
    /// representative, and only the texture knows where that is. The four uniform
    /// fields look the same everywhere and take the centre; the two that draw a
    /// composition do not:
    ///
    /// · Guilloché's centre is hollow by construction, so it samples off to the side.
    /// · Topographic is genuinely uneven. Centred it catches a bare stretch and reads
    ///   as an empty circle; this lands on a dense run of contours.
    var swatchOffset: CGSize {
        switch self {
        case .guilloche:   CGSize(width: 88, height: 0)
        case .topographic: CGSize(width: -110, height: 0)
        default:           .zero
        }
    }

    /// Tuned per texture — a dense pattern needs far less presence than a sparse one
    /// to read at the same strength.
    var strength: Double {
        switch self {
        case .grain:       0.55
        case .guilloche:   0.30
        case .topographic: 0.34
        case .brushed:     0.40
        case .carbon:      0.22
        case .pinstripe:   0.22
        // At 0.5 — the first guess — leather stops being a surface and becomes
        // the subject.
        case .buffalo:     0.20
        }
    }
}
