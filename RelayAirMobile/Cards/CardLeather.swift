//
//  CardLeather.swift
//  RelayAirMobile
//
//  The three leather grains, from Worley (cellular) noise.
//
//  Worley gives you F1 and F2 — the distances to the nearest and second-nearest
//  feature point. F2 − F1 falls to zero exactly on the boundary between two cells and
//  rises toward the middle of each, which is structurally the crevice-and-pebble
//  arrangement of grained hide rather than an approximation of it. Two octaves,
//  because real leather has coarse pebbles with finer grain inside them rather than
//  one uniform cell size, plus low-amplitude pores — which is most of the difference
//  between leather and moulded plastic.
//
//  This is the reason the card system still ships zero image assets. A photographic
//  grain map would have been the obvious route and would have cost a few hundred KB,
//  a licence to check, and a tile to level to mid-grey by hand.
//

import SwiftUI
import CoreGraphics

enum LeatherGrain {
    case fine
    case pebbled
    case coarse

    /// Cell counts across the tile for the two octaves, and how much the finer one
    /// contributes.
    ///
    /// These are dense on purpose. The first pass used a third of these counts and
    /// the pebbles came out around 25pt across — reptile skin, not leather. Real grain
    /// is a couple of millimetres, which at card scale is 2–4pt.
    var octaves: (coarse: Int, fine: Int, fineWeight: Double) {
        switch self {
        case .fine:    (26, 54, 0.42)
        case .pebbled: (19, 40, 0.40)
        case .coarse:  (13, 28, 0.38)
        }
    }

    /// Higher sharpens the crevices and flattens the pebble faces.
    var contrast: Double {
        switch self {
        case .fine:    2.1
        case .pebbled: 1.8
        case .coarse:  1.5
        }
    }

    var tile: Image? {
        switch self {
        case .fine:    LeatherTile.fine
        case .pebbled: LeatherTile.pebbled
        case .coarse:  LeatherTile.coarse
        }
    }
}

/// Blend and opacity are deliberately not applied here — `CardTextureLayer` owns those
/// for every texture, so leather stays inside the same contract as the rest.
struct LeatherLayer: View {
    let grain: LeatherGrain

    var body: some View {
        if let tile = grain.tile {
            tile.resizable(resizingMode: .tile)
        }
    }
}

// MARK: - Tile

/// Three `static let`s rather than a keyed cache: each is built lazily on first use
/// and never mutated, so there is no shared mutable state to isolate.
enum LeatherTile {
    static let fine = build(.fine)
    static let pebbled = build(.pebbled)
    static let coarse = build(.coarse)

    private static let size = 384

    private static func build(_ grain: LeatherGrain) -> Image? {
        let (coarseCells, fineCells, fineWeight) = grain.octaves

        let coarse = worley(cells: coarseCells, seed: 0x1EA7E401)
        let fine = worley(cells: fineCells, seed: 0x1EA7E402)

        var values = [Double](repeating: 0, count: size * size)
        var rng = SeededGenerator(seed: 0x1EA7E403)

        for i in 0..<values.count {
            let combined = coarse[i] * (1 - fineWeight) + fine[i] * fineWeight

            // Curve toward the crevices: leather is mostly pebble face with narrow
            // dark valleys, not a smooth ramp between the two.
            var value = pow(min(max(combined, 0), 1), 1.0 / grain.contrast)

            // Pores.
            value += Double.random(in: -0.045...0.045, using: &rng)
            values[i] = value
        }

        // Centre the mean on mid-grey. `.overlay` treats 0.5 as neutral, so a tile
        // averaging anything else lightens or darkens the whole card instead of only
        // adding grain — the single thing most likely to go wrong here.
        let mean = values.reduce(0, +) / Double(values.count)
        let shift = 0.5 - mean

        var pixels = [UInt8](repeating: 0, count: size * size)
        for i in 0..<values.count {
            pixels[i] = UInt8(min(max(values[i] + shift, 0), 1) * 255)
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                  width: size,
                  height: size,
                  bitsPerComponent: 8,
                  bitsPerPixel: 8,
                  bytesPerRow: size,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else { return nil }

        // scale 4, so the 384px tile covers 96pt of card.
        return Image(decorative: cgImage, scale: 4)
    }

    /// F2 − F1, with the feature grid wrapped so the tile repeats seamlessly. Without
    /// the wrap the seams show as straight lines across the card, and no amount of
    /// grain hides them.
    private static func worley(cells: Int, seed: UInt64) -> [Double] {
        var rng = SeededGenerator(seed: seed)

        let cellSize = Double(size) / Double(cells)
        var points = [(x: Double, y: Double)]()
        points.reserveCapacity(cells * cells)

        for row in 0..<cells {
            for column in 0..<cells {
                points.append((
                    x: (Double(column) + Double.random(in: 0.12...0.88, using: &rng)) * cellSize,
                    y: (Double(row) + Double.random(in: 0.12...0.88, using: &rng)) * cellSize
                ))
            }
        }

        var field = [Double](repeating: 0, count: size * size)
        let span = Double(size)

        for y in 0..<size {
            let py = Double(y)
            let cellY = Int(py / cellSize)

            for x in 0..<size {
                let px = Double(x)
                let cellX = Int(px / cellSize)

                var nearest = Double.greatestFiniteMagnitude
                var second = Double.greatestFiniteMagnitude

                for dy in -1...1 {
                    for dx in -1...1 {
                        let wrappedY = ((cellY + dy) % cells + cells) % cells
                        let wrappedX = ((cellX + dx) % cells + cells) % cells
                        let point = points[wrappedY * cells + wrappedX]

                        // Shift the neighbour back into this tile's space when the
                        // lookup wrapped around an edge.
                        let offsetX = Double((cellX + dx) - wrappedX) / Double(cells) * span
                        let offsetY = Double((cellY + dy) - wrappedY) / Double(cells) * span

                        let deltaX = point.x + offsetX - px
                        let deltaY = point.y + offsetY - py
                        let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()

                        if distance < nearest {
                            second = nearest
                            nearest = distance
                        } else if distance < second {
                            second = distance
                        }
                    }
                }

                field[y * size + x] = min((second - nearest) / cellSize, 1)
            }
        }

        return field
    }
}
