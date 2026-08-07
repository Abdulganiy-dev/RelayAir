//
//  CustomTextField.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 07/08/2026.
//

import SwiftUI

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let shouldIncludeLineLimit: Bool
    let placeholder: String
    let leadingSystemImageName: String?
    let trailingSystemImageName: String?
    let showsClearButton: Bool
    let radius: CGFloat
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization?

    init(
        title: String,
        text: Binding<String>,
        shouldIncludeLineLimit: Bool = true,
        placeholder: String,
        leadingSystemImageName: String? = "character.cursor.ibeam",
        trailingSystemImageName: String? = "multiply.circle.fill",
        showsClearButton: Bool = true,
        radius: CGFloat = 15,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization? = nil
    ) {
        self.title = title
        _text = text
        self.shouldIncludeLineLimit = shouldIncludeLineLimit
        self.placeholder = placeholder
        self.leadingSystemImageName = leadingSystemImageName
        self.trailingSystemImageName = trailingSystemImageName
        self.showsClearButton = showsClearButton
        self.radius = radius
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
    }

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Top-aligned when the field can grow, centred when it cannot — otherwise the
        // leading glyph drifts to the middle of a tall field.
        HStack(alignment: shouldIncludeLineLimit ? .top : .center, spacing: 10) {
            if let leadingSystemImageName {
                Image(systemName: leadingSystemImageName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                    .frame(width: 18)
                    .accessibilityHidden(true)
            }

            Group {
                if shouldIncludeLineLimit {
                    TextField("", text: $text, axis: .vertical)
                        .contentTransition(.numericText())
                        .focused($isFocused)
                        .fontWeight(.medium)
                        .customTextStyle(color: AppColors.textPrimary(colorScheme: colorScheme), fontStyle: .body)
                        .tint(AppColors.textPrimary(colorScheme: colorScheme))
                        .placeholder(when: text.isEmpty, alignment: .leading) {
                            Text(placeholder)
                                .font(.body)
                                .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                                .fontWeight(.regular)
                                .fontDesign(.rounded)
                        }
                        .lineLimit(1...10)
                        .multilineTextAlignment(.leading)
                } else {
                    TextField("", text: $text)
                        .focused($isFocused)
                        .fontWeight(.medium)
                        .customTextStyle(color: AppColors.textPrimary(colorScheme: colorScheme), fontStyle: .body)
                        .tint(AppColors.textPrimary(colorScheme: colorScheme))
                        .placeholder(when: text.isEmpty, alignment: .leading) {
                            Text(placeholder)
                                .font(.body)
                                .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                                .fontWeight(.regular)
                                .fontDesign(.rounded)
                        }
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .frame(height: 14)
                }
            }
            // Set on the container rather than on each branch — both read them from
            // the same place, so duplicating them is one more thing to keep in step.
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)

            if showsClearButton, let trailingSystemImageName, !text.isEmpty {
                Button {
                    text = ""
                    // Keep the caret where the user was — clearing a field is almost
                    // never the end of editing it.
                    isFocused = true
                } label: {
                    Image(systemName: trailingSystemImageName)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .hapticFeedback(style: .soft)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityLabel("Clear \(title)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassyBackgroundWithStroke(cornerRadius: radius)
        .animation(.smooth(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    @Previewable @State var text = ""
    CustomTextField(title: "Name", text: $text, placeholder: "Enter name")
        .padding()
}
