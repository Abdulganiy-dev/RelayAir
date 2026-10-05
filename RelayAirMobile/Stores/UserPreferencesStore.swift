//
//  UserPreferencesStore.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//

import Combine
import SwiftUI

class UserPreferencesStore: ObservableObject {
    @AppStorage("wantsHaptics") var wantsHaptics: Bool = true

    /// How many times the "Scan for one form" tip has been shown. It is a reminder
    /// for new users, so it stops after a few scans rather than nagging forever.
    @AppStorage("scanTipPresentationCount") var scanTipPresentationCount: Int = 0

    static let scanTipMaxPresentations = 3

    var shouldShowScanTip: Bool {
        scanTipPresentationCount < Self.scanTipMaxPresentations
    }

    /// Counts a showing as soon as the tip appears, whether or not it is acted on.
    func recordScanTipPresentation() {
        scanTipPresentationCount += 1
    }
}
