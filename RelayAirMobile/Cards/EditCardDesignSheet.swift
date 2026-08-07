//
//  EditCardDesignSheet.swift
//  RelayAirMobile
//
//  The design sheet — background then content, with the card pinned above both so
//  every change is visible while it is being made. Portal destination.
//
//  Content is four corner slots on the card:
//
//      top-leading      mark            bottom-leading   write-up
//      top-trailing     note            bottom-trailing  mark
//
//  Both mark slots are one tappable row. Tapping opens a chooser rather than putting
//  two competing buttons on screen: a slot holds one thing, so the choice belongs in
//  a moment of its own, not as a permanent pair of controls.
//

import SwiftUI
import PhotosUI
import PortalTransitions
import SFSymbols

struct EditCardDesignSheet: View {
    @Binding var background: CardGradient
    @Binding var content: CardContent
    @Binding var texture: CardTexture?
    let portalID: String
    let portalNamespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Which slot the chooser is open for.
    @State private var chooserSlot: MarkSlot?

    /// Which slot a follow-up picker writes into. Held separately from `chooserSlot`
    /// because the chooser is already dismissed by the time the picker opens.
    @State private var pickerSlot: MarkSlot = .image

    /// Set when the chooser is tapped, acted on once the overlay has cleared —
    /// presenting a picker while the overlay is still animating out can drop it.
    @State private var pendingSource: MarkSource?

    @State private var isPickingSymbol = false
    @State private var isPickingPhoto = false
    @State private var photoSelection: PhotosPickerItem?

    private var cardSize: CGSize { EditableCard.compact }

    var body: some View {
        VStack(spacing: 16) {
            EditableCard(background: background, content: content, texture: texture, size: cardSize)
                .portal(id: portalID, as: .destination, in: portalNamespace)
                .padding(.top, Tokens.topPadding)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    backgroundSection
                    textureSection
                    markSection(.image)
                    noteSection
                    markSection(.icon)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollDismissesKeyboard(.interactively)
        }
        .blur(radius: chooserSlot == nil ? 0 : 14)
        .animation(chooserSpring, value: chooserSlot)
      
        .allowsHitTesting(chooserSlot == nil)
        // Tapping anywhere off a control puts the keyboard away. Buttons still win the
        // tap — a container gesture only fires where no child claimed it.
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
        .background(AppColors.background(colorScheme: colorScheme).ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            HStack {
                Spacer()
                CircularButton(icon: "xmark") { dismiss() }
            }
            .padding(.horizontal, 16)
        }
        .fontDesign(Tokens.fontDesign)
        .overlay(alignment: .bottom) {
            markChooserOverlay
        }
        .onChange(of: chooserSlot) { previous, current in
            guard previous != nil, current == nil, pendingSource != nil else { return }
            // Let the overlay finish fading before the system picker presents.
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

    // MARK: - Background

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Background", subtitle: "")
                .padding(.horizontal)
           
            CardBackgroundPicker(background: $background)
        }
    }

    // MARK: - Texture

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Texture", subtitle: "Surface")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Leading `nil` is the "no texture" option, so clearing one is the
                    // same gesture as choosing one.
                    ForEach([CardTexture?.none] + CardTexture.allCases.map(Optional.init), id: \.?.id) { option in
                        textureSwatch(option)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                let distance = abs(phase.value)
                                return content
                                    .opacity(1 - distance)
                                    .scaleEffect(1 - distance * 0.25)
                                    .blur(radius: distance * 3)
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    /// Circular swatches matching the background strip. Each one wears the user's
    /// *current* background so the texture is judged against what it will sit on.
    /// Pattern is cropped at card density (not scaled down) — otherwise carbon /
    /// pinstripe / guilloché fall below a pixel. The x offset samples off the hollow
    /// centre of the guilloché rosette; the rest are uniform, so it costs them nothing.
    private func textureSwatch(_ option: CardTexture?) -> some View {
        let isSelected = option == texture
        let size: CGFloat = 52

        return Button {
            texture = option
        } label: {
            ZStack {
                Circle().fill(background.style)

                if let option {
                    CardTextureLayer(texture: option)
                        .frame(width: EditableCard.standard.width, height: EditableCard.standard.height)
                        .offset(x: 88)
                }
            }
            .frame(width: size, height: size)
            .compositingGroup()
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .overlay(
                Circle()
                    .stroke(AppColors.strokeSubtle(colorScheme: colorScheme), lineWidth: 0.5)
            )
            .padding(5)
            .overlay {
                Circle()
                    .strokeBorder(
                        AppColors.textInverted(colorScheme: colorScheme),
                        lineWidth: 2
                    )
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.86)
            }
            .contentShape(Circle())
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
        .accessibilityLabel(option?.name ?? "No texture")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Marks

    private func markSection(_ slot: MarkSlot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(slot.title, subtitle: slot.subtitle)

            Button {
                withAnimation(chooserSpring) {
                    chooserSlot = slot
                }
            } label: {
                HStack(spacing: 14) {
                    markPreview(mark(for: slot).wrappedValue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(headline(for: slot))
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
                        Text(detail(for: slot))
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                    }
                    .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(BouncyButtonSecondStyle())
            .hapticFeedback(style: .soft)
            .glassyBackgroundWithStroke(cornerRadius: 15)

            // Tints only apply to a symbol — imported artwork keeps its own colours,
            // so the row would be a control that does nothing.
            if case .symbol(let name, let selected) = mark(for: slot).wrappedValue {
                tintRow(slot: slot, symbol: name, selected: selected)
            }
        }
        .padding(.horizontal)
        .animation(.smooth(duration: 0.25), value: mark(for: slot).wrappedValue)
    }

    @ViewBuilder
    private func markPreview(_ mark: CardMark?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        Group {
            switch mark {
            case .symbol(let name, let tint):
                Image(systemName: name)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(tint.color)

            case .imported(let data):
                if let image = CardArtwork.image(data) {
                    image.resizable().scaledToFit().padding(7)
                }

            case nil:
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 48, height: 48)
        // Dark chip rather than the sheet surface: tints skew light, and most of them
        // would disappear against it.
        .background(Color(hex: "#2C3038"))
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }

    private func tintRow(slot: MarkSlot, symbol: String, selected: CardMarkTint) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CardMarkTint.palette) { tint in
                    Button {
                        mark(for: slot).wrappedValue = .symbol(name: symbol, tint: tint)
                    } label: {
                        Circle()
                            .fill(tint.color)
                            .overlay(
                                Circle().strokeBorder(
                                    AppColors.strokeSubtle(colorScheme: colorScheme),
                                    lineWidth: 1
                                )
                            )
                            .frame(width: 28, height: 28)
                            .padding(4)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        AppColors.textInverted(colorScheme: colorScheme),
                                        lineWidth: 2
                                    )
                                    .opacity(tint.id == selected.id ? 1 : 0)
                                    .scaleEffect(tint.id == selected.id ? 1 : 0.86)
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(BouncyButtonSecondStyle())
                    .hapticFeedback(style: .soft)
                    .accessibilityLabel(tint.name)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)
    }

    // MARK: - Notes

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Note", subtitle: "Top right")
                CustomTextField(
                    title: "Note",
                    text: $content.topNote,
                    shouldIncludeLineLimit: false,
                    placeholder: "Issuer, date, reference",
                    leadingSystemImageName: "tag"
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Write-up", subtitle: "Bottom left")
                CustomTextField(
                    title: "Write-up",
                    text: $content.bottomNote,
                    shouldIncludeLineLimit: false,
                    placeholder: "Name or description",
                    leadingSystemImageName: "text.alignleft"

                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Plumbing

    private func mark(for slot: MarkSlot) -> Binding<CardMark?> {
        switch slot {
        case .image: $content.image
        case .icon:  $content.icon
        }
    }

    private func headline(for slot: MarkSlot) -> String {
        switch mark(for: slot).wrappedValue {
        case .symbol(let name, _): name
        case .imported:            "Imported image"
        case nil:                  "Choose"
        }
    }

    private func detail(for slot: MarkSlot) -> String {
        switch mark(for: slot).wrappedValue {
        case .symbol:   "SF Symbol · tap to change"
        case .imported: "Tap to change"
        case nil:       "Pick an icon or import an image"
        }
    }

    /// Softer than `menuJump` so the card has time to read as a pop, not a snap.
    private var chooserSpring: Animation {
        .spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0)
    }

    private var markChooserOverlay: some View {
        ZStack(alignment: .bottom) {
            if chooserSlot != nil {
                // Transparent only — blur lives on the content below, not a scrim fill.
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissChooser() }
                    .transition(.opacity)
            }

            if let slot = chooserSlot {
                MarkSourceChooser(
                    slot: slot,
                    hasMark: mark(for: slot).wrappedValue != nil,
                    colorScheme: colorScheme
                ) { source in
                    pickerSlot = slot
                    pendingSource = source
                    dismissChooser()
                } onRemove: {
                    mark(for: slot).wrappedValue = nil
                    dismissChooser()
                }
                .modalSurface(cornerRadius: 32)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .transition(
                    .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.92, anchor: .bottom))
                )
            }
        }
        .animation(chooserSpring, value: chooserSlot)
    }

    private func dismissChooser() {
        withAnimation(chooserSpring) {
            chooserSlot = nil
        }
    }

    /// Runs once the chooser has finished dismissing. Presenting the symbol or photo
    /// picker from inside the chooser's own action would race its dismissal and the
    /// follow-up picker would never appear.
    private func openPendingPicker() {
        guard let source = pendingSource else { return }
        pendingSource = nil
        switch source {
        case .symbol: isPickingSymbol = true
        case .photo:  isPickingPhoto = true
        }
    }

    /// Bridges the picker's `String?` onto the active slot, keeping whatever tint was
    /// already chosen there. Clearing the selection clears the mark.
    private var symbolName: Binding<String?> {
        let slot = pickerSlot
        return Binding {
            if case .symbol(let name, _) = mark(for: slot).wrappedValue { return name }
            return nil
        } set: { newName in
            guard let newName else {
                if case .symbol = mark(for: slot).wrappedValue {
                    mark(for: slot).wrappedValue = nil
                }
                return
            }
            var tint = CardMarkTint.default
            if case .symbol(_, let existing) = mark(for: slot).wrappedValue { tint = existing }
            mark(for: slot).wrappedValue = .symbol(name: newName, tint: tint)
        }
    }

    /// Photos arrive at full capture resolution; they are bounded on the way in so a
    /// card never carries megabytes of pixels it will draw at 50pt.
    private func load(_ item: PhotosPickerItem?, assign: @escaping (Data) -> Void) {
        guard let item else { return }
        Task {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { return }
            let bounded = CardArtwork.downsampled(raw, maxPixels: CardArtwork.markMaxPixels) ?? raw
            await MainActor.run {
                assign(bounded)
                // Cleared so re-picking the same photo still fires onChange.
                photoSelection = nil
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private func sectionLabel(_ title: String, subtitle: String) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.65)
            }
        }
        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
    }
}

// MARK: - Slots

private enum MarkSlot: String, Identifiable {
    case image
    case icon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: "Image"
        case .icon:  "Icon"
        }
    }

    var subtitle: String {
        switch self {
        case .image: "Top left · max 50 × 50"
        case .icon:  "Bottom right · max 50 × 50"
        }
    }
}

private enum MarkSource {
    case symbol
    case photo
}

// MARK: - Chooser

/// Two ways to fill a slot, presented as a floating card. Deliberately only reachable
/// from a mark row — it has no meaning without a slot to write into.
private struct MarkSourceChooser: View {
    let slot: MarkSlot
    let hasMark: Bool
    let colorScheme: ColorScheme
    let onChoose: (MarkSource) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
                Text(slot.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
            }

            VStack(spacing: 12) {
                option(
                    icon: "square.grid.2x2.fill",
                    title: "Choose an icon",
                    detail: "Pick from SF Symbols and tint it"
                ) { onChoose(.symbol) }

                option(
                    icon: "photo.fill",
                    title: "Import an image",
                    detail: "Use a photo from your library"
                ) { onChoose(.photo) }

                if hasMark {
                    option(
                        icon: "trash.fill",
                        title: "Remove",
                        detail: "Leave this corner empty",
                        isDestructive: true,
                        action: onRemove
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fontDesign(Tokens.fontDesign)
    }

    private func option(
        icon: String,
        title: String,
        detail: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        isDestructive
                            ? Color(hex: "#D9534F")
                            : AppColors.textPrimary(colorScheme: colorScheme)
                    )
                    .frame(width: 44, height: 44)
                    .glassEffect(.clear, in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(
                            isDestructive
                                ? Color(hex: "#D9534F")
                                : AppColors.textPrimary(colorScheme: colorScheme)
                        )
                    Text(detail)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
        .glassyBackgroundWithStroke(cornerRadius: 18)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var content = CardContent(
        image: .symbol(name: "building.columns.fill", tint: .default),
        topNote: "EXPIRES 04 / 29",
        bottomNote: "Alex Morgan",
        icon: .symbol(name: "creditcard.fill", tint: .default)
    )
    @Previewable @State var texture: CardTexture? = .guilloche

    return EditCardDesignSheet(
        background: .constant(.default),
        content: $content,
        texture: $texture,
        portalID: "previewCard",
        portalNamespace: namespace
    )
}
