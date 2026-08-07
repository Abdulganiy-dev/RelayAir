//
//  PassportMini.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Card 2 — a closed passport booklet in navy, straight on. The bound spine on the
//  left is what separates it from a plain rectangle; the emblem sits high, the
//  biometric plate anchors the foot, exactly as on a real cover. Everything struck
//  on the cover is foil. No country, no flag.
//

import SwiftUI

struct PassportMini: View {
    private let spineWidth: CGFloat = 5
    private let material = MiniMaterial.navy

    /// Square-ish at the bound edge, softly rounded at the fore edge.
    private var cover: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 3,
            bottomLeadingRadius: 3,
            bottomTrailingRadius: MiniCard.objectRadius,
            topTrailingRadius: MiniCard.objectRadius,
            style: .continuous
        )
    }

    var body: some View {
        MiniCardShell(material: material) {
            booklet
                .frame(width: MiniCard.passportSize.width, height: MiniCard.passportSize.height)
                .miniObjectSurface(cover, material: material)
        }
    }

    private var booklet: some View {
        ZStack(alignment: .leading) {
            spine
            face
        }
    }

    /// The bound edge sits in its own shadow, with a single lit crease where the
    /// cover folds over.
    private var spine: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(.black.opacity(0.22))
                .frame(width: spineWidth)
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 1)
            Spacer(minLength: 0)
        }
    }

    private var face: some View {
        VStack(spacing: 0) {
            GlobeEmblem()

            Spacer().frame(height: 13)

            Text("PASSPORT")
                .miniLabel(MiniType.title, tracking: 1.5, style: Gilt.gradient)

            Spacer(minLength: 0)

            BiometricSymbol()
        }
        .padding(.leading, spineWidth + 1 + MiniCard.objectPadding)
        .padding(.trailing, MiniCard.objectPadding)
        .padding(.top, 21)
        .padding(.bottom, 13)
    }
}

#Preview("Passport") {
    PassportMini()
        .padding(40)
}
