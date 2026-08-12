//
//  RelayItemOptionMenu.swift
//  RelayAirMobile
//


import SwiftUI

struct RelayItemOptionMenu: View {
    let item: RelayItem
    @Binding var toggle: Bool
    var onRelay: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    /// Hardware Dynamic Island (compact cutout).
    private let compactWidth: CGFloat = 126
    private let compactHeight: CGFloat = 36.67
    private let expandedHeight: CGFloat = 285

    private let expandedCornerRadius: CGFloat = 44
    
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
            menuTitle: item.displayName,
            onExpand: expand,
            onRelay: onRelay,
            onEdit: onEdit,
            onDelete: onDelete
        )
        .id(item.id)
        .animation(toggle ? Tokens.islandMorphOpen : Tokens.islandMorphClose, value: toggle)
    }

    private func expand() {
        withAnimation(Tokens.islandMorphOpen) {
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
    let menuTitle: String
    let onExpand: () -> Void
    let onRelay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

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
        .frame(width: safeWidth, height: safeHeight, alignment: .bottom)
        .blur(radius: shellTransitionBlur)
        .background(.black.opacity(shellFillOpacity), in: shape)
        .clipShape(shape)
        .shadow(
            color: .black.opacity(panelShadowOpacity),
            radius: panelShadowRadius,
            x: 0,
            y: panelShadowY
        )
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

    private var shellFillOpacity: Double {
        Double(ramp(from: 0, to: 0.45))
    }

    private var panelShadowOpacity: Double {
        Double(ramp(from: 0.4, to: 1)) * 0.45
    }

    private var panelShadowRadius: CGFloat {
        8 + 20 * ramp(from: 0.4, to: 1)
    }

    private var panelShadowY: CGFloat {
        16 * ramp(from: 0.4, to: 1)
    }

    private var islandHitTarget: some View {
        RoundedRectangle(cornerRadius: compactHeight / 2, style: .circular)
            .fill(.clear)
            .frame(width: compactWidth, height: compactHeight)
            .contentShape(RoundedRectangle(cornerRadius: compactHeight / 2, style: .circular))
            .onTapGesture(perform: onExpand)
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Options for \(menuTitle)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.darkColors.textTextInverted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
               

            OptionActionButton(
                title: "Relay",
                subtitle: "Send this to your Mac",
                systemImage: "antenna.radiowaves.left.and.right",
                iconColor: Color(hex: "#00D743"),
                action: onRelay
            )
            OptionActionButton(
                title: "Edit",
                subtitle: "Update details and design",
                systemImage: "pencil",
                iconColor: AppColors.lightColors.primaryPrimaryDefault,
                action: onEdit
            )
            OptionActionButton(
                title: "Delete",
                subtitle: "Remove this item for good",
                systemImage: "trash",
                iconColor: AppColors.lightColors.errorErrorDefault,
                action: onDelete
            )
            .padding(.bottom, 25)
        }
        .padding(16)
        .frame(width: safeExpandedWidth, height: safeExpandedHeight, alignment: .center)
    }
}

private struct OptionActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let iconColor: Color
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(iconColor.gradient)
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.darkColors.textTextInverted)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.darkColors.textTextMute)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(shape)
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        VStack {
            RelayItemOptionMenu(
                item: RelayItem(id: UUID(), type: .creditCard, tag: "GTBank debit"),
                toggle: .constant(true),
                onRelay: {},
                onEdit: {},
                onDelete: {}
            )
            Spacer()
        }
    }
}
