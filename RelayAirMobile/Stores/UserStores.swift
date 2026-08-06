//
//  UserStores.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//

import Combine
import SwiftUI

class UserStores: ObservableObject {
    @AppStorage("wantsHaptics") var wantsHaptics: Bool = true
}
