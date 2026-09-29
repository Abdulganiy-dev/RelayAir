import SwiftUI

struct RelayTypePickerMenu: View {
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
                ForEach(RelayType.allCases) { type in
                    RelayTypePickerTile(type: type) {
                        onSelect(type)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerShape(menuContainerShape)
        .background {
            menuShape
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: -5)
        }
        .compositingGroup()
    }
}

private struct RelayTypePickerTile: View {
    let type: RelayType
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var tileShape: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: 14), isUniform: true)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                Image(type.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    
                Text(type.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(
                AppColors.textMute(colorScheme: colorScheme).opacity(0.12),
                in: tileShape
            )
            .contentShape(tileShape)
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
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
