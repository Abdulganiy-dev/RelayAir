//
//  Utils.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//


import Foundation
import SwiftUI
import UIKit

enum Tokens {
    static let menuSpring = Animation.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.5)
    /// Matches the snappy overshoot of system Menu presentation.
    static let menuJump = Animation.spring(response: 0.34, dampingFraction: 0.58, blendDuration: 0)
    /// Dynamic Island expand/collapse — no overshoot.
    static let islandMorph = Animation.easeInOut(duration: 0.36)
    /// Slower hero move for Portal card transitions.
    static let portalCard = Animation.spring(response: 0.72, dampingFraction: 0.86, blendDuration: 0)
    static let backgroundBlur: CGFloat = 250
    static let topPadding: CGFloat = 20
    static let fastBounceAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    static let fastBounceAnimationNoBounce: Animation = .spring(response: 0.1, dampingFraction: 1, blendDuration: 0.05)

    /// App-wide typeface: SF Pro Rounded.
    static let fontDesign: Font.Design = .rounded
}

nonisolated func debugLog(_ messages: Any...) {

    for message in messages {
        if let error = message as? Error {
            print("❌ Type Error: \(error.localizedDescription)")
        } else if let data = message as? Data {
            print("📄 Data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
        } else if let dict = message as? [String: Any] {
            print(prettyPrintJSON(dict) ?? "\(dict)")
        } else if let arrayOfDicts = message as? [[String: Any]] {
            print(prettyPrintJSON(arrayOfDicts) ?? "\(arrayOfDicts)")
        } else if let anyArray = message as? [Any] {
            print("📦 Array:")
            for (index, item) in anyArray.enumerated() {
                print("   - [\(index)] \(item)")
            }
        } else {
            print("\(message)")
        }
    }

}


nonisolated private func prettyPrintJSON(_ value: Any) -> String? {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted),
          let prettyString = String(data: data, encoding: .utf8) else {
        return nil
    }
    return prettyString
}


extension UIDevice {
    static var isIOS26OrAbove: Bool {
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
    }
}
