import SwiftUI
import UIKit

private enum RelayBackgroundColorPalette {
    static let colors: [UIColor] = [
        .systemRed, .systemBlue, .systemGreen, .systemYellow,
        .systemOrange, .systemPurple, .systemTeal, .systemPink,
        .systemIndigo, .cyan, .magenta, .systemMint,
        .systemCyan, .systemBrown,
        UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.5, green: 1.0, blue: 0.0, alpha: 1.0),
        UIColor(red: 1.0, green: 0.5, blue: 0.4, alpha: 1.0),
        UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.5, green: 0.0, blue: 1.0, alpha: 1.0),
        UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
        UIColor(red: 0.3, green: 0.8, blue: 0.7, alpha: 1.0),
        UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0),
        UIColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 1.0),
        UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)
    ]
}

struct BlurredTopBackgroundView: View {
    private static let gradientColors = randomGradientColors()

    var blurRadius: CGFloat = 170

    var body: some View {
        GeometryReader { geometry in
            let glowHeight = max(geometry.size.height * 0.42, 240)

            LinearGradient(
                gradient: Gradient(colors: Self.gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .colorEffect(
                ShaderLibrary.parameterizedNoise(
                    .float(0.4),
                    .float(0.5),
                    .float(0.5)
                )
            )
            .frame(width: geometry.size.width, height: glowHeight)
            .blur(radius: blurRadius)
            .position(x: geometry.size.width / 2, y: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .blendMode(.screen)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private static func randomGradientColors() -> [Color] {
        (0..<2).compactMap { _ in RelayBackgroundColorPalette.colors.randomElement() }
            .map { Color(uiColor: $0) }
    }
}
