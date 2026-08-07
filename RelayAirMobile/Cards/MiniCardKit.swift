//
//  MiniCardKit.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  Shared design system for the Relay Air mini cards — the 200×200 tiles that each
//  stand for one kind of saved personal information.
//
//  Rules of the family:
//    · One 200×200 canvas, 28pt continuous radius, 24pt padding, 1pt hairline border.
//    · Exactly one simplified real-world object per card, centred, straight-on.
//    · Every object has roughly the same optical mass (~11–13k px²) so the set is even.
//    · Each object is a deep material lit from the top-left: a three-stop body
//      gradient, an edge-lit rim, and one faint specular pass. Same light on all
//      three, only the temperature changes — graphite, navy, espresso.
//    · One gilt thread runs through every card, spent once each: the chip, the
//      emblem, the seal. That single warm note is what makes the set read as a
//      matched collection rather than three tiles.
//    · Straight-on. No tilt, no glass, no textures.
//

import SwiftUI

// MARK: - Tokens

enum MiniCard {

    // Canvas
    static let size: CGFloat = 200
    static let cornerRadius: CGFloat = 28
    static let padding: CGFloat = 24
    static let contentSize: CGFloat = size - padding * 2   // 152

    // Objects
    static let objectRadius: CGFloat = 10
    static let objectPadding: CGFloat = 12

    static let creditSize   = CGSize(width: 144, height: 91)    // ISO 1.586 : 1
    static let passportSize = CGSize(width: 90,  height: 126)   // ICAO booklet 0.704 : 1
    static let envelopeSize = CGSize(width: 140, height: 92)

    /// Tile fill. Barely a gradient — just enough for the surface to feel lit from
    /// above, so the object never looks pasted onto flat paper. Carries a whisper of
    /// the object's own hue.
    static func canvas(_ scheme: ColorScheme, tint: Color) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(hex: "#1D1D20"), Color(hex: "#141416")]
                : [Color(hex: "#FFFFFF"), Color(hex: "#F7F7F9")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func canvasTintOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.10 : 0.025
    }

    static func canvasBorder(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(hex: "#34343A"), Color(hex: "#232327")]
                : [Color(hex: "#EBEBEF"), Color(hex: "#DCDCE3")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Gilt

/// The one warm note in the system. Four stops so the highlight rolls across the
/// form the way real foil does, instead of reading as a flat tan wash.
enum Gilt {
    static let gradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "#F9EDCB"), location: 0.00),
            .init(color: Color(hex: "#E3C88A"), location: 0.38),
            .init(color: Color(hex: "#BE9A55"), location: 0.72),
            .init(color: Color(hex: "#EBD6A6"), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Engraved lines — chip contacts and the like.
    static let etch = Color(hex: "#8A6C30").opacity(0.55)

    /// Edge of a gilt part: catching light at the top, dropping into its own colour.
    static let rim = LinearGradient(
        colors: [.white.opacity(0.55), Color(hex: "#8A6C30").opacity(0.40)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Materials

/// How one object is made: body, edge and light. Every card picks one.
struct MiniMaterial {
    let body: [Color]
    let rimHigh: Double
    let rimLow: Double
    let sheenHigh: Double
    let sheenLow: Double

    let primaryInk: Color
    let secondaryInk: Color
    let tertiaryInk: Color
    let markInk: Color

    let shadow: Double
    let tint: Color

    var fill: LinearGradient {
        LinearGradient(colors: body, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Edge lighting: bright where the light lands, almost gone on the far side.
    var rim: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(rimHigh), .white.opacity(rimLow)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A single specular pass across the form. Deliberately weak — the moment it
    /// becomes a visible band it stops looking like a material and starts looking
    /// like a graphic.
    var sheen: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(sheenHigh), location: 0.00),
                .init(color: .white.opacity(0),         location: 0.42),
                .init(color: .white.opacity(0),         location: 0.62),
                .init(color: .white.opacity(sheenLow),  location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension MiniMaterial {

    /// Cool, near-neutral. Titanium read.
    static let graphite = MiniMaterial(
        body: [Color(hex: "#4E535E"), Color(hex: "#2C3038"), Color(hex: "#181B21")],
        rimHigh: 0.26, rimLow: 0.05,
        sheenHigh: 0.10, sheenLow: 0.045,
        primaryInk: .white.opacity(0.93),
        secondaryInk: .white.opacity(0.58),
        tertiaryInk: .white.opacity(0.42),
        markInk: .white.opacity(0.30),
        shadow: 0.20,
        tint: Color(hex: "#2C3038")
    )

    /// Deep blue, the way a real cover is dyed.
    static let navy = MiniMaterial(
        body: [Color(hex: "#2C3E64"), Color(hex: "#18233D"), Color(hex: "#0C1322")],
        rimHigh: 0.22, rimLow: 0.04,
        sheenHigh: 0.09, sheenLow: 0.04,
        primaryInk: .white.opacity(0.92),
        secondaryInk: .white.opacity(0.56),
        tertiaryInk: .white.opacity(0.40),
        markInk: .white.opacity(0.28),
        shadow: 0.22,
        tint: Color(hex: "#18233D")
    )

    /// The warm counterpoint to graphite and navy. Deep oxblood, not brown —
    /// anything closer to neutral turns olive against the gilt.
    static let oxblood = MiniMaterial(
        body: [Color(hex: "#71404A"), Color(hex: "#46232C"), Color(hex: "#2A1319")],
        rimHigh: 0.24, rimLow: 0.05,
        sheenHigh: 0.10, sheenLow: 0.04,
        primaryInk: .white.opacity(0.93),
        secondaryInk: .white.opacity(0.58),
        tertiaryInk: .white.opacity(0.44),
        markInk: .white.opacity(0.30),
        shadow: 0.21,
        tint: Color(hex: "#46232C")
    )
}

// MARK: - Typography scale

enum MiniType {
    static let eyebrow = Font.system(size: 7.5, weight: .semibold)
    static let title   = Font.system(size: 8.5, weight: .bold)
    static let data    = Font.system(size: 9,   weight: .semibold)
    static let dataSub = Font.system(size: 8,   weight: .medium)
    static let digits  = Font.system(size: 9.5, weight: .semibold)
}

private struct MiniLabel<S: ShapeStyle>: ViewModifier {
    let font: Font
    let tracking: CGFloat
    let style: S

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(tracking)
            .foregroundStyle(style)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func miniLabel<S: ShapeStyle>(_ font: Font, tracking: CGFloat, style: S) -> some View {
        modifier(MiniLabel(font: font, tracking: tracking, style: style))
    }
}

// MARK: - Card shell

/// The 200×200 tile every card is built on. Identical in all three.
struct MiniCardShell<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    let material: MiniMaterial
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: MiniCard.cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .frame(width: MiniCard.contentSize, height: MiniCard.contentSize)
            .padding(MiniCard.padding)
            .background {
                ZStack {
                    MiniCard.canvas(scheme, tint: material.tint)
                    material.tint.opacity(MiniCard.canvasTintOpacity(scheme))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(MiniCard.canvasBorder(scheme), lineWidth: 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 3)
    }
}

/// Gives an object the shared material treatment: body gradient, one specular
/// pass, an edge-lit rim, and a two-part shadow — a tight contact shadow plus a
/// wider ambient one, which is what actually makes it look lifted off the tile.
struct MiniObjectSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let material: MiniMaterial

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(material.fill)
                    shape.fill(material.sheen)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(material.rim, lineWidth: 1))
            .shadow(color: .black.opacity(material.shadow), radius: 9, x: 0, y: 4)
            .shadow(color: .black.opacity(material.shadow * 0.55), radius: 2.5, x: 0, y: 1)
    }
}

extension View {
    func miniObjectSurface<S: InsettableShape>(_ shape: S, material: MiniMaterial) -> some View {
        modifier(MiniObjectSurface(shape: shape, material: material))
    }
}

// MARK: - Glyphs

/// EMV contact chip, milled from the gilt.
struct EMVChip: View {
    var width: CGFloat = 22
    var height: CGFloat = 16

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 3.5, style: .continuous) }

    var body: some View {
        shape
            .fill(Gilt.gradient)
            .overlay(
                ChipContacts()
                    .stroke(Gilt.etch, lineWidth: 0.75)
                    .padding(2)
            )
            .overlay(shape.strokeBorder(Gilt.rim, lineWidth: 0.6))
            .frame(width: width, height: height)
    }
}

/// Contacts sit in rows, the way they do on a real chip: two rules across,
/// one down the middle.
private struct ChipContacts: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [0.32, 0.68] {
            let y = rect.minY + rect.height * fraction
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// Payment network mark: two overlapping discs. Deliberately unbranded — the
/// overlap does the work, so no logo is needed.
struct NetworkDiscs: View {
    let material: MiniMaterial
    var diameter: CGFloat = 14
    var overlap: CGFloat = 5

    var body: some View {
        HStack(spacing: -overlap) {
            disc
            disc
        }
    }

    private var disc: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.30), .white.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: diameter, height: diameter)
    }
}

/// Globe emblem for the passport cover, struck in foil. No country, no flag.
struct GlobeEmblem: View {
    var diameter: CGFloat = 30

    var body: some View {
        ZStack {
            GlobeGrid()
                .stroke(Gilt.gradient.opacity(0.72), lineWidth: 0.9)
                .clipShape(Circle().inset(by: 1.4))
            Circle()
                .strokeBorder(Gilt.gradient, lineWidth: 1.1)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct GlobeGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        // Equator and two latitudes, chord-clipped to the sphere.
        for dy in [0, -radius * 0.52, radius * 0.52] {
            let half = (radius * radius - dy * dy).squareRoot()
            path.move(to: CGPoint(x: centre.x - half, y: centre.y + dy))
            path.addLine(to: CGPoint(x: centre.x + half, y: centre.y + dy))
        }

        // Central meridian seen edge-on, plus one turned meridian.
        path.move(to: CGPoint(x: centre.x, y: rect.minY))
        path.addLine(to: CGPoint(x: centre.x, y: rect.maxY))
        path.addEllipse(in: CGRect(x: centre.x - radius * 0.5,
                                   y: rect.minY,
                                   width: radius,
                                   height: rect.height))
        return path
    }
}

/// ICAO e-passport symbol, foil-stamped: chip plate with contactless arcs.
struct BiometricSymbol: View {
    var width: CGFloat = 15
    var height: CGFloat = 10

    private var plate: RoundedRectangle { RoundedRectangle(cornerRadius: 2, style: .continuous) }

    var body: some View {
        plate
            .strokeBorder(Gilt.gradient.opacity(0.75), lineWidth: 0.8)
            .overlay(
                ContactlessWaves()
                    .stroke(Gilt.gradient,
                            style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            )
            .frame(width: width, height: height)
    }
}

private struct ContactlessWaves: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Origin sits right of centre so the dot plus both arcs read as one
        // centred group inside the plate.
        let origin = CGPoint(x: rect.minX + rect.width * 0.37, y: rect.midY)
        path.addEllipse(in: CGRect(x: origin.x - 1.2, y: origin.y - 1.2, width: 2.4, height: 2.4))
        for radius in [rect.width * 0.21, rect.width * 0.32] {
            path.addArc(center: origin,
                        radius: radius,
                        startAngle: .degrees(-48),
                        endAngle: .degrees(48),
                        clockwise: false)
        }
        return path
    }
}

/// Location seal: a house struck into a disc of gilt, like wax.
struct LocationSeal: View {
    let material: MiniMaterial
    var diameter: CGFloat = 19

    var body: some View {
        Circle()
            .fill(Gilt.gradient)
            .overlay(Circle().strokeBorder(Gilt.rim, lineWidth: 0.6))
            .overlay(
                HouseMark()
                    .stroke(material.body[2].opacity(0.75),
                            style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                    .frame(width: diameter * 0.5, height: diameter * 0.44)
            )
            .frame(width: diameter, height: diameter)
    }
}

private struct HouseMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let eave = rect.minY + rect.height * 0.46

        path.move(to: CGPoint(x: rect.minX, y: eave))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: eave))

        let inset = rect.width * 0.16
        path.move(to: CGPoint(x: rect.minX + inset, y: eave))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: eave))
        return path
    }
}

/// Masked card number: four dots, then the last four digits.
struct MaskedDigits: View {
    let material: MiniMaterial
    let last4: String

    var body: some View {
        HStack(spacing: 2.1) {
            HStack(spacing: 2.1) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(.white.opacity(0.42))
                        .frame(width: 2.6, height: 2.6)
                }
            }
            .padding(.trailing, 1.9)

            Text(last4)
                .monospacedDigit()
                .miniLabel(MiniType.digits, tracking: 1.1, style: material.primaryInk)
        }
    }
}
