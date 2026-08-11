//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  The wallet. A saved item is its card, exactly as the user dressed it, with the tag
//  underneath — the design is the recognition, the tag is the confirmation.
//
//  Nothing here touches the Keychain. Every value a row carries is plain text, which is
//  what lets the whole wallet render without a single Face ID prompt.
//

import SQLiteData
import SwiftUI

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(RelayItemStore.self) private var store
    @Binding var screenType: EntryPage
    @State private var isAddMenuExpanded = false


    private var items: [RelayItem] { store.items }

    var body: some View {
        VStack {
            if items.isEmpty {
                emptyState
            } else {
                carousel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .overlay {
            if isAddMenuExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(Tokens.menuJump) {
                            isAddMenuExpanded = false
                        }
                    }
            }
        }
        .safeAreaBar(edge: .top) {
            HStack(alignment: .top) {
                CircularButton(icon: "gearshape") {
                    print("Button pressed")
                }
                .padding(.trailing,10)

                CircularButton(icon: "document.viewfinder") {
                    print("Button pressed")
                }

                Spacer()

                MorphingGlassMenu(
                    screenType: $screenType,
                    isExpanded: $isAddMenuExpanded
                )
            }
            .padding(.horizontal, 16)
        }

    }

    // MARK: - Cards


    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 18) {
                ForEach(items) { item in
                    SavedItemCard(item: item)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
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
}

// MARK: - Saved item

private struct SavedItemCard: View {
    let item: RelayItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            EditableCard(
                background: item.background,
                content: item.content,
                texture: item.texture,
                finish: item.finish,
                size: EditableCard.standard
            )

     
            Text(item.displayName)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: EditableCard.compact.width)
        }
    }
}

#Preview {
    let _ = prepareDependencies { $0.defaultDatabase = try! appDatabase() }
    MainView(screenType: .constant(.main))
        .environment(RelayItemStore())
}
