import UIKit

extension UIDevice {
    static var isIOS26OrAbove: Bool {
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
    }
}
