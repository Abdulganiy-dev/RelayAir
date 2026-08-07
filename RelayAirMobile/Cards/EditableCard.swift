//
//  EditableCard.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  The card itself — 358 × 225, blank for now. Content comes later; this is the
//  surface the user dresses.
//
//  The card is deliberately more than a filled rectangle: one specular pass, an
//  edge-lit rim and a drop shadow. That treatment is what makes even a flat
//  colour read as a physical object rather than a swatch.
//

import SwiftUI

struct EditableCard: View {
    let background: CardGradient

    var content = CardContent()

    /// Surface texture, composited over the background. Separate from `content`
    /// because it dresses the whole card rather than occupying a slot on it.
    var texture: CardTexture?

    var size: CGSize? = EditableCard.standard
    var cornerRadius: CGFloat = 20


    static let standard = CGSize(width: 358, height: 225)


    static let compact = CGSize(width: 300, height: 200)

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(background.style)
            .overlay(shape.fill(Self.sheen))
            .overlay(textureLayer)
            .overlay(contentLayer)
            .overlay(shape.strokeBorder(Self.rim, lineWidth: 1))
            .frame(width: size?.width, height: size?.height)
            // The texture blends with the layers beneath it, so the card needs its own
            // compositing context — without this the blend would reach through onto
            // whatever the card is sitting on.
            .compositingGroup()
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
            .animation(.smooth(duration: 0.35), value: background)
            .animation(.smooth(duration: 0.25), value: content)
            .animation(.smooth(duration: 0.3), value: texture)
    }

    /// Drawn at `standard` and scaled, for the same reason as `contentLayer` — but
    /// here it is about cost rather than layout. Re-running a `Canvas` against the
    /// live size would redraw tens of thousands of segments every frame of the portal
    /// transition; scaling an already-rendered layer is just a transform.
    @ViewBuilder
    private var textureLayer: some View {
        if let texture {
            GeometryReader { proxy in
                let scale = max(
                    proxy.size.width / Self.standard.width,
                    proxy.size.height / Self.standard.height
                )

                CardTextureLayer(texture: texture)
                    .frame(width: Self.standard.width, height: Self.standard.height)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipShape(shape)
        }
    }

    /// Content is laid out once at `standard` and scaled to whatever the card is
    /// actually drawn at. That is what keeps it proportional at the compact size and,
    /// more importantly, through every interpolated frame of the portal transition —
    /// laying out against the live size would reflow the text mid-flight.
    ///
    /// Scale takes the smaller of the two ratios so content is never distorted when
    /// `compact` does not share `standard`'s aspect.
    @ViewBuilder
    private var contentLayer: some View {
        if !content.isEmpty {
            GeometryReader { proxy in
                let scale = min(
                    proxy.size.width / Self.standard.width,
                    proxy.size.height / Self.standard.height
                )

                CardContentLayer(content: content, background: background)
                    .frame(width: Self.standard.width, height: Self.standard.height)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }

    /// A single specular pass. Weak on purpose — the moment it reads as a visible
    /// band it stops looking like a material and starts looking like a graphic.
    private static let sheen = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.10), location: 0.00),
            .init(color: .white.opacity(0),    location: 0.42),
            .init(color: .white.opacity(0),    location: 0.64),
            .init(color: .black.opacity(0.06), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Bright where the light lands, nearly gone on the far side.
    private static let rim = LinearGradient(
        colors: [.white.opacity(0.28), .white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Content

/// The four corner slots, laid out at `EditableCard.standard`. Nothing in here reads
/// the live card size — the caller scales the whole thing.
private struct CardContentLayer: View {
    let content: CardContent
    let background: CardGradient

    private let inset: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                mark(content.image, alignment: .topLeading)
                Spacer(minLength: 14)
                note(content.topNote,
                     alignment: .trailing,
                     font: .system(size: 12, weight: .semibold, design: .rounded),
                     tracking: 0.6,
                     colour: background.secondaryInk,
                     maxWidth: 148)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 14) {
                note(content.bottomNote,
                     alignment: .leading,
                     font: .system(size: 15, weight: .semibold, design: .rounded),
                     tracking: 0.2,
                     colour: background.ink,
                     maxWidth: 212)
                Spacer(minLength: 14)
                mark(content.icon, alignment: .bottomTrailing)
            }
        }
        .padding(inset)
    }

    /// Both slots render through here, so a symbol and an imported photo are bounded
    /// identically. This is the one place the size ceiling is applied.
    @ViewBuilder
    private func mark(_ mark: CardMark?, alignment: Alignment) -> some View {
        switch mark {
        case .symbol(let name, let tint):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .foregroundStyle(tint.color)
                .frame(maxWidth: CardMark.maxSize, maxHeight: CardMark.maxSize, alignment: alignment)

        case .imported(let data):
            if let image = CardArtwork.image(data) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: CardMark.maxSize, maxHeight: CardMark.maxSize, alignment: alignment)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func note(
        _ text: String,
        alignment: TextAlignment,
        font: Font,
        tracking: CGFloat,
        colour: Color,
        maxWidth: CGFloat
    ) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Text(trimmed)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(colour)
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .frame(
                    maxWidth: maxWidth,
                    alignment: alignment == .trailing ? .trailing : .leading
                )
                .fixedSize(horizontal: false, vertical: true)
                // Text only, not the whole layer. A gradient running light to dark
                // puts the two write-ups at opposite ends of it, so one of them is
                // always fighting the ink — but the same shadow behind a filled
                // glyph reads as a glow rather than as legibility.
                .shadow(color: background.inkShadow, radius: 3, x: 0, y: 1)
        }
    }
}

#Preview("Card") {
    VStack(spacing: 28) {
        EditableCard(
            background: CardGradient.palette[1],
            content: CardContent(
                image: .symbol(name: "building.columns.fill", tint: .default),
                topNote: "EXPIRES 04 / 29",
                bottomNote: "Alex Morgan",
                icon: .symbol(name: "creditcard.fill", tint: .default)
            )
        )

        EditableCard(
            background: CardGradient.palette[6],
            content: CardContent(
                image: .symbol(name: "airplane", tint: CardMarkTint.palette[1]),
                topNote: "PASSPORT",
                bottomNote: "United Kingdom",
                icon: .symbol(name: "globe.europe.africa.fill", tint: CardMarkTint.palette[1])
            ),
            size: EditableCard.compact
        )
    }
    .padding(40)
}
