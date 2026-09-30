//
//  HapticService.swift
//  Expensy
//
//  Created by ABDULGANIY LAWAL on 21/12/2025.
//



import Foundation
import SwiftUI


class HapticService {

    static let shared = HapticService()
    
    private init() {}
    
    func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
  
}


struct HapticFeedbackModifier: ViewModifier {
    @AppStorage("wantsHaptics") private var wantsHaptics = true
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    func body(content: Content) -> some View {
        content
            .modifier(if: wantsHaptics, modify: { content in
                content
                    .simultaneousGesture(TapGesture().onEnded({
                        HapticService.shared.generateFeedback(style: style)
                    }))
            })
    }
}

extension View {
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.modifier(HapticFeedbackModifier(style: style))
    }
}
