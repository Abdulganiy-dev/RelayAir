import SwiftUI

struct BouncyButton: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .scaleEffect(x: configuration.isPressed ? 0.75 : 1.0, y: configuration.isPressed ? 0.75: 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 1), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.5 : 1)
        
            
            
    }
}

struct BouncyButtonSecondStyle: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .scaleEffect(x: configuration.isPressed ? 0.9 : 1.0, y: configuration.isPressed ? 0.9: 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 1), value: configuration.isPressed)
            .opacity(1)
        
            
            
    }
}

struct ThreeDButtonStyle: ButtonStyle {
    let color:String
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.3))
                        .offset(y: configuration.isPressed ? 0 : 6)
                    
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: color))
                    
                }
                
            )
            .offset(y: configuration.isPressed ? 6 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
    
    
    
}
