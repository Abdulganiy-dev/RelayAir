import SwiftUI

extension Font {
    /// SF Pro Rounded system font at a fixed size.
    static func relay(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        .system(size: size, weight: weight, design: AppDesignTokens.fontDesign)
    }
}
