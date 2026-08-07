//
//  AppColors.swift
//  Expensy
// 
//  Created by ABDULGANIY LAWAL on 21/12/2025.
//



import SwiftUI


extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        
        // Handle short hex `#RGB` format by expanding it to `RRGGBB`
        if hexSanitized.count == 3 {
            hexSanitized = hexSanitized.map { "\($0)\($0)" }.joined()
        }
        
        // Check for valid length (6 or 8 for RGBA)
        guard hexSanitized.count == 6 || hexSanitized.count == 8 else {
            self.init(red: 0, green: 0, blue: 0) // Default to black for invalid input
            return
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        
        let hasAlpha = hexSanitized.count == 8
        let divisor = 255.0
        
        let r = Double((rgbValue & 0xFF000000) >> 24) / divisor
        let g = Double((rgbValue & 0x00FF0000) >> 16) / divisor
        let b = Double((rgbValue & 0x0000FF00) >> 8) / divisor
        let a = hasAlpha ? Double(rgbValue & 0x000000FF) / divisor : 1.0
        
        self.init(red: hasAlpha ? r : (Double((rgbValue & 0xFF0000) >> 16) / divisor),
                  green: hasAlpha ? g : (Double((rgbValue & 0x00FF00) >> 8) / divisor),
                  blue: hasAlpha ? b : (Double(rgbValue & 0x0000FF) / divisor),
                  opacity: a)
    }
}


struct AppColors {
    struct lightColors {
        static let primaryPrimaryMute = Color(hex: "#ebf2fe")
        static let primaryPrimaryThin = Color(hex: "#c4d9fc")
        static let primaryPrimaryDefault = Color(hex: "#3b82f6")
        static let successSuccessMute = Color(hex: "#e5fbec")
        static let successSuccessThin = Color(hex: "#b2f3c7")
        static let successSuccessDefault = Color(hex: "#00d743")
        static let warningWarningMute = Color(hex: "#fcf3e5")
        static let warningWarningThin = Color(hex: "#f7dbb2")
        static let warningWarningDefault = Color(hex: "#e58600")
        static let errorErrorMute = Color(hex: "#ffebea")
        static let errorErrorThin = Color(hex: "#ffc4c1")
        static let errorErrorDefault = Color(hex: "#ff3b30")
        static let textTextBrand = Color(hex: "#3b82f6")
        static let textTextInverted = Color(hex: "#1e1e1e")
        static let textTextMute = Color(hex: "#818181")
        static let textTextPrimary = Color(hex: "#4f4f4f")
        static let textTextDisabled = Color(hex: "#d9d9d9")
        static let backgroundSurfacePrimaryBG = Color(hex: "#fafafa")
        static let backgroundSurfaceLayer = Color(hex: "#E9E1D9")
        // Apple macOS Folder Colors
        static let folderFront = Color.white
        static let folderBack = Color(hex: "#2F7AA8")
        static let backgroundSurfaceMute = Color(hex: "#f7f7f7")
        static let backgroundSurfaceMild = Color(hex: "#fffafa")
        static let strokeColourStrokeSoft = Color(hex: "#0000000a")
        static let strokeColourStrokeSubtle = Color(hex: "#00000014")
        static let strokeColourStrokeMild = Color(hex: "#0000001e")
        static let strokeColourStrokeWarm = Color(hex: "#00000028")
        static let strokeColourStrokeStrong = Color(hex: "#00000033")
        static let strokeColourStrokePrimary = Color(hex: "#3b82f6")
        static let primaryOncolorBlack = Color(hex: "#000000")
        static let primaryOncolorWhite = Color(hex: "#ffffff")
        static let primaryNeutralWhite = Color(hex: "#ffffff")
        static let primaryNeutralBlack = Color(hex: "#000000")
        static let iconIconPrimary = Color(hex: "#4f4f4f")
        static let iconIconInverted = Color(hex: "#1e1e1e")
        static let iconIconMute = Color(hex: "#818181")
        static let iconIconDisabled = Color(hex: "#d9d9d9")
        static let iconIconBrand = Color(hex: "#3b82f6")
        static let backgroundBackdropSoft = Color(hex: "#3b82f651")
        static let backgroundBackdropMild = Color(hex: "#3b82f6a3")
        static let backgroundBackdropWarm = Color(hex: "#3b82f6cc")
        static let extraExtraDefault = Color(hex: "#9455fd")
        static let extraExtraThin = Color(hex: "#dfccfe")
        static let extraExtraMute = Color(hex: "#f4eeff")
    }
    struct darkColors {
        static let primaryPrimaryMute = Color(hex: "#c4d9fc")
        static let primaryPrimaryThin = Color(hex: "#c4d9fc")
        static let primaryPrimaryDefault = Color(hex: "#3b82f6")
        static let successSuccessMute = Color(hex: "#e5fbec")
        static let successSuccessThin = Color(hex: "#b2f3c7")
        static let successSuccessDefault = Color(hex: "#00d743")
        static let warningWarningMute = Color(hex: "#fcf3e5")
        static let warningWarningThin = Color(hex: "#f7dbb2")
        static let warningWarningDefault = Color(hex: "#e58600")
        static let errorErrorMute = Color(hex: "#ffebea")
        static let errorErrorThin = Color(hex: "#ffc4c1")
        static let errorErrorDefault = Color(hex: "#ff3b30")
        static let textTextBrand = Color(hex: "#3b82f6")
        static let textTextInverted = Color(hex: "#e8e8e8")
        static let textTextMute = Color(hex: "#818181")
        static let textTextPrimary = Color(hex: "#BCBCBC")
        static let textTextDisabled = Color(hex: "#3b3b3b")
        static let backgroundSurfacePrimaryBG = Color(hex: "#0a0a0a")
        static let backgroundSurfaceLayer = Color(hex: "#1A1A1A")
        // Apple macOS Folder Colors (darker, low-glare slate for dark mode)
        static let folderFront = Color(hex: "#1F2A37") // front panel
        static let folderBack = Color(hex: "#111827")  // back panel
        static let backgroundSurfaceMute = Color(hex: "#282828")
        static let backgroundSurfaceMild = Color(hex: "#3b3b3b")
        static let strokeColourStrokeSoft = Color(hex: "#ffffff0a")
        static let strokeColourStrokeSubtle = Color(hex: "#ffffff14")
        static let strokeColourStrokeMild = Color(hex: "#ffffff1e")
        static let strokeColourStrokeWarm = Color(hex: "#ffffff28")
        static let strokeColourStrokeStrong = Color(hex: "#ffffff33")
        static let strokeColourStrokePrimary = Color(hex: "#3b82f6")
        static let primaryOncolorBlack = Color(hex: "#ffffff")
        static let primaryOncolorWhite = Color(hex: "#000000")
        static let primaryNeutralWhite = Color(hex: "#ffffff")
        static let primaryNeutralBlack = Color(hex: "#000000")
        static let iconIconPrimary = Color(hex: "#bcbcbc")
        static let iconIconInverted = Color(hex: "#e8e8e8")
        static let iconIconMute = Color(hex: "#818181")
        static let iconIconDisabled = Color(hex: "#3b3b3b")
        static let iconIconBrand = Color(hex: "#3b82f6")
        static let backgroundBackdropSoft = Color(hex: "#3b82f651")
        static let backgroundBackdropMild = Color(hex: "#3b82f6a3")
        static let backgroundBackdropWarm = Color(hex: "#3b82f6cc")
        static let extraExtraDefault = Color(hex: "#9455fd")
        static let extraExtraThin = Color(hex: "#dfccfe")
        static let extraExtraMute = Color(hex: "#f4eeff")
    }
    static var primaryColor = "#3B82F6"
    
    static func errorMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.errorErrorMute : lightColors.errorErrorMute
    }
    
    static func onBardingBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundSurfacePrimaryBG : lightColors.backgroundSurfacePrimaryBG
    }
    
    static func background(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : lightColors.backgroundSurfaceMild
    }
    
    static func backgroundSurfaceMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundSurfaceMute : lightColors.backgroundSurfaceMute
    }
    
    static func backgroundSurfaceLayer(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundSurfaceLayer: lightColors.backgroundSurfaceLayer
    }
    
    // Apple macOS Folder Colors
    static func folderFront(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.folderFront : lightColors.folderFront
    }
    
    static func folderBack(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.folderBack : .white
    }
    
    static func strokeSoft(colorScheme:ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokeSoft : lightColors.strokeColourStrokeSoft
    }
    
    
    
    
    static func errorDefault(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.errorErrorDefault : lightColors.errorErrorDefault
    }
    
    static func primaryMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryPrimaryMute : lightColors.primaryPrimaryMute
    }
    
    static func sheetBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#e8e8e8") : .white
    }
    
    static func primaryDefault(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryPrimaryDefault : lightColors.primaryPrimaryDefault
    }
    
    static func textInverted(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.textTextInverted : lightColors.textTextInverted
    }
    
    static func textMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.textTextMute : lightColors.textTextMute
    }
    
    
    static func textDisabled(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.textTextDisabled : lightColors.textTextDisabled
    }
    
    static func textPrimary(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.textTextPrimary : lightColors.textTextPrimary
    }
    
    static func strokeColor(colorScheme:ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokeSoft : lightColors.strokeColourStrokeSoft
    }
    
    static func warningDefault(colorScheme:ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.warningWarningDefault: lightColors.warningWarningDefault
    }
    
    static func warningMute(colorScheme:ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.warningWarningMute: lightColors.warningWarningMute
    }
    
    static func warningThin(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.warningWarningThin : lightColors.warningWarningThin
    }
    
    static func successMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.successSuccessMute : lightColors.successSuccessMute
    }
    
    static func successThin(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.successSuccessThin : lightColors.successSuccessThin
    }
    
    static func successDefault(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.successSuccessDefault : lightColors.successSuccessDefault
    }
    
    static func errorThin(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.errorErrorThin : lightColors.errorErrorThin
    }
    
    static func primaryThin(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryPrimaryThin : lightColors.primaryPrimaryThin
    }
    
    static func backgroundSurfacePrimary(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundSurfacePrimaryBG : lightColors.backgroundSurfacePrimaryBG
    }
    
    static func backgroundSurfaceMild(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundSurfaceMild : lightColors.backgroundSurfaceMild
    }
    
    static func strokeSubtle(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokeSubtle : lightColors.strokeColourStrokeSubtle
    }
    
    static func strokeMild(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokeMild : lightColors.strokeColourStrokeMild
    }
    
    static func strokeWarm(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokeWarm : lightColors.strokeColourStrokeWarm
    }
    
    static func strokeStrong(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokeStrong : lightColors.strokeColourStrokeStrong
    }
    
    static func strokePrimary(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.strokeColourStrokePrimary : lightColors.strokeColourStrokePrimary
    }
    
    static func onPrimaryBlack(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryOncolorBlack : lightColors.primaryOncolorBlack
    }
    
    static func onPrimaryWhite(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryOncolorWhite : lightColors.primaryOncolorWhite
    }
    
    static func neutralWhite(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryNeutralWhite : lightColors.primaryNeutralWhite
    }
    
    static func neutralBlack(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.primaryNeutralBlack : lightColors.primaryNeutralBlack
    }
    
    static func iconPrimary(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.iconIconPrimary : lightColors.iconIconPrimary
    }
    
    static func iconInverted(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.iconIconInverted : lightColors.iconIconInverted
    }
    
    static func iconMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.iconIconMute : lightColors.iconIconMute
    }
    
    static func iconDisabled(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.iconIconDisabled : lightColors.iconIconDisabled
    }
    
    static func iconBrand(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.iconIconBrand : lightColors.iconIconBrand
    }
    
    static func textBrand(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.textTextBrand : lightColors.textTextBrand
    }
    
    static func backgroundBackdropSoft(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundBackdropSoft : lightColors.backgroundBackdropSoft
    }
    
    static func backgroundBackdropMild(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundBackdropMild : lightColors.backgroundBackdropMild
    }
    
    static func backgroundBackdropWarm(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.backgroundBackdropWarm : lightColors.backgroundBackdropWarm
    }
    
    static func extraDefault(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.extraExtraDefault : lightColors.extraExtraDefault
    }
    
    static func extraThin(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.extraExtraThin : lightColors.extraExtraThin
    }
    
    static func extraMute(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColors.extraExtraMute : lightColors.extraExtraMute
    }
}
