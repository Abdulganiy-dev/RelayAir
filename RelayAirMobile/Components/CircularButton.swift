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
    var iconColor: Color?
    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 48

    init(
        icon: String,
        buttonColor: Color? = nil,
        useButtonColor: Bool = false,
        iconColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.action = action
        self.buttonColor = buttonColor
        self.useButtonColor = useButtonColor
        self.iconColor = iconColor
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle((iconColor ?? AppColors.iconInverted(colorScheme: colorScheme)).gradient)
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
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
