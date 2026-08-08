//
//  CardMarkChooser.swift
//  RelayAirMobile
//
//  SF Symbol / import / remove chooser for a card corner mark.
//
//  There used to be a row of tint chips here. Symbols are engraved into the card now,
//  so they have no colour of their own to pick — a hole is whatever the card is made
//  of, and the chips were asking a question with no answer.
//

import SwiftUI

enum MarkSlot: String, Identifiable {
    case image
    case icon

    var id: String { rawValue }
}

enum MarkSource {
    case symbol
    case photo
}

struct CardMarkChooser: View {
    let slot: MarkSlot
    @Binding var mark: CardMark?
    let onChoose: (MarkSource) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                markOption(
                    icon: "square.grid.2x2.fill",
                    title: "Choose an icon",
                    detail: "Pick from SF Symbols"
                ) {
                    onChoose(.symbol)
                }

                markOption(
                    icon: "photo.fill",
                    title: "Import an image",
                    detail: "Use a photo from your library"
                ) {
                    onChoose(.photo)
                }

                if mark != nil {
                    markOption(
                        icon: "trash.fill",
                        title: "Remove",
                        detail: "Leave this corner empty",
                        isDestructive: true
                    ) {
                        mark = nil
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func markOption(
        icon: String,
        title: String,
        detail: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        isDestructive
                            ? Color(hex: "#D9534F")
                            : AppColors.textInverted(colorScheme: colorScheme)
                    )
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(
                            isDestructive
                                ? Color(hex: "#D9534F")
                                : AppColors.textInverted(colorScheme: colorScheme)
                        )
                    Text(detail)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme).opacity(0.7))
                }
                .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme).opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonSecondStyle())
        .hapticFeedback(style: .soft)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
        )
    }

}
