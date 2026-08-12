//
//  EditRelayItem.swift
//  RelayAirMobile
//
//  Same layout as create — card on top, form underneath — but for a saved item.
//  The wallet card portals in as the destination.
//

import SwiftUI
import PortalTransitions
import SQLiteData

struct EditRelayItem: View {
    let item: RelayItem
    let arrivalPortalID: String
    let arrivalPortalNamespace: Namespace.ID
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(RelayItemStore.self) private var store
    @Namespace private var portalNamespace

    @State private var background: CardGradient
    @State private var content: CardContent
    @State private var texture: CardTexture?
    @State private var finish: CardFinish
    @State private var tag: String
    @State private var details = RelayItemDetails()
    @State private var isEditingCard = false
    @State private var isKeyboardVisible = false
    @State private var saveError: String?

    private var portalID: String { "relayCard.edit.design.\(item.id.uuidString)" }
    private var canSave: Bool { details.isComplete(for: item.type) }

    init(
        item: RelayItem,
        arrivalPortalID: String,
        arrivalPortalNamespace: Namespace.ID,
        onClose: @escaping () -> Void
    ) {
        self.item = item
        self.arrivalPortalID = arrivalPortalID
        self.arrivalPortalNamespace = arrivalPortalNamespace
        self.onClose = onClose
        _background = State(initialValue: item.background)
        _content = State(initialValue: item.content)
        _texture = State(initialValue: item.texture)
        _finish = State(initialValue: item.finish)
        _tag = State(initialValue: item.tag)
    }

    var body: some View {
        NavigationStack {
            editor
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(AppColors.background(colorScheme: colorScheme).ignoresSafeArea())
        .presentationBackground(AppColors.background(colorScheme: colorScheme))
    }

    private var editor: some View {
        ScrollView {
            VStack(spacing: 34) {
                EditableCard(background: background, content: content, texture: texture, finish: finish)
                    .portal(id: arrivalPortalID, as: .destination, in: arrivalPortalNamespace)
                    .portal(id: portalID, as: .source, in: portalNamespace)

                RelayItemForm(type: item.type, tag: $tag, details: $details)
            }
            .padding(.horizontal)
            .padding(.top, Tokens.topPadding)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(AppColors.background(colorScheme: colorScheme).ignoresSafeArea())
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isKeyboardVisible {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadDetails()
        }
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
                        save()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .hapticFeedback(style: .soft)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .animation(.smooth(duration: 0.25), value: canSave)
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
                CircularButton(icon: "xmark", action: onClose)
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
        .alert("Couldn't save", isPresented: .constant(saveError != nil)) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private func loadDetails() async {
        do {
            details = try await store.details(for: item)
        } catch {
            onClose()
        }
    }

    private func save() {
        do {
            var updated = item
            updated.tag = tag
            updated.gradientID = background.id
            updated.content = content
            updated.texture = texture
            updated.finish = finish
            try store.update(updated, details: details)
            onClose()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

//#Preview {
//    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
//    @Previewable @Namespace var namespace
//    PortalContainer {
//        EditRelayItem(
//            item: RelayItem(id: UUID(), type: .creditCard),
//            arrivalPortalID: "preview",
//            arrivalPortalNamespace: namespace,
//            onClose: {}
//        )
//        .environment(RelayItemStore())
//    }
//}
