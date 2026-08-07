//
//  CardBackgroundPicker.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Twelve swatches per kind, three rows of four. Circles rather than squares so a
//  gradient's whole sweep is visible in one glance.
//

import SwiftUI

struct CardBackgroundPicker: View {
    @Binding var background: CardBackground
    @Binding var kind: CardBackgroundKind

    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 18),
        count: 4
    )

    var body: some View {
        VStack(spacing: 22) {
            Picker("Background", selection: $kind) {
                ForEach(CardBackgroundKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(swatches) { option in
                    Swatch(
                        background: option,
                        isSelected: option.id == background.id
                    ) {
                        background = option
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: kind)
    }

    private var swatches: [CardBackground] {
        switch kind {
        case .colour:   CardSolid.palette.map(CardBackground.solid)
        case .gradient: CardGradient.palette.map(CardBackground.gradient)
        }
    }
}

// MARK: - Swatch

private struct Swatch: View {
    let background: CardBackground
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(background.style)
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
                .aspectRatio(1, contentMode: .fit)
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
        .accessibilityLabel(background.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    @Previewable @State var background = CardBackground.default
    @Previewable @State var kind = CardBackgroundKind.gradient

    return CardBackgroundPicker(background: $background, kind: $kind)
        .padding(24)
}
