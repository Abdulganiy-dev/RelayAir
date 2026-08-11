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

    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private enum Field: Hashable {
        case top, bottom
    }

    var body: some View {
        VStack(spacing: 18) {
            plainField(
                label: "Top Right",
                placeholder: "Anything",
                text: $topNote,
                field: .top
            )

            plainField(
                label: "Bottom Left",
                placeholder: "Anything",
                text: $bottomNote,
                field: .bottom
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func plainField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(Color.black.opacity(0.35))
            )
            .focused($focusedField, equals: field)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Color.black.opacity(0.85))
            .tint(Color.black.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
            )
        }
    }
}
