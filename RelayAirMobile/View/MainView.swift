//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//


import SQLiteData
import SwiftUI
import PortalTransitions

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(RelayItemStore.self) private var store
    @Binding var screenType: EntryPage
    
    @Binding var hideStatusBar: Bool
    @Namespace private var editPortalNamespace
    @State private var isAddMenuExpanded = false
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

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: gridSpacing),
        count: gridColumnCount
    )

    var body: some View {
     NavigationStack{
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gear") {
                        //
                    }
                }
                
                
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        withAnimation(Tokens.fastBounceAnimation) {
                            screenType = .add(.creditCard)
                        }
                    }
                  
                }
                
                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button("Scan", systemImage: "document.viewfinder") {
                        //
                    }
                  
                }
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

            Text("Add a card, passport or address with the button up top.")
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
        MainView(screenType: .constant(.main), hideStatusBar: .constant(false))
            .environment(RelayItemStore())
    }
}
