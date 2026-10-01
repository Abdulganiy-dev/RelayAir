//
//  CustomTextField.swift
//  RelayAirMobile
//
//  Created by ABDULGANIY LAWAL on 07/08/2026.
//

import SwiftUI

enum RelayFormFieldLayout {
    static let controlHeight: CGFloat = 57
    static let titleSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 18
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let showsTitle: Bool
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
        showsTitle: Bool = true,
        shouldIncludeLineLimit: Bool = true,
        placeholder: String,
        leadingSystemImageName: String? = "character.cursor.ibeam",
        trailingSystemImageName: String? = "multiply.circle.fill",
        showsClearButton: Bool = true,
        radius: CGFloat = RelayFormFieldLayout.cornerRadius,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization? = nil
    ) {
        self.title = title
        _text = text
        self.showsTitle = showsTitle
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
       
        VStack(alignment: .leading, spacing: RelayFormFieldLayout.titleSpacing) {
            if showsTitle {
                Text(title)
                    .customTextStyle(.caption, color: .muted)
            }

            HStack(alignment: shouldIncludeLineLimit ? .top : .center, spacing: 10) {
                if let leadingSystemImageName {
                    Image(systemName: leadingSystemImageName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }

                Group {
                    if shouldIncludeLineLimit {
                        TextField("", text: $text, axis: .vertical)
                            .contentTransition(.numericText())
                            .focused($isFocused)
                            .accessibilityLabel(title)
                            .customTextStyle(.bodyMedium, color: .inverted)
                            .tint(AppColors.textInverted(colorScheme: colorScheme))
                            .placeholder(when: text.isEmpty, alignment: .leading) {
                                Text(placeholder)
                                    .customTextStyle(.body, color: .muted)
                            }
                            .lineLimit(1...10)
                            .multilineTextAlignment(.leading)
                    } else {
                        TextField("", text: $text)
                            .focused($isFocused)
                            .accessibilityLabel(title)
                            .customTextStyle(.bodyMedium, color: .inverted)
                            .tint(AppColors.textInverted(colorScheme: colorScheme))
                            .placeholder(when: text.isEmpty, alignment: .leading) {
                                Text(placeholder)
                                    .customTextStyle(.body, color: .muted)
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
                            .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .hapticFeedback(style: .light)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityLabel("Clear \(title)")
                }
            }
            .frame(minHeight: RelayFormFieldLayout.controlHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RelayFormFieldLayout.horizontalPadding)
            .relayRowBackground(cornerRadius: radius)
            .animation(.smooth(duration: 0.2), value: text.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    @Previewable @State var text = ""
    CustomTextField(title: "Name", text: $text, placeholder: "Enter name")
        .padding()
}
