//
//  AddressMini.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Card 3 — a saved address, drawn as a mailing envelope rather than a map.
//  Heavy dark stationery: the flap is a lit crease over a faint wash, so it reads
//  as an envelope without a heavy triangle taking over the tile. The seal carries
//  a house, not a GPS pin.
//

import SwiftUI

struct AddressMini: View {
    var label: String = "HOME"
    var street: String = "2140 MARKET ST"
    var locality: String = "SAN FRANCISCO, CA"

    private let material = MiniMaterial.oxblood

    /// Fraction of the envelope height taken by the closed flap. Kept shallow so the
    /// seam stays a detail rather than becoming the subject.
    private let flapDepth: CGFloat = 0.29

    var body: some View {
        MiniCardShell(material: material) {
            envelope
                .frame(width: MiniCard.envelopeSize.width, height: MiniCard.envelopeSize.height)
                .miniObjectSurface(
                    RoundedRectangle(cornerRadius: MiniCard.objectRadius, style: .continuous),
                    material: material
                )
        }
    }

    private var envelope: some View {
        ZStack(alignment: .topLeading) {
            flap
            details
        }
    }

    /// The flap is one extra thickness of paper: very slightly brighter than the
    /// body, with a lit edge where it folds. The dark line sitting 1pt under the
    /// lit one is what turns a drawn V into an actual fold.
    private var flap: some View {
        ZStack {
            EnvelopeFlap(depth: flapDepth)
                .fill(.white.opacity(0.06))
            EnvelopeSeam(depth: flapDepth)
                .stroke(.black.opacity(0.16), lineWidth: 1)
                .offset(y: 1)
            EnvelopeSeam(depth: flapDepth)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .miniLabel(MiniType.eyebrow, tracking: 1.4, style: material.tertiaryInk)
                    Text(street)
                        .miniLabel(MiniType.data, tracking: 0.5, style: material.primaryInk)
                    Text(locality)
                        .miniLabel(MiniType.dataSub, tracking: 0.3, style: material.secondaryInk)
                }

                Spacer(minLength: 4)

                LocationSeal(material: material)
            }
        }
        .padding(.horizontal, MiniCard.objectPadding)
        // Sits the block optically centred in the body left free by the flap
        // rather than resting on the bottom edge.
        .padding(.bottom, 16)
    }
}

// MARK: - Envelope geometry

private struct EnvelopeFlap: Shape {
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * depth))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct EnvelopeSeam: Shape {
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * depth))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview("Address") {
    AddressMini()
        .padding(40)
}
