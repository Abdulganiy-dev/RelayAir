//
//  CardLeather.swift
//  RelayAirMobile
//
//  Buffalo leather grain, from Worley (cellular) noise.
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

/// Blend and opacity are deliberately not applied here — `CardTextureLayer` owns those
/// for every texture, so leather stays inside the same contract as the rest.
struct LeatherLayer: View {
    var body: some View {
        if let tile = LeatherTile.buffalo {
            tile.resizable(resizingMode: .tile)
        }
    }
}

// MARK: - Tile

/// Built lazily on first use and never mutated, so there is no shared mutable state
/// to isolate.
enum LeatherTile {
    static let buffalo = build()

    private static let size = 384

    /// Cell counts across the tile for the two octaves, and how much the finer one
    /// contributes. Dense on purpose — sparse counts read as reptile skin, not leather.
    private static let coarseCells = 13
    private static let fineCells = 28
    private static let fineWeight = 0.38

    /// Higher sharpens the crevices and flattens the pebble faces.
    private static let contrast = 1.5

    /// How much slope shading to mix over the plain tonal field.
    ///
    /// At 0 the grain is purely tonal — crevices equally dark on every side — and it
    /// reads as a stain rather than a surface. Lighting it makes the pebbles dome.
    /// Past about 0.7 the low-frequency structure drops out and only edge noise is
    /// left, which stops looking like leather and starts looking like stucco.
    private static let lighting = 0.35

    /// Multiplier on the slope before it becomes brightness. Tuned against the cell
    /// densities above; a coarser field would want less.
    private static let lightingGain = 7.0

    private static func build() -> Image? {
        let coarse = worley(cells: coarseCells, seed: 0x1EA7E401)
        let fine = worley(cells: fineCells, seed: 0x1EA7E402)

        // Height first, in its own pass — the lighting step needs to read neighbours,
        // so the whole field has to exist before any of it is shaded.
        var height = [Double](repeating: 0, count: size * size)
        for i in 0..<height.count {
            let combined = coarse[i] * (1 - fineWeight) + fine[i] * fineWeight

            // Curve toward the crevices: leather is mostly pebble face with narrow
            // dark valleys, not a smooth ramp between the two.
            height[i] = pow(min(max(combined, 0), 1), 1.0 / contrast)
        }

        // Light it. The slope along the light axis, wrapped at the edges so the tile
        // stays seamless:
        //
        //     lit = h(down-right) − h(up-left)
        //
        // On the up-left flank of a pebble the surface climbs as you move down-right,
        // so the difference is positive and the flank brightens — which is what a
        // raised dome does under a light at the top-left, matching the rim, the sheen
        // and the engraved marks. Reverse the sign and every pebble becomes a dimple.
        var values = [Double](repeating: 0, count: size * size)
        var rng = SeededGenerator(seed: 0x1EA7E403)

        for y in 0..<size {
            let up = (y - 1 + size) % size
            let down = (y + 1) % size

            for x in 0..<size {
                let left = (x - 1 + size) % size
                let right = (x + 1) % size

                let upLeft = height[up * size + left]
                let downRight = height[down * size + right]
                let lit = 0.5 + (downRight - upLeft) * lightingGain

                var value = height[y * size + x] * (1 - lighting) + lit * lighting

                // Pores.
                value += Double.random(in: -0.045...0.045, using: &rng)
                values[y * size + x] = value
            }
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
