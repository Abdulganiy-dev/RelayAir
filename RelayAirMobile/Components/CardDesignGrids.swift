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
