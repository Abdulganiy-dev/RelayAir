//
//  CreditCardMini.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Card 1 — a premium bank card in graphite, reduced to four marks: chip, network,
//  name, last four. The whole middle band is deliberately empty; the whitespace is
//  what lets the material show.
//

import SwiftUI

struct CreditCardMini: View {
    var holder: String = "ALEX MORGAN"
    var last4: String = "4429"

    private let material = MiniMaterial.graphite

    var body: some View {
        MiniCardShell(material: material) {
            card
                .frame(width: MiniCard.creditSize.width, height: MiniCard.creditSize.height)
                .miniObjectSurface(
                    RoundedRectangle(cornerRadius: MiniCard.objectRadius, style: .continuous),
                    material: material
                )
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Centre-aligned, not top-aligned: the discs are shorter than the chip,
            // so matching their optical centres is what actually looks level.
            HStack(alignment: .center, spacing: 0) {
                EMVChip()
                Spacer(minLength: 8)
                NetworkDiscs(material: material)
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(holder)
                    .miniLabel(MiniType.data, tracking: 0.6, style: material.primaryInk)
                Spacer(minLength: 6)
                MaskedDigits(material: material, last4: last4)
            }
        }
        .padding(MiniCard.objectPadding)
    }
}

#Preview("Credit card") {
    CreditCardMini()
        .padding(40)
}
