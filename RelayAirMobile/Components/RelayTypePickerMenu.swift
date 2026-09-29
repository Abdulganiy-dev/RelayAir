import SwiftUI

struct RelayTypePickerMenu: View {
    var isPresentationComplete = true
    let onSelect: (RelayType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var menuContainerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
    }

    private var menuShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 28), isUniform: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Create a relay item")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.textInverted(colorScheme: .light))

                Text("What would you like to save?")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppColors.textMute(colorScheme: .light))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RelayType.allCases.enumerated(), id: \.element.id) { index, type in
                    RelayTypePickerTile(
                        type: type,
                        entranceDelay: .milliseconds(index * 20),
                        isPresentationComplete: isPresentationComplete
                    ) {
                        onSelect(type)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            menuShape
                .fill(Color(hex: "#F8F7F2"))
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
        .compositingGroup()
    }
}

private struct RelayTypePickerTile: View {
    let type: RelayType
    let entranceDelay: Duration
    let isPresentationComplete: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var tileShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 14), isUniform: true)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(type.iconAssetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 84, height: 84)

                Text(type.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
//            .background(
//                AppColors.textMute(colorScheme: colorScheme).opacity(0.12),
//                in: tileShape
//            )
            .contentShape(tileShape)
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
        .rotation3DEffect(
            .degrees(hasAppeared || reduceMotion ? 0 : -14),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.35
        )
        .blur(radius: hasAppeared || reduceMotion ? 0 : 6)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 18)
        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.94)
        .allowsHitTesting(hasAppeared)
        .accessibilityHidden(!hasAppeared)
        .task(id: isPresentationComplete) {
            guard isPresentationComplete, !hasAppeared else { return }

            guard !reduceMotion else {
                hasAppeared = true
                return
            }

            do {
                try await Task.sleep(for: entranceDelay)
            } catch {
                return
            }

            withAnimation(Tokens.fastBounceAnimation) {
                hasAppeared = true
            }
        }
    }
}

#Preview("Relay type picker") {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.14)
            .ignoresSafeArea()

        RelayTypePickerMenu(onSelect: { _ in })
            .frame(height: 360)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
