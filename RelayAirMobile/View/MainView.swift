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

    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) {
            HStack {
                CircularButton(icon: "gearshape") {
                    print("Button pressed")
                }

                Spacer()

                Menu {
                    ForEach(RelayType.allCases) { type in
                        Button {
                            withAnimation(Tokens.fastBounceAnimation) {
                                screenType = .add(type)
                            }
                        } label: {
                            Label(type.title, systemImage: type.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .frame(width: 44, height: 44)
                        .glassEffect(.clear, in: Circle())
                }
                .buttonStyle(BouncyButton())
                .hapticFeedback(style: .soft)
            }
            .padding(.horizontal, 16)
        }
        .safeAreaBar(edge: .bottom) {
            HStack {
                Spacer()
                CircularButton(icon: "document.viewfinder") {
                    print("Button pressed")
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    MainView(screenType: .constant(.main))
}
