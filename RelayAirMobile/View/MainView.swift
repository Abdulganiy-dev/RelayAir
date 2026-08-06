//
//  MainView.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//

import SwiftUI

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        NavigationStack {
            VStack{
                ScrollView(.horizontal) {
                    
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
           
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        print("Button pressed")
                    }) {
                        Image(systemName: "gearshape")
                        
                            .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                            .buttonStyle(BouncyButton())
                    }
                    .hapticFeedback(style: .soft)
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button(action: {
                        print("Button pressed")
                    }) {
                        Image(systemName: "document.viewfinder")
                            .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                            .buttonStyle(BouncyButton())
                    }
                    .hapticFeedback(style: .soft)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Button pressed")
                    }) {
                        Image(systemName: "plus")
                          
       
                            .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                            .buttonStyle(BouncyButton())
                    }
                    .hapticFeedback(style: .soft)
                }
            }
        }
    }
}

#Preview {
    MainView()
}
