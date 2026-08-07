//
//  CardDesignNoteFields.swift
//  RelayAirMobile
//
//  Plain note / write-up fields for the card design dock. Kept apart so the two
//  corners read as separate edits — not CustomTextField chrome.
//

import SwiftUI

struct CardDesignNoteFields: View {
    @Binding var topNote: String
    @Binding var bottomNote: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 18) {
            plainField(
                label: "Bottom Left",
                placeholder: "Anything",
                text: $topNote
            )

            plainField(
                label: "Top Right",
                placeholder: "Anything",
                text: $bottomNote
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func plainField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme).opacity(0.55))
            )
            .font(.system(.body, design: .rounded))
            .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
            .tint(AppColors.textInverted(colorScheme: colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
            )
        }
    }
}
