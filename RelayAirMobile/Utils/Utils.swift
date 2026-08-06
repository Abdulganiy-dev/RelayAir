//
//  Utils.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//


import Foundation
import UIKit

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
