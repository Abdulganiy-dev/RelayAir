//
//  CardDesignGrids.swift
//  RelayAirMobile
//
//  3-column circular pickers for card background gradients and surface textures.
//

import SwiftUI

struct CardBackgroundGrid: View {
    @Binding var background: CardGradient

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(CardGradient.palette) { option in
                    CircularSwatch(
                        isSelected: option.id == background.id,
                        label: option.name
                    ) {
                        Circle().fill(option.style)
                    } action: {
                        background = option
                    }
                    .applyBlurScrollTransition()
                 
//                    .scrollTransition(., axis: .vertical) { content, phase in
//                        let distance = abs(phase.value)
//                        return content
//                            .opacity(1 - distance)
//                            .scaleEffect(1 - distance * 0.25)
//                            .blur(radius: distance * 3)
//                    }
                }
            }

           
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom) {
            Text("  ")
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
   
    }
}

struct CardTextureGrid: View {
    @Binding var texture: CardTexture?
    let background: CardGradient

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    /// Leading `nil` is the "no texture" option, so clearing one is the same
    /// gesture as choosing one.
    private var options: [CardTexture?] {
        [nil] + CardTexture.allCases.map(Optional.init)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(options, id: \.?.id) { option in
                    CircularSwatch(
                        isSelected: option == texture,
                        label: option?.name ?? "None"
                    ) {
                        ZStack {
                            Circle().fill(background.style)
                            if let option {
                                CardTextureLayer(texture: option)
                                    .frame(
                                        width: EditableCard.standard.width,
                                        height: EditableCard.standard.height
                                    )
                                    .offset(x: 88)
                            }
                        }
                        .frame(width: 52, height: 52)
                        .compositingGroup()
                        .clipShape(Circle())
                    } action: {
                        texture = option
                    }
                    .applyBlurScrollTransition()
                }
            }

        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom) {
            Text("  ")
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)

    }
}

// MARK: - Finish

struct CardFinishGrid: View {
    @Binding var finish: CardFinish
    let background: CardGradient
    let texture: CardTexture?

    @Environment(\.colorScheme) private var colorScheme

    private let swatchSize = CGSize(width: 96, height: 60)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(CardFinish.allCases) { option in
                Button {
                    finish = option
                } label: {
                    VStack(spacing: 10) {
                        EditableCard(
                            background: background,
                            texture: texture,
                            finish: option,
                            size: swatchSize,
       
                            cornerRadius: 11
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(
                                    AppColors.textInverted(colorScheme: colorScheme),
                                    lineWidth: 2
                                )
                                .padding(-5)
                                .opacity(option == finish ? 1 : 0)
                                .scaleEffect(option == finish ? 1 : 0.9)
                        }

                        Text(option.name)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BouncyButtonSecondStyle())
                .hapticFeedback(style: .soft)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option == finish ? [.isSelected] : [])
                .animation(.spring(response: 0.32, dampingFraction: 0.7), value: finish)
            }
        }

        .padding(.top, 10)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
    }
}
