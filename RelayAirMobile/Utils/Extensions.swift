//
//  Extensions.swift
//  Expensy
//
//  Created by ABDULGANIY LAWAL on 21/12/2025.
//

import SwiftUI
import UIKit

extension View {
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
        color: Color,
        fontStyle: Font.TextStyle = .body,
        fontDesign: Font.Design = Tokens.fontDesign,
        fontWeight: Font.Weight = .semibold
    ) -> some View {
        modifier(
            CustomTextStyle(
                color: color,
                fontDesign: fontDesign,
                fontStyle: fontStyle,
                fontWeight: fontWeight
            )
        )
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

private struct CustomTextStyle: ViewModifier {
    var color: Color
    var fontDesign: Font.Design
    var fontStyle: Font.TextStyle
    var fontWeight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.system(fontStyle, design: fontDesign))
            .foregroundStyle(color)
            .fontWeight(fontWeight)
    }
}

// MARK: - GlassyBackgroundWithStroke

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


extension JSONDecoder {
    /// Decodes with detailed error logging for all `DecodingError` cases.
    /// Throws user-friendly messages while logging technical details.
    func decodeLoggingErrors<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decode(type, from: data)
        } catch let decodingError as DecodingError {
            switch decodingError {
            case let .dataCorrupted(context):
                debugLog("Decoding error - Data corrupted: \(context)")
            case let .keyNotFound(key, context):
                debugLog("Decoding error - Key '\(key)' not found: \(context.debugDescription)")
                debugLog("codingPath: \(context.codingPath)")
            case let .valueNotFound(_, context):
                debugLog("Decoding error - Value not found: \(context.debugDescription)")
                debugLog("codingPath: \(context.codingPath)")
            case let .typeMismatch(type, context):
                debugLog("Decoding error - Type '\(type)' mismatch: \(context.debugDescription)")
                debugLog("codingPath: \(context.codingPath)")
            @unknown default:
                debugLog("Decoding error - Unknown case: \(decodingError)")
            }
            throw NSError(
                domain: "DecodingError",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode data. Please try again."]
            )
        } catch {
            debugLog("Decoding error: \(error)")
            throw NSError(
                domain: "DecodingError",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Failed to process data. Please try again."]
            )
        }
    }
}

extension Font {
    /// SF Pro Rounded system font at a fixed size.
    static func relay(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        .system(size: size, weight: weight, design: Tokens.fontDesign)
    }
}

