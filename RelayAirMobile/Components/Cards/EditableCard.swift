//
//  EditableCard.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  The card itself — 358 × 225, blank for now. Content comes later; this is the
//  surface the user dresses.
//
//  The card is deliberately more than a filled rectangle: a colour-matched rim
//  and a drop shadow give it depth without washing out the chosen background.
//

import SwiftUI

struct EditableCard: View {
    let background: CardGradient

    var content = CardContent()

    /// Surface texture, composited over the background. Separate from `content`
    /// because it dresses the whole card rather than occupying a slot on it.
    var texture: CardTexture?

    /// How the edge and depth are built. Frosted is the default, with a softer rim.
    var finish: CardFinish = .frosted

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
            .overlay(textureLayer)
            .overlay(contentLayer)
            .overlay(rimLayer)
            .frame(width: size?.width, height: size?.height)

            .compositingGroup()
            .shadow(color: .black.opacity(0.15),
                    radius: 15, x: 0, y: 4)
            // .shadow(color: .black.opacity(finish.ambientShadow.opacity),
            //         radius: finish.ambientShadow.radius, x: 0, y: finish.ambientShadow.y)
            .animation(.smooth(duration: 0.35), value: background)
            .animation(.smooth(duration: 0.25), value: content)
            .animation(.smooth(duration: 0.3), value: texture)
            .animation(.smooth(duration: 0.3), value: finish)
    }

    /// Several sub-pixel strokes rather than one border. Alternating light and dark
    /// down through the inset is what reads as a milled edge — a single line reads as
    /// a shape with an outline drawn round it.
    private var rimLayer: some View {
        ZStack {
            ForEach(finish.rim(for: background)) { layer in
                shape
                    .inset(by: layer.inset)
                    .strokeBorder(layer.style, lineWidth: layer.width)
                    .blendMode(layer.blendMode)
            }
        }
    }

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


}

// MARK: - Engraving


private struct EngravedSymbol: View {
    let name: String

    private let weight: Font.Weight = .regular

    var body: some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .fontWeight(weight)
            .foregroundStyle(
                Color.black.opacity(0.42)
                    .shadow(.inner(color: .black.opacity(0.85), radius: 1.6, x: 1.1, y: 1.5))
                    .shadow(.drop(color: .white.opacity(0.30), radius: 0.7, x: 0.5, y: 1.1))
            )
    }
}

// MARK: - Content

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
                     hierarchy: .supportingEmphasis,
                     tracking: 0.6,
                     colour: background.secondaryInk,
                     maxWidth: 148)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 14) {
                note(content.bottomNote,
                     alignment: .leading,
                     hierarchy: .prominent,
                     tracking: 0.2,
                     colour: background.ink,
                     maxWidth: 212)
                Spacer(minLength: 14)
                mark(content.icon, alignment: .bottomTrailing)
            }
        }
        .padding(inset)
    }


    @ViewBuilder
    private func mark(_ mark: CardMark?, alignment: Alignment) -> some View {
        switch mark {
        case .symbol(let name):
            ZStack(alignment: alignment) {
                EngravedSymbol(name: name)
                    .id(name)
                    .transition(.scale.combined(with: .opacity))
            }
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
        hierarchy: AppTextHierarchy,
        tracking: CGFloat,
        colour: Color,
        maxWidth: CGFloat
    ) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Text(trimmed)
                .customTextStyle(hierarchy, color: .custom(colour), fontDesign: .rounded)
                .tracking(tracking)
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .frame(
                    maxWidth: maxWidth,
                    alignment: alignment == .trailing ? .trailing : .leading
                )
                .fixedSize(horizontal: false, vertical: true)
               
                .shadow(color: background.inkShadow, radius: 3, x: 0, y: 1)
        }
    }
}

#Preview("Card") {
    VStack(spacing: 28) {
        EditableCard(
            background: .named("midnight"),
            content: CardContent(
                image: .symbol(name: "building.columns.fill"),
                topNote: "EXPIRES 04 / 29",
                bottomNote: "Alex Morgan",
                icon: .symbol(name: "creditcard.fill")
            )
        )

        EditableCard(
            background: .named("platinum"),
            content: CardContent(
                image: .symbol(name: "airplane"),
                topNote: "PASSPORT",
                bottomNote: "United Kingdom",
                icon: .symbol(name: "globe.europe.africa.fill")
            ),
            size: EditableCard.compact
        )
    }
    .padding(40)
}
