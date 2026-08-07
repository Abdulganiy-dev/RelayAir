//
//  CardTexture.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 07/08/2026.
//
//  Procedural card textures. Nothing here is an asset: each one is drawn from maths,
//  so it holds at 358×225, at 300×200, and at every interpolated size in between
//  during the portal flight.
//
//  All of them composite with `.overlay` blend at low opacity, which modulates the
//  light and dark of whatever is underneath instead of painting grey over it. That is
//  what lets one texture sit on Champagne and on Midnight and read correctly on both.
//
//  `EditableCard` draws this at a fixed size and scales the result. The `Canvas`
//  passes below are expensive enough — guilloché is tens of thousands of segments —
//  that re-running them against a live size would cost a redraw every frame the card
//  animates. Scaling a rendered layer is just a transform.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum CardTexture: String, CaseIterable, Identifiable {
    case grain
    // Guilloché and topographic sit together: they are the two that draw a
    // *composition* across the card. The other four are uniform fields.
    case guilloche
    case topographic
    case brushed
    case carbon
    case pinstripe

    var id: String { rawValue }

    var name: String {
        switch self {
        case .grain:       "Grain"
        case .guilloche:   "Guilloché"
        case .topographic: "Topographic"
        case .brushed:     "Brushed"
        case .carbon:      "Carbon"
        case .pinstripe:   "Pinstripe"
        }
    }

    /// Tuned per texture — a dense pattern needs far less presence than a sparse one
    /// to read at the same strength.
    var strength: Double {
        switch self {
        case .grain:       0.55
        case .guilloche:   0.30
        case .topographic: 0.34
        case .brushed:     0.40
        case .carbon:      0.22
        case .pinstripe:   0.22
        }
    }
}

// MARK: - Renderer

struct CardTextureLayer: View {
    let texture: CardTexture

    var body: some View {
        Group {
            switch texture {
            case .grain:       GrainLayer()
            case .guilloche:   GuillocheLayer()
            case .topographic: TopographicLayer()
            case .brushed:     BrushedLayer()
            case .carbon:      CarbonLayer()
            case .pinstripe:   PinstripeLayer()
            }
        }
        .blendMode(.overlay)
        .opacity(texture.strength)
        .allowsHitTesting(false)
    }
}

// MARK: - Grain

/// Real per-pixel noise from Core Image, generated once as a tile and repeated.
/// Drawing thousands of dots in a `Canvas` would work but costs a redraw every frame
/// the card animates; a tiled bitmap costs nothing.
private struct GrainLayer: View {
    var body: some View {
        if let tile = Self.tile {
            tile.resizable(resizingMode: .tile)
        }
    }

    static let tile: Image? = {
        let filter = CIFilter.randomGenerator()
        guard let noise = filter.outputImage else { return nil }

        let extent = CGRect(x: 0, y: 0, width: 300, height: 300)
        let desaturated = noise
            .cropped(to: extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.2,
            ])

        guard let cg = CIContext().createCGImage(desaturated, from: extent) else { return nil }
        // scale 3, so the tile covers 100pt and one noise pixel is a third of a point.
        // At scale 1 each pixel is a whole point, which reads as chunky speckle rather
        // than grain.
        return Image(decorative: cg, scale: 3)
    }()
}

// MARK: - Guilloché

/// The engine-turned rosette used on banknotes and metal cards. A hypotrochoid with a
/// non-integer R/r so the curve precesses instead of closing, which is what produces
/// the woven look rather than a single loop.
private struct GuillocheLayer: View {
    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let base = min(size.width, size.height)

            for (index, spec) in Self.rings.enumerated() {
                var path = Path()
                let outer = base * spec.scale
                let inner = outer / spec.ratio
                let pen = inner * spec.pen

                var theta = 0.0
                let step = 0.012
                let turns = Double(spec.turns) * 2 * .pi
                var started = false

                while theta <= turns {
                    let k = (outer - inner) / inner
                    let x = centre.x + (outer - inner) * cos(theta) + pen * cos(k * theta)
                    let y = centre.y + (outer - inner) * sin(theta) - pen * sin(k * theta)
                    let point = CGPoint(x: x, y: y)

                    if started {
                        path.addLine(to: point)
                    } else {
                        path.move(to: point)
                        started = true
                    }
                    theta += step
                }

                context.stroke(
                    path,
                    with: .color(.white.opacity(index == 0 ? 0.85 : 0.55)),
                    lineWidth: 0.5
                )
            }
        }
    }

    private struct Ring {
        let scale: Double
        let ratio: Double
        let pen: Double
        let turns: Int
    }

    private static let rings: [Ring] = [
        Ring(scale: 0.46, ratio: 6.7,  pen: 1.7, turns: 24),
        Ring(scale: 0.62, ratio: 9.3,  pen: 1.4, turns: 30),
        Ring(scale: 0.30, ratio: 4.9,  pen: 2.1, turns: 18),
    ]
}

// MARK: - Topographic

/// Iso-lines traced through a value-noise field with marching squares.
///
/// The only texture here with somewhere to look: the contours pool and spread
/// differently across the card instead of covering it evenly, which is what separates
/// it from the four uniform fields.
private struct TopographicLayer: View {
    /// Coarse enough that contours read as broad sweeps rather than scribble.
    private let field = NoiseField(seed: 0x51D0C0DE, columns: 6, rows: 4, detailColumns: 13, detailRows: 9)

    private let levels: [Double] = [0.30, 0.38, 0.46, 0.54, 0.62, 0.70, 0.78]

    /// Marching-squares cell size. Smaller is smoother and costs more; by 3pt the
    /// stepping is already past what the eye resolves.
    private let step: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            let columns = Int(size.width / step)
            let rows = Int(size.height / step)
            guard columns > 1, rows > 1 else { return }

            // Sampled once and reused for every level. The field does not change
            // between them, and resampling per level is the easy way to make this
            // seven times slower than it needs to be.
            var samples = [Double](repeating: 0, count: (columns + 1) * (rows + 1))
            for row in 0...rows {
                for column in 0...columns {
                    let x = Double(column) * Double(step) / Double(size.width)
                    let y = Double(row) * Double(step) / Double(size.height)
                    samples[row * (columns + 1) + column] = field.value(x: x, y: y)
                }
            }

            for (index, level) in levels.enumerated() {
                var path = Path()

                for row in 0..<rows {
                    for column in 0..<columns {
                        let topLeft     = samples[row * (columns + 1) + column]
                        let topRight    = samples[row * (columns + 1) + column + 1]
                        let bottomRight = samples[(row + 1) * (columns + 1) + column + 1]
                        let bottomLeft  = samples[(row + 1) * (columns + 1) + column]

                        var code = 0
                        if topLeft > level     { code |= 8 }
                        if topRight > level    { code |= 4 }
                        if bottomRight > level { code |= 2 }
                        if bottomLeft > level  { code |= 1 }

                        guard code != 0, code != 15 else { continue }

                        let originX = CGFloat(column) * step
                        let originY = CGFloat(row) * step

                        // Interpolated crossing per edge, so a contour lands between
                        // samples rather than snapping to the grid.
                        func crossing(_ a: Double, _ b: Double) -> CGFloat {
                            let span = b - a
                            guard abs(span) > .ulpOfOne else { return 0.5 }
                            return CGFloat(min(max((level - a) / span, 0), 1))
                        }

                        let points = [
                            CGPoint(x: originX + crossing(topLeft, topRight) * step, y: originY),
                            CGPoint(x: originX + step, y: originY + crossing(topRight, bottomRight) * step),
                            CGPoint(x: originX + crossing(bottomLeft, bottomRight) * step, y: originY + step),
                            CGPoint(x: originX, y: originY + crossing(topLeft, bottomLeft) * step),
                        ]

                        for (from, to) in Self.segments(for: code) {
                            path.move(to: points[from])
                            path.addLine(to: points[to])
                        }
                    }
                }

                // Alternating weight, so the set reads as elevation bands rather than
                // as one flat mesh of identical lines.
                let isMajor = index.isMultiple(of: 2)
                context.stroke(
                    path,
                    with: .color(.white.opacity(isMajor ? 0.95 : 0.5)),
                    lineWidth: isMajor ? 0.9 : 0.6
                )
            }
        }
    }

    /// Edge indices: 0 top, 1 right, 2 bottom, 3 left. Cases 5 and 10 are the ambiguous
    /// saddles — either resolution is valid and the choice is invisible at this scale.
    private static func segments(for code: Int) -> [(Int, Int)] {
        switch code {
        case 1, 14: [(3, 2)]
        case 2, 13: [(2, 1)]
        case 3, 12: [(3, 1)]
        case 4, 11: [(0, 1)]
        case 5:     [(0, 3), (2, 1)]
        case 6, 9:  [(0, 2)]
        case 7, 8:  [(0, 3)]
        case 10:    [(0, 1), (3, 2)]
        default:    []
        }
    }
}

/// Two octaves of value noise — a coarse grid for the overall shape, a finer one at
/// roughly a quarter amplitude for the wobble. Smoothstepped between control points;
/// linear interpolation gives straight-edged polygons instead of contours.
private struct NoiseField {
    private let coarse: [Double]
    private let detail: [Double]
    private let columns: Int
    private let rows: Int
    private let detailColumns: Int
    private let detailRows: Int

    init(seed: UInt64, columns: Int, rows: Int, detailColumns: Int, detailRows: Int) {
        self.columns = columns
        self.rows = rows
        self.detailColumns = detailColumns
        self.detailRows = detailRows

        var rng = SeededGenerator(seed: seed)
        coarse = (0..<((columns + 1) * (rows + 1))).map { _ in Double.random(in: 0...1, using: &rng) }
        detail = (0..<((detailColumns + 1) * (detailRows + 1))).map { _ in Double.random(in: 0...1, using: &rng) }
    }

    func value(x: Double, y: Double) -> Double {
        let base = sample(coarse, columns: columns, rows: rows, x: x, y: y)
        let fine = sample(detail, columns: detailColumns, rows: detailRows, x: x, y: y)
        return base * 0.74 + fine * 0.26
    }

    private func sample(_ grid: [Double], columns: Int, rows: Int, x: Double, y: Double) -> Double {
        let gridX = min(max(x, 0), 0.9999) * Double(columns)
        let gridY = min(max(y, 0), 0.9999) * Double(rows)

        let x0 = Int(gridX), y0 = Int(gridY)
        let x1 = min(x0 + 1, columns), y1 = min(y0 + 1, rows)

        let tx = smoothstep(gridX - Double(x0))
        let ty = smoothstep(gridY - Double(y0))

        let topLeft     = grid[y0 * (columns + 1) + x0]
        let topRight    = grid[y0 * (columns + 1) + x1]
        let bottomLeft  = grid[y1 * (columns + 1) + x0]
        let bottomRight = grid[y1 * (columns + 1) + x1]

        let top = topLeft + (topRight - topLeft) * tx
        let bottom = bottomLeft + (bottomRight - bottomLeft) * tx
        return top + (bottom - top) * ty
    }

    private func smoothstep(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

// MARK: - Brushed metal

/// Horizontal hairlines at jittered opacity. Deterministically seeded so the card does
/// not shimmer when the view redraws.
private struct BrushedLayer: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: 0x8BADF00D)
            var y = 0.0

            // Full width and tightly spaced. Jittering the ends — which the first
            // attempt did — reads as scan-lines, not as metal: a brush stroke runs the
            // whole length of the panel, only its weight varies.
            while y < size.height {
                let bright = Bool.random(using: &rng)
                let alpha = Double.random(in: 0.05...0.5, using: &rng)
                let thickness = Double.random(in: 0.35...0.85, using: &rng)

                let line = Path(CGRect(x: 0, y: y, width: size.width, height: thickness))
                context.fill(line, with: .color(bright ? .white.opacity(alpha) : .black.opacity(alpha * 0.8)))

                y += Double.random(in: 0.6...1.5, using: &rng)
            }
        }
    }
}

// MARK: - Carbon

/// Twill weave: square cells whose hatching alternates direction, the way real carbon
/// fibre reads at a distance.
private struct CarbonLayer: View {
    var body: some View {
        Canvas { context, size in
            let cell = 9.0
            var row = 0

            var y = 0.0
            while y < size.height {
                var column = 0
                var x = 0.0
                while x < size.width {
                    let leaning = (row + column).isMultiple(of: 2)
                    var path = Path()
                    var offset = -cell

                    while offset < cell * 2 {
                        if leaning {
                            path.move(to: CGPoint(x: x + offset, y: y))
                            path.addLine(to: CGPoint(x: x + offset + cell, y: y + cell))
                        } else {
                            path.move(to: CGPoint(x: x + offset + cell, y: y))
                            path.addLine(to: CGPoint(x: x + offset, y: y + cell))
                        }
                        offset += 2.4
                    }

                    // GraphicsContext is a value type, so a copy scopes the clip to
                    // this cell without needing to undo it.
                    var cellContext = context
                    cellContext.clip(to: Path(CGRect(x: x, y: y, width: cell, height: cell)))
                    cellContext.stroke(path, with: .color(.white.opacity(leaning ? 0.9 : 0.45)), lineWidth: 0.8)

                    x += cell
                    column += 1
                }
                y += cell
                row += 1
            }
        }
    }
}

// MARK: - Pinstripe

/// Fine diagonal hairlines. The quietest of the set — closest to a paper stock than
/// to a pattern.
private struct PinstripeLayer: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing = 5.0
            var x = -size.height

            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += spacing
            }

            context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 0.6)
        }
    }
}

// MARK: - Deterministic randomness

/// splitmix64. Seeded from a constant so a texture is identical every redraw — an
/// unseeded generator would make the card crawl while it animates.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
