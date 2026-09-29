//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//


import SQLiteData
import SwiftUI
import PortalTransitions

private enum MainNavigationRoute: Hashable {
    case createRelayItem(RelayType)
    case settings
    case scan
}

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(RelayItemStore.self) private var store
    @Binding var hideStatusBar: Bool
    @Namespace private var editPortalNamespace
    @Namespace private var navigationTransitionNamespace
    @State private var navigationPath: [MainNavigationRoute] = []
    @State private var isAddMenuPresented = false
    @State private var selectedRelayTypeAfterMenuDismissal: RelayType?
    @State private var isRelayItemOptionMenuOpen = false
    @State private var itemBeingEdited: RelayItem?
    @State private var dotItems = Self.makeDotItems()
    @State private var lastDotHapticTime: Date = .distantPast
    @State private var pulseClearTask: Task<Void, Never>?
    @State private var cardShakeOffset: CGFloat = 0
    @State private var cardShakeTask: Task<Void, Never>?
    @State private var cardFrameInGlobal: CGRect = .zero
    @State private var gridFrameInGlobal: CGRect = .zero
    @State private var rippleOrigin: CGPoint = .zero
    @State private var rippleTrigger = 0
    @State private var cardAdvanceTask: Task<Void, Never>?
    @State private var itemPendingDeletion: RelayItem?

    private static let gridColumnCount = 20
    private static let gridHeight: CGFloat = 200
    private static let gridSpacing: CGFloat = 4
    private static let dotSize: CGFloat = 3
    private static let dotPadding: CGFloat = 2

    private static let dragInfluenceRadius: CGFloat = 44
    private static let editPortalID = "relayCard.wallet"
    private static let addTransitionID = "createRelayItem"
    private static let settingsTransitionID = "settingsPage"
    private static let scanTransitionID = "scanPage"

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: gridSpacing),
        count: gridColumnCount
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                ScrollView(content: {
                    LazyVStack{
                        ForEach(store.items) { item in
                            SavedItemCard(
                                item: item,
                                portalID: Self.editPortalID,
                                portalNamespace: editPortalNamespace
                            )
                        }
                    }
                    .frame(maxWidth: .infinity,maxHeight: .infinity)
                })
                .matchedTransitionSource(id: Self.settingsTransitionID, in: navigationTransitionNamespace)
                .matchedTransitionSource(id: Self.addTransitionID, in: navigationTransitionNamespace)
                .matchedTransitionSource(id: Self.scanTransitionID, in: navigationTransitionNamespace)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: MainNavigationRoute.settings) {
                            Label("Settings", systemImage: "gear")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(Tokens.fastBounceAnimation) {
                                isAddMenuPresented = true
                            }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }

                    ToolbarSpacer(.flexible, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        NavigationLink(value: MainNavigationRoute.scan) {
                            Label("Scan", systemImage: "document.viewfinder")
                        }
                    }
                }
                .navigationDestination(for: MainNavigationRoute.self) { route in
                    switch route {
                    case .createRelayItem(let type):
                        CreateRelayItem(type: type)
                            .navigationTransition(.zoom(sourceID: Self.addTransitionID, in: navigationTransitionNamespace))
                    case .settings:
                        EmptyToolbarDestinationView()
                            .navigationTransition(.zoom(sourceID: Self.settingsTransitionID, in: navigationTransitionNamespace))
                    case .scan:
                        EmptyToolbarDestinationView()
                            .navigationTransition(.zoom(sourceID: Self.scanTransitionID, in: navigationTransitionNamespace))
                    }
                }
                .fullScreenCover(item: $itemBeingEdited) { item in
                    EditRelayItem(
                        item: item,
                        arrivalPortalID: Self.editPortalID,
                        arrivalPortalNamespace: editPortalNamespace,
                        onClose: {
                            itemBeingEdited = nil
                        }
                    )
                    .environment(store)
                }
                .portalTransition(
                    id: Self.editPortalID,
                    in: editPortalNamespace,
                    isActive: isEditingItem,
                    animation: Tokens.portalCard
                ) {
                    if let item = itemBeingEdited ?? store.currentRelayItem {
                        EditableCard(
                            background: item.background,
                            content: item.content,
                            texture: item.texture,
                            finish: item.finish,
                            size: nil
                        )
                    }
                }
                .alert(
                    "Delete this card?",
                    isPresented: Binding(
                        get: { itemPendingDeletion != nil },
                        set: { if !$0 { itemPendingDeletion = nil } }
                    ),
                    presenting: itemPendingDeletion
                ) { item in
                    Button("Delete", role: .destructive) {
                        deleteCard(item)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { item in
                    Text("“\(item.displayName)” and its saved details will be removed.")
                }
            }
            .blur(radius: isAddMenuPresented ? 8 : 0)
            .allowsHitTesting(!isAddMenuPresented)
            .accessibilityHidden(isAddMenuPresented)

            if isAddMenuPresented {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissAddMenu)
                    .transition(.opacity)
                    .zIndex(1)

                RelayTypePickerMenu(onSelect: selectRelayType)
                    .frame(maxWidth: .infinity)
                    .frame(height: 430)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(Tokens.fastBounceAnimation, value: isAddMenuPresented)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                .padding(.bottom, 4)

            Text("Nothing saved yet")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))

            Text("Add a credit card, passport, address or custom item with the button up top.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Edit

    private var isEditingItem: Binding<Bool> {
        Binding(
            get: { itemBeingEdited != nil },
            set: { if !$0 { itemBeingEdited = nil } }
        )
    }

    private func startRelay() {
        withAnimation(Tokens.islandMorphClose) {
            isRelayItemOptionMenuOpen = false
        }
    }

    private func openCurrentCardEditor() {
        guard let item = store.currentRelayItem else { return }
        cardAdvanceTask?.cancel()
        withAnimation(Tokens.islandMorphClose) {
            isRelayItemOptionMenuOpen = false
        }
        cardAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            itemBeingEdited = item
        }
    }

    private func openRelayItemOptionMenu(from location: CGPoint) {
        pulseDots(at: location)
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                withAnimation(isRelayItemOptionMenuOpen ? Tokens.islandMorphClose : Tokens.islandMorphOpen) {
                    isRelayItemOptionMenuOpen.toggle()
                }
            }
        }
      
    }

    // MARK: - Delete

    private func confirmDeleteCurrentCard() {
        guard let item = store.currentRelayItem else { return }
        cardAdvanceTask?.cancel()
        withAnimation(Tokens.islandMorphClose) {
            isRelayItemOptionMenuOpen = false
        }
        itemPendingDeletion = item
    }

    private func confirmDeleteCurrentCard(from location: CGPoint) {
        pulseDots(at: location)
        confirmDeleteCurrentCard()
    }

    private func deleteCard(_ item: RelayItem) {
        do {
            try store.delete(item)
            itemPendingDeletion = nil
        } catch {
            itemPendingDeletion = nil
        }
    }

    // MARK: - Grid swipe

    private func handleGridSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width
        let dy = value.translation.height
        guard abs(dx) > abs(dy), abs(dx) > 50 else { return }

        guard store.items.count > 1 else {
            shakeCard(toward: dx)
            return
        }

        rippleOrigin = rippleOrigin(for: value)
        rippleTrigger += 1
        playSoftDotHaptic()

        cardAdvanceTask?.cancel()
        cardAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(RippleModifier.defaultDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) {
                if dx > 0 {
                    store.selectNextRelayItem()
                } else {
                    store.selectPreviousRelayItem()
                }
            }
        }
    }

    private func selectRelayType(_ type: RelayType) {
        selectedRelayTypeAfterMenuDismissal = type
        dismissAddMenu()
    }

    private func dismissAddMenu() {
        withAnimation(Tokens.fastBounceAnimation, completionCriteria: .logicallyComplete) {
            isAddMenuPresented = false
        } completion: {
            pushSelectedRelayType()
        }
    }

    private func pushSelectedRelayType() {
        guard let type = selectedRelayTypeAfterMenuDismissal else { return }
        selectedRelayTypeAfterMenuDismissal = nil
        navigationPath.append(.createRelayItem(type))
    }

    /// Ripple starts from the card corner matching where the swipe began on the grid.
    private func rippleOrigin(for value: DragGesture.Value) -> CGPoint {
        let inset: CGFloat = 12
        let width = max(cardFrameInGlobal.width, EditableCard.compact.width)
        let cardHeight = EditableCard.compact.height
        let startedOnRight = gridFrameInGlobal.width > 0
            ? value.startLocation.x > gridFrameInGlobal.midX
            : value.translation.width < 0
        let startedOnTop = gridFrameInGlobal.height > 0
            ? value.startLocation.y < gridFrameInGlobal.midY
            : true

        return CGPoint(
            x: startedOnRight ? max(inset, width - inset) : inset,
            y: startedOnTop ? inset : max(inset, cardHeight - inset)
        )
    }

    private func shakeCard(toward direction: CGFloat) {
        cardShakeTask?.cancel()
        let kick: CGFloat = direction > 0 ? 14 : -14

        cardShakeTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.05)) {
                cardShakeOffset = kick
            }
            try? await Task.sleep(for: .milliseconds(45))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.06)) {
                cardShakeOffset = -kick * 0.75
            }
            try? await Task.sleep(for: .milliseconds(55))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.06)) {
                cardShakeOffset = kick * 0.4
            }
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                cardShakeOffset = 0
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.45)
    }

    // MARK: - Dot grid

    private static var gridRowCount: Int {
        let rowHeight = dotSize + (dotPadding * 2)
 
        return max(1, Int((gridHeight + gridSpacing) / (rowHeight + gridSpacing)))
    }

    private static func makeDotItems() -> [DotItem] {
        let count = gridRowCount * gridColumnCount
        return (0..<count).map { index in
            DotItem(
                id: UUID(),
                index: index,
                row: index / gridColumnCount,
                column: index % gridColumnCount,
                screenFrame: .zero,
                shouldEnlarge: false
            )
        }
    }

    /// Only dots currently under the finger/tap pad are enlarged — no drawing trail.
    private func updateSpotlight(at location: CGPoint) {
        var newlyEnlarged = false

        withAnimation(.snappy(duration: 0.12)) {
            for index in dotItems.indices {
                let frame = dotItems[index].screenFrame
                let shouldEnlarge: Bool
                if frame == .zero {
                    shouldEnlarge = false
                } else {
                    let distance = hypot(frame.midX - location.x, frame.midY - location.y)
                    shouldEnlarge = distance <= Self.dragInfluenceRadius
                }

                if shouldEnlarge, !dotItems[index].shouldEnlarge {
                    newlyEnlarged = true
                }
                if dotItems[index].shouldEnlarge != shouldEnlarge {
                    dotItems[index].shouldEnlarge = shouldEnlarge
                }
            }
        }

        if newlyEnlarged {
            playSoftDotHaptic()
        }
    }

    /// Brief spotlight for tap / double-tap at the touch point.
    private func pulseDots(at location: CGPoint) {
        pulseClearTask?.cancel()
        updateSpotlight(at: location)
        pulseClearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            clearSpotlight()
        }
    }

    private func playSoftDotHaptic() {
        guard UserDefaults.standard.object(forKey: "wantsHaptics") as? Bool ?? true else { return }

        let now = Date()
        guard now.timeIntervalSince(lastDotHapticTime) > 0.09 else { return }
        lastDotHapticTime = now

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 1)
    }

    private func clearSpotlight() {
        lastDotHapticTime = .distantPast
        withAnimation(.easeOut(duration: 0.2)) {
            for index in dotItems.indices where dotItems[index].shouldEnlarge {
                dotItems[index].shouldEnlarge = false
            }
        }
    }
}

private struct RelayTypePickerMenu: View {
    let onSelect: (RelayType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var menuContainerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
    }

    private var menuShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 28), isUniform: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Create a relay item")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(colorScheme: .light))

                Text("What would you like to save?")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppColors.textMute(colorScheme: .light))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RelayType.allCases) { type in
                    RelayTypePickerTile(type: type) {
                        onSelect(type)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerShape(menuContainerShape)
        .background {
            menuShape
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
    }
}

private struct RelayTypePickerTile: View {
    let type: RelayType
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var tileShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 14), isUniform: true)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
                    .frame(width: 54, height: 54)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.13), radius: 7, x: 0, y: 4)

                Text(type.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .background(Color.black.opacity(0.045), in: tileShape)
            .overlay {
                tileShape.stroke(Color.black.opacity(0.11), lineWidth: 1.5)
            }
            .contentShape(tileShape)
        }
        .buttonStyle(.plain)
        .hapticFeedback(style: .soft)
    }
}

private struct EmptyToolbarDestinationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Dot item

private struct DotItem: Identifiable {
    let id: UUID
    let index: Int
    let row: Int
    let column: Int
  
    var screenFrame: CGRect
    var shouldEnlarge: Bool

    var screenCenter: CGPoint {
        CGPoint(x: screenFrame.midX, y: screenFrame.midY)
    }
}

// MARK: - Saved item

private struct SavedItemCard: View {
    let item: RelayItem
    var portalID: String? = nil
    var portalNamespace: Namespace.ID? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            EditableCard(
                background: item.background,
                content: item.content,
                texture: item.texture,
                finish: item.finish,
                size: EditableCard.compact
            )
            .applyWalletPortal(id: portalID, namespace: portalNamespace)

            Text(item.displayName)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: EditableCard.compact.width)
                .contentTransition(.numericText())
        }
    }
}

private extension View {
    @ViewBuilder
    func applyWalletPortal(id: String?, namespace: Namespace.ID?) -> some View {
        if let id, let namespace {
            portal(id: id, as: .source, in: namespace)
        } else {
            self
        }
    }
}

#Preview {
    let previewItems = [
        RelayItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            type: .creditCard,
            tag: "Everyday Card",
            subtitle: "•••• 4821",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            gradientID: "sapphire",
            texture: .brushed,
            finish: .machined,
            content: CardContent(
                image: .symbol(name: "creditcard.fill"),
                topNote: "RELAY AIR",
                bottomNote: "•••• 4821",
                icon: .symbol(name: "wave.3.right")
            )
        ),
        RelayItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            type: .passport,
            tag: "Travel Passport",
            subtitle: "Nigerian passport",
            createdAt: Date(timeIntervalSince1970: 1_799_913_600),
            gradientID: "oxblood",
            texture: .pinstripe,
            finish: .flat,
            content: CardContent(
                image: .symbol(name: "globe.africa.fill"),
                topNote: "NIGERIA",
                bottomNote: "PASSPORT",
                icon: .symbol(name: "person.text.rectangle")
            )
        ),
        RelayItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            type: .address,
            tag: "Home Address",
            subtitle: "Lagos",
            createdAt: Date(timeIntervalSince1970: 1_799_827_200),
            gradientID: "meadow",
            texture: .topographic,
            finish: .frosted,
            content: CardContent(
                image: .symbol(name: "house.fill"),
                topNote: "HOME",
                bottomNote: "LAGOS",
                icon: .symbol(name: "mappin.and.ellipse")
            )
        ),
    ]

    let _ = prepareDependencies {
        let database = try! appDatabase()
        try! database.write { db in
            for item in previewItems {
                try RelayItem.insert { item }.execute(db)
            }
        }
        $0.defaultDatabase = database
    }

    PortalContainer {
        NavigationStack {
            MainView(hideStatusBar: .constant(false))
                .environment(RelayItemStore())
        }
    }
}
