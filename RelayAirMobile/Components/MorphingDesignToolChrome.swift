//
//  MorphingDesignToolChrome.swift
//  RelayAirMobile
//
//  Same idea as `MorphingGlassMenu`: size is driven through `Animatable`, and a
//  stable `glassEffectID` per tool makes expand/collapse morph from — and back
//  into — that tool's circle.
//

import SwiftUI

enum DesignTool: String, CaseIterable, Identifiable {
    case background
    case texture
    case finish
    case image
    case note
    case icon

    var id: String { rawValue }

    /// What the dock actually shows. `.finish` is built and fully wired but held back:
    /// every card is `.frosted`, and a picker whose answer is always the same is just a
    /// step in the way. Drop the filter to bring it back.
    static let docked: [DesignTool] = allCases.filter { $0 != .finish }

    var title: String {
        switch self {
        case .background: "Background"
        case .texture:    "Texture"
        case .finish:     "Finish"
        case .image:      "Top left media"
        case .note:       "Notes"
        case .icon:       "Bottom right media"
        }
    }

    var systemImage: String {
        switch self {
        case .background: "paintpalette.fill"
        case .texture:    "circle.hexagongrid.fill"
        case .finish:     "cube.transparent"
        case .image:      "photo.fill"
        case .note:       "text.alignleft"
        case .icon:       "star.fill"
        }
    }

    /// Media panels grow when a mark is already set — that is when the third
    /// (Remove) row appears. Pass `hasMark` for `.image` / `.icon`; ignored elsewhere.
    func expandedHeight(hasMark: Bool = false) -> CGFloat {
        switch self {
        case .background:   310
        case .texture:      230
        // Shorter than the others: three options in one row, but the ambient shadow
        // needs room below the swatches or the depth clips into a hard band.
        case .finish:       200
        case .note:         240
        case .image, .icon: hasMark ? 300 : 200
        }
    }
}

struct MorphingDesignToolChrome<Panel: View>: View, Animatable {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    /// 0 = icon only, 1 = panel fully revealed.
    var progress: CGFloat

    let tool: DesignTool
    let collapsedSize: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat
    let colorScheme: ColorScheme
    let namespace: Namespace.ID
    let onExpand: () -> Void
    @ViewBuilder let panel: () -> Panel

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

    /// Spring morphs can overshoot past 0; SwiftUI rejects non-finite / negative frames.
    private var safeWidth: CGFloat { sanitized(width) }
    private var safeHeight: CGFloat { sanitized(height) }
    private var safeExpandedWidth: CGFloat { sanitized(expandedWidth) }
    private var safeExpandedHeight: CGFloat { sanitized(expandedHeight) }
    private var safeCornerRadius: CGFloat {
        let value = cornerRadius.isFinite ? cornerRadius : collapsedSize / 2
        return max(value, 0)
    }

    /// Circular corners (not continuous) so a radius of half the collapsed size
    /// stays a true circle, matching `MorphingGlassMenu`.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: safeCornerRadius)
    }

    var body: some View {
        ZStack {
            panel()
                .frame(width: safeExpandedWidth, height: safeExpandedHeight, alignment: .top)
                .frame(width: safeWidth, height: safeHeight, alignment: .bottom)
                .opacity(panelOpacity)
                .blur(radius: panelBlur)
                .scaleEffect(panelScale, anchor: .bottom)
                .allowsHitTesting(progress > 0.85)

            iconButton
                .opacity(iconOpacity)
                .blur(radius: iconBlur)
                .allowsHitTesting(progress < 0.15)
        }
        .frame(width: safeWidth, height: safeHeight)
        .blur(radius: shellTransitionBlur)
        .clipShape(shape)
        .glassEffect(.regular, in: shape)
        .glassEffectID(tool.id, in: namespace)
        .scaleEffect(1 + 0.04 * clampedProgress, anchor: .bottom)
        .accessibilityLabel(tool.title)
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

    private var iconOpacity: Double {
        Double(1 - ramp(from: 0.08, to: 0.42))
    }

    private var iconBlur: CGFloat {
        max(0, ramp(from: 0, to: 0.42) * maxTransitionBlur * 0.9)
    }

    private var shellTransitionBlur: CGFloat {
        // Peaks mid-morph; clamp so spring overshoot cannot push blur negative.
        max(0, 4 * clampedProgress * (1 - clampedProgress) * (maxTransitionBlur * 0.4))
    }

    private var iconButton: some View {
        Button(action: onExpand) {
            Image(systemName: tool.systemImage)
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
