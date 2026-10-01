// App-wide design values used across the iOS app.

import SwiftUI

enum AppDesignTokens {
    static let menuSpring = Animation.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.5)
    /// Matches the snappy overshoot of system Menu presentation.
    static let menuJump = Animation.spring(response: 0.34, dampingFraction: 0.58, blendDuration: 0)
    /// Slower hero move for Portal card transitions.
    static let portalCard = Animation.spring(response: 0.72, dampingFraction: 0.86, blendDuration: 0)
    static let popupBackgroundBlurRadius: CGFloat = 8
    static let topPadding: CGFloat = 20
    static let fastBounceAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    static let fastBounceAnimationNoBounce: Animation = .spring(response: 0.1, dampingFraction: 1, blendDuration: 0.05)

    /// App-wide typeface: SF Pro Rounded.
    static let fontDesign: Font.Design = .rounded
}
