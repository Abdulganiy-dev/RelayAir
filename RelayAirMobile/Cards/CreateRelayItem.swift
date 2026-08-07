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
import PortalTransitions

struct CreateRelayItem: View {
    let type: RelayType
    @Binding var screenType: EntryPage
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var portalNamespace

    @State private var background: CardBackground = .default
    @State private var kind: CardBackgroundKind = .gradient
    @State private var content = CardContent()
    @State private var isEditingCard = false

    private var portalID: String { "relayCard.\(type.id)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                EditableCard(background: background, content: content)
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
                kind: $kind,
                content: $content,
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
            
            EditableCard(background: background, content: content, size: nil)
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
    PortalContainer {
        CreateRelayItem(type: .creditCard, screenType: .constant(.main))
    }
}
