//
//  CardEditorView.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Card on top, controls underneath. Background images and textures will join the
//  kind picker; nothing else about this screen should need to move when they do.
//

import SwiftUI

struct CreateRelayItem: View {
    let type: RelayType
    @Binding var screenType: EntryPage
    @Environment(\.colorScheme) private var colorScheme

    @State private var background: CardBackground = .default
    @State private var kind: CardBackgroundKind = .gradient

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                EditableCard(background: background)
                    .padding(.top, 12)

                Text(background.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                    .contentTransition(.opacity)
                    .animation(.smooth(duration: 0.25), value: background)

                CardBackgroundPicker(background: $background, kind: $kind)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .safeAreaBar(edge: .top) {
            HStack {
                Text(type.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme))

                Spacer()

                Button("Done") {
                    withAnimation(Tokens.fastBounceAnimation) {
                        screenType = .main
                    }
                }
                .fontWeight(.semibold)
                .buttonStyle(BouncyButton())
                .hapticFeedback(style: .soft)
            }
            .padding(.horizontal, 16)
        }
        // Keep the chosen kind and the shown background in step when the user
        // switches tabs — otherwise the ring vanishes onto a grid it isn't in.
        .onChange(of: kind) { _, newKind in
            guard background.kind != newKind else { return }
            background = switch newKind {
            case .colour:   .solid(CardSolid.palette[0])
            case .gradient: .gradient(CardGradient.palette[1])
            }
        }
    }
}

#Preview {
    CreateRelayItem(type: .creditCard, screenType: .constant(.main))
}
