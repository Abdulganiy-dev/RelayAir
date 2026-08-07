//
//  CardBackgroundPicker.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Horizontal swatch strip. Circles rather than squares so a gradient's whole
//  sweep is visible in one glance.
//
//  Edges are handled per swatch with `scrollTransition` rather than by treating the
//  strip as one block. Each circle fades, shrinks and softens on its own as it
//  crosses an edge, which means it works on any surface, needs no scroll-offset
//  bookkeeping, and an edge with nothing beyond it simply has nothing to transition.
//

import SwiftUI

struct CardBackgroundPicker: View {
    @Binding var background: CardGradient

    private let swatchSize: CGFloat = 52

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(CardGradient.palette) { option in
                    Swatch(
                        gradient: option,
                        isSelected: option.id == background.id,
                        size: swatchSize
                    ) {
                        background = option
                    }
                    // .interactive, and driven off phase.value rather than
                    // phase.isIdentity: isIdentity is a boolean, so it would snap
                    // between two states at the edge instead of tracking the
                    // finger. phase.value runs -1 → 0 → +1 across the crossing,
                    // which is what makes this read as a fade.
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        let distance = abs(phase.value)
                        return content
                            .opacity(1 - distance)
                            .scaleEffect(1 - distance * 0.25)
                            .blur(radius: distance * 3)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Swatch

private struct Swatch: View {
    let gradient: CardGradient
    let isSelected: Bool
    let size: CGFloat
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(gradient.style)
                // The same rim the card gets, so a swatch previews the material
                // rather than just the colour.
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.30), .white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .overlay(
                    Circle()
                        .stroke(AppColors.strokeSubtle(colorScheme: colorScheme), lineWidth: 0.5)
                )
                .frame(width: size, height: size)
                .padding(5)
                .overlay {
                    // Ring sits outside the swatch with a gap, so it never
                    // interferes with reading the colour underneath.
                    Circle()
                        .strokeBorder(
                            AppColors.textInverted(colorScheme: colorScheme),
                            lineWidth: 2
                        )
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.86)
                }
                .contentShape(Circle())
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
        .accessibilityLabel(gradient.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    @Previewable @State var background = CardGradient.default

    return CardBackgroundPicker(background: $background)
        .padding(.vertical, 24)
        .background(AppColors.background(colorScheme: .light))
}
