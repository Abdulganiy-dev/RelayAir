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

    @Environment(RelayItemStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var portalNamespace

    @State private var background: CardGradient
    @State private var content: CardContent
    @State private var texture: CardTexture?
    @State private var finish: CardFinish
    @State private var tag: String
    @State private var details = RelayItemDetails()
    @State private var customFieldEditorMode: CustomFieldEditorMode?
    @State private var addedCustomFieldID: UUID?
    @State private var isEditingCard = false
    @State private var isKeyboardVisible = false
    @State private var saveError: String?

    private var portalID: String { "relayCard.edit.design.\(item.id.uuidString)" }
    private var canSave: Bool {
        guard details.isComplete(for: item.type) else { return false }
        guard item.type == .custom else { return true }
        return !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && customFieldEditorMode == nil
    }

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
        .presentationBackground(.clear)
    }

    private var editor: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 34) {
                    EditableCard(background: background, content: content, texture: texture, finish: finish)
                        .portal(id: arrivalPortalID, as: .destination, in: arrivalPortalNamespace)
                        .portal(id: portalID, as: .source, in: portalNamespace)

                    RelayItemForm(
                        type: item.type,
                        tag: $tag,
                        details: $details,
                        customFieldEditorMode: $customFieldEditorMode,
                        onCustomFieldAdded: { addedCustomFieldID = $0 }
                    )
                }
                .padding(.horizontal)
                .padding(.top, Tokens.topPadding)
                .padding(.bottom, 40)
            }
            .onChange(of: customFieldEditorMode) { _, mode in
                guard mode == nil, let id = addedCustomFieldID else { return }
                addedCustomFieldID = nil
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.smooth) {
                        scrollProxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .relayAppBackground()
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .task {
            await loadDetails()
        }
        .safeAreaBar(edge: .bottom) {
            if isKeyboardVisible {
                HStack {
                    Spacer()
                    CircularButton(icon: "checkmark", action: dismissKeyboard)
                        .accessibilityLabel("Done editing")
                }
                .padding(.horizontal, 16)
            } else {
                HStack(spacing: 12) {
                    CircularButton(icon: "paintpalette") {
                        isEditingCard = true
                    }
                    .accessibilityLabel("Edit Card")

                    CircularButton(
                        icon: "checkmark",
                        iconColor: canSave ? nil : AppColors.iconDisabled(colorScheme: colorScheme)
                    ) {
                        save()
                    }
                    .accessibilityLabel("Save")
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .animation(.smooth(duration: 0.25), value: canSave)

                    Spacer(minLength: 0)

                    if item.type == .custom {
                        CircularButton(icon: "plus") {
                            customFieldEditorMode = .adding
                        }
                        .accessibilityLabel("Add custom field")
                        .disabled(customFieldEditorMode != nil)
                        .opacity(customFieldEditorMode == nil ? 1 : 0.45)
                    }
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
        .safeAreaBar(edge: .top) {
            HStack {
                Spacer()
                CircularButton(icon: "xmark", action: onClose)
                    .accessibilityLabel("Close")
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
                .customTextStyle(.action)
        } message: {
            Text(saveError ?? "")
                .customTextStyle(.body)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private func loadDetails() async {
        do {
            details = try await store.details(for: item, to: .edit)
        } catch {
            onClose()
        }
    }

    private func save() {
        guard canSave else { return }
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
