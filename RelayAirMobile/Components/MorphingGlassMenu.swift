//
//  MorphingGlassMenu.swift
//  RelayAirMobile
//
//  Single glass container that grows from a 44pt button into the add menu.
//  Size is driven through Animatable so width/height interpolate frame-by-frame.
//

import SwiftUI

struct MorphingGlassMenu: View {
    @Binding var screenType: EntryPage
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let collapsedSize: CGFloat = 44
    private let expandedWidth: CGFloat = 200
    private let rowHeight: CGFloat = 44
    private let contentPadding: CGFloat = 6

    private var expandedHeight: CGFloat {
        contentPadding * 2 + CGFloat(RelayType.allCases.count) * rowHeight
    }

    var body: some View {
        MorphingMenuLayout(
            width: isExpanded ? expandedWidth : collapsedSize,
            height: isExpanded ? expandedHeight : collapsedSize,
            cornerRadius: isExpanded ? 22 : collapsedSize / 2,
            progress: isExpanded ? 1 : 0,
            collapsedSize: collapsedSize,
            expandedWidth: expandedWidth,
            expandedHeight: expandedHeight,
            rowHeight: rowHeight,
            contentPadding: contentPadding,
            colorScheme: colorScheme,
            onExpand: expand,
            onSelect: select
        )
    }

    private func expand() {
        withAnimation(Tokens.menuJump) {
            isExpanded = true
        }
    }

    private func select(_ type: RelayType) {
        withAnimation(Tokens.menuJump) {
            isExpanded = false
           
        }
        withAnimation(Tokens.fastBounceAnimation) {
           screenType = .add(type)
        }
    }
}

/// Interpolates geometry each frame so the glass chrome visibly grows/shrinks.
private struct MorphingMenuLayout: View, Animatable {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    /// 0 = plus only, 1 = menu fully revealed.
    var progress: CGFloat

    var collapsedSize: CGFloat
    var expandedWidth: CGFloat
    var expandedHeight: CGFloat
    var rowHeight: CGFloat
    var contentPadding: CGFloat
    var colorScheme: ColorScheme
    var onExpand: () -> Void
    var onSelect: (RelayType) -> Void

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(width, height),
                AnimatablePair(cornerRadius, progress)
            )
        }
        set {
            width = newValue.first.first
            height = newValue.first.second
            cornerRadius = newValue.second.first
            progress = newValue.second.second
        }
    }

    var body: some View {
        // Grow from the trailing edge so the plus stays put; rows stay leading-aligned.
        ZStack(alignment: .topTrailing) {
            menuContent
                .frame(width: expandedWidth, height: expandedHeight, alignment: .topLeading)
                .opacity(menuContentOpacity)
                .scaleEffect(menuContentScale, anchor: .topTrailing)
                .allowsHitTesting(progress > 0.85)

            plusButton
                .opacity(plusOpacity)
                .scaleEffect(plusScale, anchor: .center)
                .allowsHitTesting(progress < 0.15)
        }
        .frame(width: width, height: height, alignment: .topTrailing)
        .clipped()
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: cornerRadius))
        .scaleEffect(0.94 + 0.06 * progress, anchor: .topTrailing)
    }

    private var menuContentOpacity: Double {
        Double(max(0, min(1, (progress - 0.35) / 0.45)))
    }

    private var menuContentScale: CGFloat {
        0.92 + 0.08 * progress
    }

    private var plusOpacity: Double {
        Double(max(0, min(1, 1 - progress * 1.6)))
    }

    private var plusScale: CGFloat {
        1 - 0.15 * progress
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(RelayType.allCases.enumerated()), id: \.element.id) { index, type in
                Button {
                    onSelect(type)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Text(type.title)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hapticFeedback(style: .soft)

                if index < RelayType.allCases.count - 1 {
                    Divider()
                        .opacity(0.35)
                        .padding(.horizontal, 14)
                }
            }
        }
        .padding(.vertical, contentPadding)
    }

    private var plusButton: some View {
        Button(action: onExpand) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.iconInverted(colorScheme: colorScheme).gradient)
                .frame(width: collapsedSize, height: collapsedSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hapticFeedback(style: .soft)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        HStack {
            Spacer()
            MorphingGlassMenu(screenType: .constant(.main), isExpanded: .constant(false))
                .padding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
