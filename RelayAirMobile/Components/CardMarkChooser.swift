//
//  CardMarkChooser.swift
//  RelayAirMobile
//
//  SF Symbol / import / remove chooser for a card corner mark, plus tint chips
//  when the active mark is a symbol.
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

                if case .symbol(let name, let selected) = mark {
                    tintRow(symbol: name, selected: selected)
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

    private func tintRow(symbol: String, selected: CardMarkTint) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CardMarkTint.palette) { tint in
                    Button {
                        mark = .symbol(name: symbol, tint: tint)
                    } label: {
                        Circle()
                            .fill(tint.color)
                            .frame(width: 26, height: 26)
                            .padding(3)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        AppColors.textInverted(colorScheme: colorScheme),
                                        lineWidth: 2
                                    )
                                    .opacity(tint.id == selected.id ? 1 : 0)
                                    .scaleEffect(tint.id == selected.id ? 1 : 0.86)
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(BouncyButtonSecondStyle())
                    .hapticFeedback(style: .soft)
                    .accessibilityLabel(tint.name)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)
    }
}
