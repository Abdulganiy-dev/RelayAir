//
//  ModalSurface.swift
//  RelayAirMobile
//
//  Floating card chrome for in-place overlays — soft fill, hairline stroke, shadow.
//

import SwiftUI

private struct ModalSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? .black.opacity(0.86) : .white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.5), lineWidth: 1)
            )
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
    }
}

extension View {
    func modalSurface(cornerRadius: CGFloat = 32) -> some View {
        modifier(ModalSurfaceModifier(cornerRadius: cornerRadius))
    }
}
