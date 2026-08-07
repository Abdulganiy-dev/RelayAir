//
//  MorphingGlassMenu.swift
//  RelayAirMobile
//
//  Single glass container that grows from a 44pt button into the add menu.
//  Size is driven through Animatable; GlassEffectContainer owns the glass morph.
//

import SwiftUI

struct MorphingGlassMenu: View {
    @Binding var screenType: EntryPage
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var namespace

    private let collapsedSize: CGFloat = 44
    private let expandedWidth: CGFloat = 200
    private let rowHeight: CGFloat = 44
    private let contentPadding: CGFloat = 6
    private let spacing: CGFloat = 12

    private var expandedHeight: CGFloat {
        contentPadding * 2 + CGFloat(RelayType.allCases.count) * rowHeight
    }

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
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
                namespace: namespace,
                onExpand: expand,
                onSelect: select
            )
        }
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
    var namespace: Namespace.ID
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

    private let maxTransitionBlur: CGFloat = 10

    /// Matches the glass shape exactly, so the blur halo is contained by the same
    /// outline the glass draws. Circular (not continuous) corners on purpose —
    /// at radius 22 on a 44pt frame that is what keeps the collapsed state a true
    /// circle rather than a squircle.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }

    var body: some View {
        ZStack {
            menuContent
                .frame(width: expandedWidth, height: expandedHeight, alignment: .topLeading)
                .frame(width: width, height: height, alignment: .topTrailing)
                .opacity(menuContentOpacity)
                .blur(radius: menuContentBlur)
                .scaleEffect(menuContentScale, anchor: .topTrailing)
                .allowsHitTesting(progress > 0.85)

            // Centered in the current glass bounds so it sits in the middle of the circle.
            plusButton
                .opacity(plusOpacity)
                .blur(radius: plusBlur)
                .scaleEffect(plusScale, anchor: .center)
                .allowsHitTesting(progress < 0.15)
        }
        .frame(width: width, height: height)
        // Blur first, then clip. The old order (.clipped() before .blur) blurred
        // content that had already been cut against transparency, which greyed the
        // edges out and let the halo spill past the pill instead of being held by it.
        .blur(radius: shellTransitionBlur)
        .clipShape(shape)
        .glassEffect(.clear, in: shape)
        .glassEffectID("menuChrome", in: namespace)
        .scaleEffect(1 + 0.04 * progress, anchor: .center)
    }

    /// Clamped 0→1 ramp across a sub-range of `progress`.
    private func ramp(from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        max(0, min(1, (progress - lower) / (upper - lower)))
    }

    // Every blur below is driven straight off `progress`, never off `1 - opacity`.
    // Deriving one from the other is what made the blur invisible: it put peak blur
    // exactly where opacity was lowest, so the softest frame was also the one you
    // could not see. Opacity now finishes early and blur keeps resolving behind it —
    // the content arrives, *then* comes into focus, which is the part that reads.

    private var menuContentOpacity: Double {
        Double(ramp(from: 0.22, to: 0.52))
    }

    private var menuContentScale: CGFloat {
        0.92 + 0.08 * progress
    }

    /// Still ~7pt soft at the moment the menu reaches full opacity, resolving to
    /// sharp only at the very end of the morph.
    private var menuContentBlur: CGFloat {
        (1 - ramp(from: 0.3, to: 1)) * maxTransitionBlur
    }

    /// Held a beat before it starts fading, so the blur below has something to act on.
    private var plusOpacity: Double {
        Double(1 - ramp(from: 0.08, to: 0.42))
    }

    private var plusScale: CGFloat {
        1 - 0.15 * progress
    }

    /// Leads the fade — the plus goes soft while it is still clearly visible.
    private var plusBlur: CGFloat {
        ramp(from: 0, to: 0.42) * maxTransitionBlur * 0.9
    }

    /// Peaks mid-morph (0 at both ends) so the shell itself softens while resizing.
    /// Scaled well down from `maxTransitionBlur`: this stacks on top of the
    /// per-element blur, and the sum is what actually lands on screen.
    private var shellTransitionBlur: CGFloat {
        4 * progress * (1 - progress) * (maxTransitionBlur * 0.4)
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
        .frame(width: collapsedSize, height: collapsedSize)
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
