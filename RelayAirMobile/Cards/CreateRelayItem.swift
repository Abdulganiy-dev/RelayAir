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
import SQLiteData

struct CreateRelayItem: View {
    let type: RelayType
    @Environment(\.dismiss) private var dismiss
    @Environment(RelayItemStore.self) private var store
    @Namespace private var portalNamespace

    @State private var background: CardGradient = .default
    @State private var content = CardContent()
    @State private var texture: CardTexture?
    @State private var finish: CardFinish = .frosted
    @State private var tag = ""
    @State private var details = RelayItemDetails()
    @State private var isEditingCard = false
    @State private var isKeyboardVisible = false
    @State private var saveError: String?

    private var portalID: String { "relayCard.\(type.id)" }

    private var canCreate: Bool { details.isComplete(for: type) }

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                EditableCard(background: background, content: content, texture: texture, finish: finish)
                    .portal(id: portalID, as: .source, in: portalNamespace)

                RelayItemForm(type: type, tag: $tag, details: $details)
            }
            .padding(.horizontal)
            .padding(.top, Tokens.topPadding)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
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
                            .customTextStyle(.action, color: .inverted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .hapticFeedback(style: .soft)

                    Button {
                        save()
                    } label: {
                        Label("Create", systemImage: "checkmark")
                            .customTextStyle(.action, color: canCreate ? .inverted : .disabled)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .hapticFeedback(style: .soft)
                    .disabled(!canCreate)
                    .opacity(canCreate ? 1 : 0.45)
                    .animation(.smooth(duration: 0.25), value: canCreate)
                }
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
        .alert("Couldn't save", isPresented: .constant(saveError != nil)) {
            Button("OK") { saveError = nil }
                .customTextStyle(.action)
        } message: {
            Text(saveError ?? "")
                .customTextStyle(.body)
        }
    }

    private func save() {
        do {
            try store.create(
                type: type,
                tag: tag,
                details: details,
                background: background,
                content: content,
                texture: texture,
                finish: finish
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    PortalContainer {
        NavigationStack {
            CreateRelayItem(type: .creditCard)
                .environment(RelayItemStore())
                .relayAppBackground()
        }
    }
}
