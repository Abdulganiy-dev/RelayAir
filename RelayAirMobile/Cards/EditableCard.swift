//
//  EditableCard.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  The card itself — 358 × 225, blank for now. Content comes later; this is the
//  surface the user dresses.
//
//  The card is deliberately more than a filled rectangle: one specular pass, an
//  edge-lit rim and a drop shadow. That treatment is what makes even a flat
//  colour read as a physical object rather than a swatch.
//

import SwiftUI

struct EditableCard: View {
    let background: CardBackground

    var size: CGSize? = EditableCard.standard
    var cornerRadius: CGFloat = 20


    static let standard = CGSize(width: 358, height: 225)


    static let compact = CGSize(width: 300, height: 200)

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(background.style)
            .overlay(shape.fill(Self.sheen))
            .overlay(shape.strokeBorder(Self.rim, lineWidth: 1))
            .frame(width: size?.width, height: size?.height)
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
            .animation(.smooth(duration: 0.35), value: background)
    }

    /// A single specular pass. Weak on purpose — the moment it reads as a visible
    /// band it stops looking like a material and starts looking like a graphic.
    private static let sheen = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.10), location: 0.00),
            .init(color: .white.opacity(0),    location: 0.42),
            .init(color: .white.opacity(0),    location: 0.64),
            .init(color: .black.opacity(0.06), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Bright where the light lands, nearly gone on the far side.
    private static let rim = LinearGradient(
        colors: [.white.opacity(0.28), .white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

#Preview("Card") {
    VStack(spacing: 28) {
        EditableCard(background: .gradient(CardGradient.palette[1]))
        EditableCard(background: .solid(CardSolid.palette[8]))
    }
    .padding(40)
}
