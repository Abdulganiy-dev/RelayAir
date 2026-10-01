// Shared app-level SwiftUI styling and layout helpers.

import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func adaptiveStatusBarHidden(_ hidden: Bool) -> some View {
        if #available(iOS 27, *) {
            statusBarHidden(hidden)
                .toolbarVisibility(hidden ? .hidden : .automatic, for: .statusBar)
        } else {
            statusBarHidden(hidden)
        }
    }

    @ViewBuilder
    func modifier<Content: View>(if condition: Bool, animation: Animation = .default, modify: (Self) -> Content) -> some View {
        Group {
            if condition {
                modify(self)
            } else {
                self
            }
        }
        .animation(animation, value: condition)
    }



    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow {
                placeholder()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: shouldShow)
            }
            self
        }
    }
    
    func applyBlurScrollTransition() -> some View {
        self.modifier(BlurScrollTransitionModifier())
    }
    
    func applyHorizontalScrollTransition() -> some View {
        self.modifier(BlurScrollTransitionModifierHorizontal())
    }

    func customTextStyle(
        _ hierarchy: AppTextHierarchy = .body,
        color: AppTextColor = .primary,
        fontDesign: Font.Design = AppDesignTokens.fontDesign
    ) -> some View {
        modifier(
            CustomTextStyle(
                hierarchy: hierarchy,
                color: color,
                fontDesign: fontDesign
            )
        )
    }

    func relayAppBackground() -> some View {
        background { AppScreenBackground() }
    }

    func relayRowBackground(cornerRadius: CGFloat = 18) -> some View {
        modifier(RelayRowBackground(cornerRadius: cornerRadius))
    }

    func glassyBackgroundWithStroke(cornerRadius: CGFloat = 20, addStroke: Bool = true) -> some View {
        modifier(GlassyBackgroundWithStroke(cornerRadius: cornerRadius, addStroke: addStroke))
    }

    /// White raised surface for form fields sitting on glass / app background.
    func whiteElevatedBackground(cornerRadius: CGFloat = 15) -> some View {
        modifier(WhiteElevatedBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - CustomTextStyle

struct AppTextHierarchy {
    let fontStyle: Font.TextStyle
    let fontWeight: Font.Weight

    static let title = Self(fontStyle: .title3, fontWeight: .bold)
    static let prominent = Self(fontStyle: .title2, fontWeight: .semibold)
    static let sectionHeading = Self(fontStyle: .headline, fontWeight: .semibold)
    static let body = Self(fontStyle: .body, fontWeight: .regular)
    static let bodyMedium = Self(fontStyle: .body, fontWeight: .medium)
    static let action = Self(fontStyle: .body, fontWeight: .semibold)
    static let supporting = Self(fontStyle: .subheadline, fontWeight: .regular)
    static let supportingEmphasis = Self(fontStyle: .subheadline, fontWeight: .semibold)
    static let footnoteAction = Self(fontStyle: .footnote, fontWeight: .semibold)
    static let caption = Self(fontStyle: .caption, fontWeight: .regular)
    static let captionEmphasis = Self(fontStyle: .caption, fontWeight: .semibold)
    static let smallLabel = Self(fontStyle: .caption2, fontWeight: .medium)
}

enum AppTextColor {
    case primary
    case muted
    case disabled
    case inverted
    case custom(Color)

    func resolve(colorScheme: ColorScheme) -> Color {
        switch self {
        case .primary: AppColors.textPrimary(colorScheme: colorScheme)
        case .muted: AppColors.textMute(colorScheme: colorScheme)
        case .disabled: AppColors.textDisabled(colorScheme: colorScheme)
        case .inverted: AppColors.textInverted(colorScheme: colorScheme)
        case .custom(let color): color
        }
    }
}

private struct CustomTextStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let hierarchy: AppTextHierarchy
    let color: AppTextColor
    let fontDesign: Font.Design

    func body(content: Content) -> some View {
        content
            .font(.system(hierarchy.fontStyle, design: fontDesign))
            .fontWeight(hierarchy.fontWeight)
            .foregroundStyle(color.resolve(colorScheme: colorScheme))
    }
}

// MARK: - GlassyBackgroundWithStroke

private struct RelayRowBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .foregroundStyle(.gray.opacity(0.14))
        )
    }
}

private struct GlassyBackgroundWithStroke: ViewModifier {
    var cornerRadius: CGFloat
    var addStroke: Bool
    var strokeColor: Color = .white.opacity(0.2)
    var strokeWidth: CGFloat = 0.5
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .foregroundStyle(colorScheme == .dark ? .gray.opacity(0.1) : .gray.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        addStroke
                            ? (colorScheme == .dark ? Color.gray.opacity(0.1) : Color.black.opacity(0.07))
                            : .clear,
                        lineWidth: strokeWidth
                    )
            )
    }
}

// MARK: - WhiteElevatedBackground

private struct WhiteElevatedBackground: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white)
            )
    }
}


/// Prefer reading screen from view/window context. This is a fallback utility only.
extension UIScreen {
    static var screenWidth: CGFloat {
        // Prefer deriving from an active window scene when available.
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
           let screen = windowScene.screen as UIScreen? {
            return screen.bounds.width
        }

        // Fallbacks
        if #available(iOS 26.0, *) {
            // `main` is deprecated; we avoid using it. If no active scene, best effort using primary trait environment.
            return UIScreen.main.bounds.width // acceptable fallback for legacy; guarded by availability below
        } else {
            return UIScreen.main.bounds.width
        }
    }

    static var screenHeight: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
           let screen = windowScene.screen as UIScreen? {
            return screen.bounds.height
        }

        if #available(iOS 26.0, *) {
            return UIScreen.main.bounds.height
        } else {
            return UIScreen.main.bounds.height
        }
    }
}

// MARK: - SwiftUI helpers for screen size (preferred)
extension View {
    /// Reads the available size from layout. Use inside body to get container/screen size without UIScreen.
    func readSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: _SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(_SizePreferenceKey.self, perform: onChange)
    }
}

private struct _SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
