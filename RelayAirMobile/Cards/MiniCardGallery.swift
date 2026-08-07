//
//  MiniCardGallery.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  The family seen together. Use this to check the set stays even whenever a
//  card is added or changed — the three objects should carry the same weight
//  and no single tile should draw the eye first.
//

import SwiftUI

struct MiniCardGallery: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 20) {
            CreditCardMini()
            PassportMini()
            AddressMini()
        }
        .padding(28)
        // Plain white behind the set, so the tile's own 1pt border is what
        // defines each card — the way a Wallet or Passwords grid reads.
        .background(scheme == .dark ? Color(hex: "#000000") : Color(hex: "#FFFFFF"))
    }
}

#Preview("Family — light") {
    MiniCardGallery()
        .environment(\.colorScheme, .light)
}

#Preview("Family — dark") {
    MiniCardGallery()
        .environment(\.colorScheme, .dark)
}
