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

    init(
        title: String,
        text: Binding<String>,
        shouldIncludeLineLimit: Bool = true,
        placeholder: String,
        leadingSystemImageName: String? = "character.cursor.ibeam",
        trailingSystemImageName: String? = "multiply.circle.fill",
        showsClearButton: Bool = true,
        radius: CGFloat = 15
    ) {
        self.title = title
        _text = text
        self.shouldIncludeLineLimit = shouldIncludeLineLimit
        self.placeholder = placeholder
        self.leadingSystemImageName = leadingSystemImageName
        self.trailingSystemImageName = trailingSystemImageName
        self.showsClearButton = showsClearButton
        self.radius = radius
    }

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
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
            .padding()
        }
        .frame(maxWidth: .infinity)
        .glassyBackgroundWithStroke(cornerRadius: radius)
    }
}

#Preview {
    @Previewable @State var text = ""
    CustomTextField(title: "Name", text: $text, placeholder: "Enter name")
        .padding()
}
