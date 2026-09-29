//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//


import SQLiteData
import SwiftUI

private enum MainNavigationRoute: Hashable {
    case createRelayItem(RelayType)
    case settings
    case scan
}

struct MainView: View {
    @Environment(RelayItemStore.self) private var store
    @Namespace private var navigationTransitionNamespace
    @State private var navigationPath: [MainNavigationRoute] = []
    @State private var isAddMenuPresented = false
    @State private var selectedRelayTypeAfterMenuDismissal: RelayType?

    private static let addTransitionID = "createRelayItem"
    private static let settingsTransitionID = "settingsPage"
    private static let scanTransitionID = "scanPage"

    var body: some View {

            NavigationStack(path: $navigationPath) {
                ScrollView(content: {
                    LazyVStack{
                        ForEach(store.items) { item in
                            SavedItemCard(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity,maxHeight: .infinity)
                })
                .matchedTransitionSource(id: Self.settingsTransitionID, in: navigationTransitionNamespace)
                .matchedTransitionSource(id: Self.addTransitionID, in: navigationTransitionNamespace)
                .matchedTransitionSource(id: Self.scanTransitionID, in: navigationTransitionNamespace)
                .onTapGesture(perform: dismissAddMenu)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        NavigationLink(value: MainNavigationRoute.settings) {
                            Label("Settings", systemImage: "gear")
                        }
                    }

                    ToolbarSpacer(.flexible, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
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
            }
            .blur(radius: isAddMenuPresented ? 8 : 0)
            .allowsHitTesting(!isAddMenuPresented)
            .accessibilityHidden(isAddMenuPresented)
        
        .animation(Tokens.fastBounceAnimation, value: isAddMenuPresented)
        
        .overlay(alignment: .bottom) {
            if isAddMenuPresented {
                VStack{
                    Spacer()
                    
                    RelayTypePickerMenu(onSelect: selectRelayType)
                        .frame(height: 360)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
        
                }
                .frame(maxWidth: .infinity,maxHeight: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                


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

    NavigationStack {
        MainView()
            .environment(RelayItemStore())
    }
}
