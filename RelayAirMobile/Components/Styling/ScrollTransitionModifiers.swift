import SwiftUI

struct BlurScrollTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive.threshold(.visible(0.8)),
                              axis: .vertical) { view, phase in
                view

                    .blur(radius: phase.isIdentity ? 0 : 5)
                    .scaleEffect(phase.isIdentity ? 1 : 0.5)

            }
    }
}


struct BlurScrollTransitionModifierHorizontal: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition(.animated(.bouncy(duration: 0.4, extraBounce: 0.2)),axis: .horizontal) { view, phase in
                view
                    .blur(radius: phase.isIdentity ? 0 : 5)
                    .scaleEffect(phase.isIdentity ? 1 : 0.8)

            }
    }
}
