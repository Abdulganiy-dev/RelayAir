//
//  CircularButton.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//

import SwiftUI

struct CircularButton: View {
    var icon: String
    var action: () -> Void
    @State private var onAppear: Bool = false
    var buttonColor: Color?
    var useButtonColor: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 44

    init(icon: String, buttonColor: Color? = nil, useButtonColor: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
        self.buttonColor = buttonColor
        self.useButtonColor = useButtonColor
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(BouncyButton())
        .glassEffect(.clear.interactive(), in: .circle)
        .frame(width: size, height: size)
        .hapticFeedback(style: .soft)
        .scaleEffect(onAppear ? 1 : 0.1)
        .opacity(onAppear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                onAppear = true
            }
        }
    }
}

#Preview {
    CircularButton(icon: "xmark", action: {
        //
    })
}
