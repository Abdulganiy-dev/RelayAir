//
//  CircularSwatch.swift
//  RelayAirMobile
//
//  Labeled circular chip used by the card design grids. Selection ring sits
//  outside the swatch so it never fights the colour underneath.
//

import SwiftUI

struct CircularSwatch<Preview: View>: View {
    let isSelected: Bool
    let label: String
    @ViewBuilder let preview: () -> Preview
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 52

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(AppColors.strokeSubtle(colorScheme: colorScheme), lineWidth: 0.5)
                    )
                    .padding(5)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                AppColors.textInverted(colorScheme: colorScheme),
                                lineWidth: 2
                            )
                            .opacity(isSelected ? 1 : 0)
                            .scaleEffect(isSelected ? 1 : 0.86)
                    }

                Text(label)
                    .customTextStyle(.smallLabel, color: .inverted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .light)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }
}
