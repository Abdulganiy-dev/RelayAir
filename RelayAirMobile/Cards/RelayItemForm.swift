//
//  RelayItemForm.swift
//  RelayAirMobile
//
//  One form per relay kind. All three are built from the same two rows — a text field
//  and a date field — so they read as one screen wearing different labels rather than
//  as three screens.
//
//  Keyboard, content type and capitalisation are set per field. On a form that is
//  mostly numbers and proper nouns, getting those wrong is the difference between
//  typing a card number in two seconds and fighting the keyboard for ten.
//

import SwiftUI

struct RelayItemForm: View {
    let type: RelayType
    @Binding var details: RelayItemDetails

    var body: some View {
        switch type {
        case .creditCard: CreditCardForm(details: $details.creditCard)
        case .passport:   PassportForm(details: $details.passport)
        case .address:    AddressForm(details: $details.address)
        }
    }
}

// MARK: - Credit card

private struct CreditCardForm: View {
    @Binding var details: CreditCardDetails

    var body: some View {
        FormStack {
            FormSection("Card") {
                FormField(
                    "Card number",
                    text: $details.number,
                    placeholder: "0000 0000 0000 0000",
                    icon: "creditcard",
                    keyboard: .numberPad,
                    contentType: .creditCardNumber,
                    format: .cardNumber
                )

                HStack(spacing: 12) {
                    FormField(
                        "Expires",
                        text: $details.expiry,
                        placeholder: "MM/YY",
                        icon: "calendar",
                        keyboard: .numberPad,
                        format: .expiry
                    )

                    FormField(
                        "Security code",
                        text: $details.securityCode,
                        placeholder: "CVV",
                        icon: "lock",
                        keyboard: .numberPad
                    )
                }
            }

            FormSection("Holder") {
                FormField(
                    "Name on card",
                    text: $details.holder,
                    placeholder: "Alex Morgan",
                    icon: "person",
                    contentType: .name,
                    capitalization: .words
                )
            }

            FormSection("Label", subtitle: "Optional") {
                FormField(
                    "Nickname",
                    text: $details.nickname,
                    placeholder: "Everyday card",
                    icon: "tag",
                    capitalization: .sentences
                )
            }
        }
    }
}

// MARK: - Passport

private struct PassportForm: View {
    @Binding var details: PassportDetails

    var body: some View {
        FormStack {
            FormSection("Holder") {
                FormField(
                    "Full name",
                    text: $details.fullName,
                    placeholder: "As printed in the passport",
                    icon: "person.text.rectangle",
                    contentType: .name,
                    capitalization: .words
                )

                FormDateField("Date of birth", date: $details.dateOfBirth, icon: "birthday.cake")
            }

            FormSection("Document") {
                FormField(
                    "Passport number",
                    text: $details.number,
                    placeholder: "000000000",
                    icon: "number",
                    capitalization: .characters
                )

                FormField(
                    "Nationality",
                    text: $details.nationality,
                    placeholder: "United Kingdom",
                    icon: "globe",
                    contentType: .countryName,
                    capitalization: .words
                )
            }

            FormSection("Validity", subtitle: "Optional") {
                FormDateField("Issued", date: $details.issued, icon: "calendar.badge.plus")
                FormDateField("Expires", date: $details.expires, icon: "calendar.badge.exclamationmark")
            }
        }
    }
}

// MARK: - Address

private struct AddressForm: View {
    @Binding var details: AddressDetails

    var body: some View {
        FormStack {
            FormSection("Street") {
                FormField(
                    "Address line 1",
                    text: $details.line1,
                    placeholder: "2140 Market St",
                    icon: "house",
                    contentType: .streetAddressLine1,
                    capitalization: .words
                )

                FormField(
                    "Address line 2",
                    text: $details.line2,
                    placeholder: "Apartment, suite, floor",
                    icon: "building.2",
                    contentType: .streetAddressLine2,
                    capitalization: .words
                )
            }

            FormSection("Locality") {
                FormField(
                    "City",
                    text: $details.city,
                    placeholder: "San Francisco",
                    icon: "building.columns",
                    contentType: .addressCity,
                    capitalization: .words
                )

                HStack(spacing: 12) {
                    FormField(
                        "State",
                        text: $details.region,
                        placeholder: "CA",
                        icon: "map",
                        contentType: .addressState,
                        capitalization: .words
                    )

                    FormField(
                        "Postcode",
                        text: $details.postcode,
                        placeholder: "94114",
                        icon: "number",
                        contentType: .postalCode,
                        capitalization: .characters
                    )
                }

                FormField(
                    "Country",
                    text: $details.country,
                    placeholder: "United States",
                    icon: "globe",
                    contentType: .countryName,
                    capitalization: .words
                )
            }

            FormSection("Label", subtitle: "Optional") {
                FormField(
                    "Nickname",
                    text: $details.label,
                    placeholder: "Home",
                    icon: "tag",
                    capitalization: .words
                )
            }
        }
    }
}

// MARK: - Shared chrome

private struct FormStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FormSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .opacity(0.65)
                }
            }
            .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))

            content
        }
    }
}

private struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let keyboard: UIKeyboardType
    let contentType: UITextContentType?
    let capitalization: TextInputAutocapitalization?
    let format: FieldFormat?

    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        capitalization: TextInputAutocapitalization? = nil,
        format: FieldFormat? = nil
    ) {
        self.title = title
        _text = text
        self.placeholder = placeholder
        self.icon = icon
        self.keyboard = keyboard
        self.contentType = contentType
        self.capitalization = capitalization
        self.format = format
    }

    var body: some View {
        CustomTextField(
            title: title,
            text: $text,
            shouldIncludeLineLimit: false,
            placeholder: placeholder,
            leadingSystemImageName: icon,
            keyboardType: keyboard,
            textContentType: contentType,
            autocapitalization: capitalization
        )
        .onChange(of: text) { _, new in
            guard let format else { return }
            let formatted = format.apply(to: new)
            // Guarded, or assigning back into the same binding re-enters this handler.
            if formatted != new { text = formatted }
        }
    }
}

/// A date that has not been set yet. Rendered as a row that says so, rather than
/// defaulting to today — a passport that quietly claims to have been issued this
/// morning is worse than one that admits the field is empty.
private struct FormDateField: View {
    let title: String
    @Binding var date: Date?
    let icon: String

    @State private var isPicking = false
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, date: Binding<Date?>, icon: String) {
        self.title = title
        _date = date
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.28)) { isPicking.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                        .frame(width: 18)

                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))

                    Spacer(minLength: 8)

                    Text(date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Select")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(
                            date == nil
                                ? AppColors.textMute(colorScheme: colorScheme)
                                : AppColors.textPrimary(colorScheme: colorScheme)
                        )

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                        .rotationEffect(.degrees(isPicking ? 180 : 0))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(BouncyButtonSecondStyle())
            .hapticFeedback(style: .soft)

            if isPicking {
                DatePicker(
                    title,
                    selection: Binding { date ?? .now } set: { date = $0 },
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))

                if date != nil {
                    Button("Clear") {
                        withAnimation(.smooth(duration: 0.28)) {
                            date = nil
                            isPicking = false
                        }
                    }
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                    .padding(.bottom, 14)
                    .hapticFeedback(style: .soft)
                }
            }
        }
        .glassyBackgroundWithStroke(cornerRadius: 15)
        .clipped()
    }
}

#Preview("Credit card") {
    @Previewable @State var details = RelayItemDetails()
    ScrollView {
        RelayItemForm(type: .creditCard, details: $details).padding()
    }
    .background(AppColors.background(colorScheme: .light))
}

#Preview("Passport") {
    @Previewable @State var details = RelayItemDetails()
    ScrollView {
        RelayItemForm(type: .passport, details: $details).padding()
    }
    .background(AppColors.background(colorScheme: .light))
}

#Preview("Address") {
    @Previewable @State var details = RelayItemDetails()
    ScrollView {
        RelayItemForm(type: .address, details: $details).padding()
    }
    .background(AppColors.background(colorScheme: .light))
}
