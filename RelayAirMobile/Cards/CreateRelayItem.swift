//
//  CardEditorView.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Card on top, controls underneath. Everything about how the card looks is edited in
//  the design sheet; this screen only holds the state and hands it over.
//

import SwiftUI
import PortalTransitions

struct CreateRelayItem: View {
    let type: RelayType
    @Binding var screenType: EntryPage
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var portalNamespace

    @State private var background: CardGradient = .default
    @State private var content = CardContent()
    @State private var texture: CardTexture?
    @State private var isEditingCard = false

    private var portalID: String { "relayCard.\(type.id)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                EditableCard(background: background, content: content, texture: texture)
                    .portal(id: portalID, as: .source, in: portalNamespace)

            
            }
            .padding(.horizontal)
            .padding(.top, Tokens.topPadding)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    
                    isEditingCard = true
                } label: {
                    Label("Edit Card", systemImage: "paintpalette")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(BouncyButton())
                .glassEffect(.clear, in: .capsule)
                .hapticFeedback(style: .soft)

                Button {
                    // TODO: persist relay item
                    withAnimation(Tokens.fastBounceAnimation) {
                        screenType = .main
                    }
                } label: {
                    Label("Create", systemImage: "checkmark")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(BouncyButton())
                .glassEffect(.clear, in: .capsule)
                .hapticFeedback(style: .soft)
            }
            .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme))
            .padding(.horizontal, 16)
        }
        .safeAreaBar(edge: .top) {
            HStack {
                Spacer()
                CircularButton(icon: "xmark") {
                    withAnimation(Tokens.fastBounceAnimation) {
                        screenType = .main
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .fullScreenCover(isPresented: $isEditingCard) {
            EditCardDesignSheet(
                background: $background,
                content: $content,
                texture: $texture,
                portalID: portalID,
                portalNamespace: portalNamespace
            )
        }
        .portalTransition(
            id: portalID,
            in: portalNamespace,
            isActive: $isEditingCard,
            animation: Tokens.portalCard
        ) {
            
            EditableCard(background: background, content: content, texture: texture, size: nil)
        }
    }
}

#Preview {
    PortalContainer {
        CreateRelayItem(type: .creditCard, screenType: .constant(.main))
    }
}
