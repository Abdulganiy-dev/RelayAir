//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//


import PortalTransitions
import SQLiteData
import SwiftUI

struct MainView: View {
    @Environment(RelayItemStore.self) private var store
    @State private var navigation = RelayNavigationStore()
    @State private var selectedSavedItem: RelayItem?
    @State private var isAddMenuPresented = false
    @State private var selectedRelayTypeAfterMenuDismissal: RelayType?
    @State private var searchText = ""
    @State private var isSearchPresented = false

    private var isPopupPresented: Bool {
        isAddMenuPresented || selectedSavedItem != nil
    }


    private var searchResults: [RelayItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            [item.displayName, item.tag, item.subtitle, item.type.title]
                .contains { $0.localizedStandardContains(query) }
        }
    }

    var body: some View {
        
        NavigationStack(path: $navigation.path) {
            SavedItemRevealCarousel(items: searchResults, onSelect: presentSavedItem)
                .overlay {
                    if searchResults.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .blur(radius: isPopupPresented ? AppDesignTokens.popupBackgroundBlurRadius : 0)
            
            
            .safeAreaBar(edge: .top) {
                if !isAddMenuPresented && selectedSavedItem == nil {
                    HStack {
                        CircularButton(icon: "gear") {
                            navigation.push(.settings)
                        }
                        .accessibilityLabel("Settings")

                        Spacer()

                        CircularButton(icon: "plus", action: presentAddMenu)
                            .accessibilityLabel("Add item")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .safeAreaBar(edge: .bottom) {
                if !isPopupPresented {
                    ExpandingSearchBar(
                        text: $searchText,
                        isPresented: $isSearchPresented,
                        prompt: "Search items"
                    ) {
                        CircularButton(icon: "document.viewfinder") {
                            navigation.push(.scan)
                        }
                        .accessibilityLabel("Scan")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .relayAppBackground()
            .navigationDestination(for: RelayNavigationRoute.self) { route in
                ZStack {
                    switch route {
                    case .createRelayItem(let type):
                        CreateRelayItemView(type: type)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .relayAppBackground()
                    case .editRelayItem(let item):
                        EditRelayItemView(item: item)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .relayAppBackground()
                    case .settings:
                        SettingsView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .relayAppBackground()
                    case .scan:
                        ScannerView()

                    }
                }

                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { gesture in
                            guard gesture.startLocation.x <= 40,
                                  gesture.translation.width > 80,
                                  gesture.translation.width > abs(gesture.translation.height) else { return }
                            navigation.pop()
                        }
                )
            }
            .allowsHitTesting(!isAddMenuPresented && selectedSavedItem == nil)
            .accessibilityHidden(isAddMenuPresented || selectedSavedItem != nil)
            
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    if isAddMenuPresented {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture(perform: dismissAddMenu)

                        RelayTypePickerMenu(
                            onSelect: selectRelayType,
                            onClose: dismissAddMenu
                        )
                        .padding(.horizontal)
                        .transition(RelayPopupMenu.presentationTransition)
                    }
                    
                    if let item = selectedSavedItem {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture(perform: dismissSavedItemOptions)

                        SavedItemOptionsMenu(
                            item: item,
                            onSelect: { option in selectSavedItemOption(option, for: item) },
                            onClose: dismissSavedItemOptions
                        )
                        .padding(.horizontal)
                        .transition(RelayPopupMenu.presentationTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(isAddMenuPresented || selectedSavedItem != nil)
            }
        }
        .environment(navigation)
    }
        
        private func presentSavedItem(_ item: RelayItem) {
            guard selectedSavedItem == nil, !isAddMenuPresented else { return }
            
            withAnimation(RelayPopupMenu.presentationAnimation) {
                selectedSavedItem = item
            }
        }

        private func selectSavedItemOption(_ option: SavedItemOption, for item: RelayItem) {
            switch option {
            case .edit:
                withAnimation(
                    RelayPopupMenu.presentationAnimation,
                    completionCriteria: .logicallyComplete
                ) {
                    selectedSavedItem = nil
                } completion: {
                    navigation.push(.editRelayItem(item))
                }
            case .delete, .relay:
                dismissSavedItemOptions()
            }
        }
        
        private func dismissSavedItemOptions() {
            withAnimation(RelayPopupMenu.presentationAnimation) {
                selectedSavedItem = nil
            }
        }
        
        private func presentAddMenu() {
            guard !isAddMenuPresented, selectedSavedItem == nil else { return }
            
            withAnimation(RelayPopupMenu.presentationAnimation) {
                isAddMenuPresented = true
            }
        }
        
        private func selectRelayType(_ type: RelayType) {
            selectedRelayTypeAfterMenuDismissal = type
            dismissAddMenu()
        }
        
        private func dismissAddMenu() {
            withAnimation(RelayPopupMenu.presentationAnimation, completionCriteria: .logicallyComplete) {
                isAddMenuPresented = false
            } completion: {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(90))
                    pushSelectedRelayType()
                }
            }
        }
        
        private func pushSelectedRelayType() {
            guard let type = selectedRelayTypeAfterMenuDismissal else { return }
            selectedRelayTypeAfterMenuDismissal = nil
            navigation.push(.createRelayItem(type))
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
        EntryView()
            .environment(RelayItemStore())
    }
}
