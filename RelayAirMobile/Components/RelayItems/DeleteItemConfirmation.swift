//
//  DeleteItemConfirmation.swift
//  RelayAirMobile
//
//  Shown in a popover pinned above the card being deleted, so the card stays in view
//  while you decide — a system confirmation dialog sits wherever it likes, which on
//  the wallet was right on top of the card.
//

import SwiftUI

struct DeleteItemConfirmation: View {
    let item: RelayItem
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Delete \u{201C}\(item.displayName)\u{201D}?")
                    .customTextStyle(.title, color: .inverted)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text("This card and everything saved on it will be removed from this device.")
                    .customTextStyle(.supporting, color: .muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .customTextStyle(.action, color: .inverted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .hapticFeedback(style: .light)

                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                        .customTextStyle(.action, color: .custom(.white))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(AppColors.errorDefault(colorScheme: colorScheme))
                .hapticFeedback(style: .medium)
            }
        }
        .padding(20)
        .frame(width: 320)
        .accessibilityAction(.escape, onCancel)
    }
}
