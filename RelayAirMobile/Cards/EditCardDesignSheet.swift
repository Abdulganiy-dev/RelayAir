//
//  EditCardDesignSheet.swift
//  RelayAirMobile
//
//  Design sheet — card centered by default (pinned to the top while the keyboard
//  is up), tools docked as circular glass buttons at the bottom. Each button morphs
//  into its own editor panel; while one is open the rest of the dock is hidden.
//

import SwiftUI
import PhotosUI
import PortalTransitions
import SFSymbols

struct EditCardDesignSheet: View {
    @Binding var background: CardGradient
    @Binding var content: CardContent
    @Binding var texture: CardTexture?
    @Binding var finish: CardFinish
    let portalID: String
    let portalNamespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var toolNamespace

    @State private var activeTool: DesignTool?

    /// Which mark slot a follow-up picker writes into.
    @State private var pickerSlot: MarkSlot = .image

    /// Set when a mark source is chosen; acted on once the dock has collapsed.
    @State private var pendingSource: MarkSource?

    @State private var isPickingSymbol = false
    @State private var isPickingPhoto = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var isKeyboardVisible = false

    private var cardSize: CGSize { EditableCard.compact }

    private var dockSpring: Animation {
        .spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0)
    }

    private let collapsedToolSize: CGFloat = 44
    private let expandedCornerRadius: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissSurroundings)

                GeometryReader { geo in
                    cardPreview
                        .position(
                            x: geo.size.width / 2,
                            y: isKeyboardVisible
                                ? Tokens.topPadding + cardSize.height / 2
                                : geo.size.height / 2
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(dockSpring, value: isKeyboardVisible)

            designDock
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background(AppColors.background(colorScheme: colorScheme).ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            HStack {
                Spacer()
                CircularButton(icon: "xmark") { dismiss() }
            }
            .padding(.horizontal, 16)
        }
        .fontDesign(Tokens.fontDesign)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(dockSpring) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(dockSpring) { isKeyboardVisible = false }
        }
        .onChange(of: activeTool) { previous, current in
            guard previous != nil, current == nil, pendingSource != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(480))
                openPendingPicker()
            }
        }
        .sfSymbolPicker(isPresented: $isPickingSymbol, selection: symbolName)
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, item in
            let slot = pickerSlot
            load(item) { mark(for: slot).wrappedValue = .imported($0) }
        }
    }

    private var cardPreview: some View {
        EditableCard(
            background: background,
            content: content,
            texture: texture,
            finish: finish,
            size: cardSize
        )
        .portal(id: portalID, as: .destination, in: portalNamespace)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Dock

    private var designDock: some View {
        GeometryReader { proxy in
            // Geometry can report 0 during the height morph — never feed that into frames.
            let expandedWidth = max(proxy.size.width, collapsedToolSize)

          
                HStack(alignment: .bottom, spacing: activeTool == nil ? 16 : 0) {
                    ForEach(DesignTool.docked) { tool in
                        let isExpanded = activeTool == tool
                        let isHidden = activeTool != nil && !isExpanded
                        let panelHeight = tool.expandedHeight(hasMark: hasMark(for: tool))

                        MorphingDesignToolChrome(
                  
                            width: isExpanded
                                ? expandedWidth
                                : (isHidden ? 1 : collapsedToolSize),
                            height: isExpanded ? panelHeight : collapsedToolSize,
                            cornerRadius: isExpanded
                                ? expandedCornerRadius
                                : collapsedToolSize / 2,
                            progress: isExpanded ? 1 : 0,
                            tool: tool,
                            collapsedSize: collapsedToolSize,
                            expandedWidth: expandedWidth,
                            expandedHeight: panelHeight,
                            colorScheme: colorScheme,
                            namespace: toolNamespace,
                            onExpand: {
                                withAnimation(dockSpring) { activeTool = tool }
                            }
                        ) {
                            expandedPanel(for: tool)
                        }
                        .opacity(isHidden ? 0 : 1)
                        .allowsHitTesting(!isHidden)
                        .layoutPriority(isExpanded ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            
        }
        .frame(height: dockExpandedHeight)
        .animation(dockSpring, value: activeTool)
        .animation(dockSpring, value: content.image != nil)
        .animation(dockSpring, value: content.icon != nil)
    }

    /// Grows with the media Remove row when that panel is open.
    private var dockExpandedHeight: CGFloat {
        guard let activeTool else { return collapsedToolSize }
        return activeTool.expandedHeight(hasMark: hasMark(for: activeTool))
    }

    private func hasMark(for tool: DesignTool) -> Bool {
        switch tool {
        case .image: content.image != nil
        case .icon:  content.icon != nil
        default:     false
        }
    }

    @ViewBuilder
    private func expandedPanel(for tool: DesignTool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
          
            switch tool {
            case .background:
                CardBackgroundGrid(background: $background)
            case .texture:
                CardTextureGrid(texture: $texture, background: background)
            case .finish:
         
                CardFinishGrid(finish: $finish, background: background, texture: texture)
            case .image:
                CardMarkChooser(slot: .image, mark: mark(for: .image)) { source in
                    pickerSlot = .image
                    pendingSource = source
                    collapseTool()
                }
            case .note:
                CardDesignNoteFields(
                    topNote: $content.topNote,
                    bottomNote: $content.bottomNote
                )
            case .icon:
                CardMarkChooser(slot: .icon, mark: mark(for: .icon)) { source in
                    pickerSlot = .icon
                    pendingSource = source
                    collapseTool()
                }
            }
        }
        .safeAreaBar(edge: .top, content: {
            HStack{
                Text(tool.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                    .padding(.vertical)
                Spacer()
            }

        })
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    // MARK: - Plumbing

    private func dismissSurroundings() {
        dismissKeyboard()
        guard activeTool != nil else { return }
        withAnimation(dockSpring) {
            activeTool = nil
        }
    }

    private func collapseTool() {
        dismissSurroundings()
    }

    private func mark(for slot: MarkSlot) -> Binding<CardMark?> {
        switch slot {
        case .image: $content.image
        case .icon:  $content.icon
        }
    }

    private func openPendingPicker() {
        guard let source = pendingSource else { return }
        pendingSource = nil
        switch source {
        case .symbol: isPickingSymbol = true
        case .photo:  isPickingPhoto = true
        }
    }

    private var symbolName: Binding<String?> {
        let slot = pickerSlot
        return Binding {
            if case .symbol(let name) = mark(for: slot).wrappedValue { return name }
            return nil
        } set: { newName in
            guard let newName else {
                if case .symbol = mark(for: slot).wrappedValue {
                    mark(for: slot).wrappedValue = nil
                }
                return
            }
            mark(for: slot).wrappedValue = .symbol(name: newName)
        }
    }

    private func load(_ item: PhotosPickerItem?, assign: @escaping (Data) -> Void) {
        guard let item else { return }
        Task {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { return }
            let bounded = CardArtwork.downsampled(raw, maxPixels: CardArtwork.markMaxPixels) ?? raw
            await MainActor.run {
                assign(bounded)
                photoSelection = nil
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var content = CardContent(
        image: .symbol(name: "building.columns.fill"),
        topNote: "EXPIRES 04 / 29",
        bottomNote: "Alex Morgan",
        icon: .symbol(name: "creditcard.fill")
    )
    @Previewable @State var texture: CardTexture? = .guilloche
    @Previewable @State var finish: CardFinish = .machined

    EditCardDesignSheet(
        background: .constant(.default),
        content: $content,
        texture: $texture,
        finish: $finish,
        portalID: "previewCard",
        portalNamespace: namespace
    )
}
