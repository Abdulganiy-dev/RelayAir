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
    @State private var finish: CardFinish = .frosted
    @State private var details = RelayItemDetails()
    @State private var isEditingCard = false
    @State private var isKeyboardVisible = false

    private var portalID: String { "relayCard.\(type.id)" }

    private var canCreate: Bool { details.isComplete(for: type) }

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                EditableCard(background: background, content: content, texture: texture, finish: finish)
                    .portal(id: portalID, as: .source, in: portalNamespace)

                RelayItemForm(type: type, details: $details)
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
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
            if !isKeyboardVisible {
                HStack(spacing: 12) {
                    Button {
                        isEditingCard = true
                    } label: {
                        Label("Edit Card", systemImage: "paintpalette")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)

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
                    .glassEffect(.regular.interactive(), in: .capsule)
       
                   
                    .hapticFeedback(style: .soft)
                    .disabled(!canCreate)
                    .opacity(canCreate ? 1 : 0.45)
                    .animation(.smooth(duration: 0.25), value: canCreate)
                }
                .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme))
                .padding(.horizontal, 16)
           
            }
        }
        .animation(.smooth(duration: 0.28), value: isKeyboardVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
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
                finish: $finish,
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
            EditableCard(background: background, content: content, texture: texture, finish: finish, size: nil)
        }
    }
}

#Preview {
    PortalContainer {
        CreateRelayItem(type: .creditCard, screenType: .constant(.main))
    }
}
