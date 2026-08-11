//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//

import SwiftUI

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var screenType: EntryPage
    @State private var isAddMenuExpanded = false

    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                
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
}

#Preview {
    MainView(screenType: .constant(.main))
}
