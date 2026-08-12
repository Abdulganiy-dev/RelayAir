//
//  RelayItemOptionMenu.swift
//  RelayAirMobile
//


import SwiftUI

struct RelayItemOptionMenu: View {
    let item: RelayItem
    @Binding var toggle: Bool

    /// Hardware Dynamic Island (compact cutout).
    private let compactWidth: CGFloat = 126
    private let compactHeight: CGFloat = 36.67
    private let expandedHeight: CGFloat = 250
    /// Apple HIG: expanded island uses a 44pt corner radius.
    private let expandedCornerRadius: CGFloat = 44
    /// Expanded Live Activity is 371pt on 393-wide phones and 408pt on 430-wide —
    /// 11pt from each edge.
    private let expandedEdgeInset: CGFloat = 11

    private var compactCornerRadius: CGFloat { compactHeight / 2 }
    private var expandedWidth: CGFloat { UIScreen.screenWidth - (expandedEdgeInset * 2) }

    var body: some View {
        RelayItemOptionMenuLayout(
            width: toggle ? expandedWidth : compactWidth,
            height: toggle ? expandedHeight : compactHeight,
            cornerRadius: toggle ? expandedCornerRadius : compactCornerRadius,
            progress: toggle ? 1 : 0,
            compactWidth: compactWidth,
            compactHeight: compactHeight,
            expandedWidth: expandedWidth,
            expandedHeight: expandedHeight,
            item: item,
            onExpand: expand
        )
        .animation(Tokens.islandMorph, value: toggle)
    }

    private func expand() {
        withAnimation(Tokens.islandMorph) {
            toggle = true
        }
    }
}

/// Interpolates geometry each frame so the glass chrome visibly grows/shrinks.
private struct RelayItemOptionMenuLayout: View, Animatable {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    /// 0 = island pill, 1 = panel fully revealed.
    var progress: CGFloat

    let compactWidth: CGFloat
    let compactHeight: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat
    let item: RelayItem
    let onExpand: () -> Void

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

    private let maxTransitionBlur: CGFloat = 10

    private var safeWidth: CGFloat { sanitized(width) }
    private var safeHeight: CGFloat { sanitized(height) }
    private var safeExpandedWidth: CGFloat { sanitized(expandedWidth) }
    private var safeExpandedHeight: CGFloat { sanitized(expandedHeight) }
    private var safeCornerRadius: CGFloat {
        let value = cornerRadius.isFinite ? cornerRadius : compactHeight / 2
        return max(value, 0)
    }

    /// Circular corners so the collapsed 37.33pt radius is a true pill, not a squircle.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: safeCornerRadius, style: .circular)
    }

    var body: some View {
        ZStack {
            expandedPanel
                .frame(width: safeExpandedWidth, height: safeExpandedHeight, alignment: .top)
                .frame(width: safeWidth, height: safeHeight, alignment: .top)
                .opacity(panelOpacity)
                .blur(radius: panelBlur)
                .scaleEffect(panelScale, anchor: .top)
                .allowsHitTesting(progress > 0.85)

            islandHitTarget
                .opacity(islandOpacity)
                .blur(radius: islandBlur)
                .allowsHitTesting(progress < 0.15)
        }
        .frame(width: safeWidth, height: safeHeight)
        .blur(radius: shellTransitionBlur)
        .background(.black, in: shape)
        .clipShape(shape)
    }

    private func sanitized(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 1 }
        return max(value, 1)
    }

    private var clampedProgress: CGFloat {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private func ramp(from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        let span = upper - lower
        guard span > 0 else { return 0 }
        return max(0, min(1, (clampedProgress - lower) / span))
    }

    private var panelOpacity: Double {
        Double(ramp(from: 0.22, to: 0.52))
    }

    private var panelScale: CGFloat {
        0.92 + 0.08 * clampedProgress
    }

    private var panelBlur: CGFloat {
        max(0, (1 - ramp(from: 0.3, to: 1)) * maxTransitionBlur)
    }

    private var islandOpacity: Double {
        Double(1 - ramp(from: 0.08, to: 0.42))
    }

    private var islandBlur: CGFloat {
        max(0, ramp(from: 0, to: 0.42) * maxTransitionBlur * 0.9)
    }

    private var shellTransitionBlur: CGFloat {
        max(0, 4 * clampedProgress * (1 - clampedProgress) * (maxTransitionBlur * 0.4))
    }

    private var islandHitTarget: some View {
        RoundedRectangle(cornerRadius: compactHeight / 2, style: .circular)
            .fill(.clear)
            .frame(width: compactWidth, height: compactHeight)
            .contentShape(RoundedRectangle(cornerRadius: compactHeight / 2, style: .circular))
            .onTapGesture(perform: onExpand)
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: item.type.systemImage)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(item.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: safeExpandedWidth, height: safeExpandedHeight, alignment: .topLeading)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        VStack {
            RelayItemOptionMenu(
                item: RelayItem(id: UUID(), type: .creditCard, tag: "GTBank debit"),
                toggle: .constant(false)
            )
            Spacer()
        }
    }
}
