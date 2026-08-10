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
        
        FormStack {
            
            FormField(
                "Tag",
                text: $details.tag,
                placeholder: type.tagExample,
                icon: "tag",
                capitalization: .sentences
            )

            switch type {
            case .creditCard: CreditCardForm(details: $details.creditCard)
            case .passport:   PassportForm(details: $details.passport)
            case .address:    AddressForm(details: $details.address)
            }
        }
    }
}

// MARK: - Credit card

private struct CreditCardForm: View {
    @Binding var details: CreditCardDetails

    var body: some View {
        Group {
            FormField(
                "Card number",
                text: $details.number,
                placeholder: "The long number on the front of your card",
                icon: "creditcard",
                keyboard: .numberPad,
                contentType: .creditCardNumber,
                format: .cardNumber
            )

            HStack(spacing: 12) {
                FormField(
                    "Expires",
                    text: $details.expiry,
                    placeholder: "Month / year, e.g. 08/28",
                    icon: "calendar",
                    keyboard: .numberPad,
                    format: .expiry
                )

                FormField(
                    "Security code",
                    text: $details.securityCode,
                    placeholder: "3 or 4 digits on the back",
                    icon: "lock",
                    keyboard: .numberPad
                )
            }

            FormField(
                "Name on card",
                text: $details.holder,
                placeholder: "Exactly as printed on the card",
                icon: "person",
                contentType: .name,
                capitalization: .words
            )
        }
    }
}

// MARK: - Passport

private struct PassportForm: View {
    @Binding var details: PassportDetails

    var body: some View {
        Group {
            FormField(
                "Full name",
                text: $details.fullName,
                placeholder: "Exactly as printed in your passport",
                icon: "person.text.rectangle",
                contentType: .name,
                capitalization: .words
            )

            FormSexField(sex: $details.sex)

            FormDateField("Date of birth", date: $details.dateOfBirth, icon: "birthday.cake")

            FormField(
                "Place of birth",
                text: $details.placeOfBirth,
                placeholder: "City or country on your passport",
                icon: "mappin.and.ellipse",
                capitalization: .words
            )

            FormField(
                "Passport number",
                text: $details.number,
                placeholder: "The number on your biodata page",
                icon: "number",
                capitalization: .characters
            )

            FormField(
                "Nationality",
                text: $details.nationality,
                placeholder: "e.g. Nigerian",
                icon: "globe",
                contentType: .countryName,
                capitalization: .words
            )

            FormField(
                "Passport type",
                text: $details.passportType,
                placeholder: "Ordinary, official, or diplomatic",
                icon: "doc.text",
                capitalization: .words
            )

            FormField(
                "Issuing authority",
                text: $details.issuingAuthority,
                placeholder: "Agency that issued your passport",
                icon: "building.columns",
                capitalization: .words
            )

            FormField(
                "Personal number",
                text: $details.personalNumber,
                placeholder: "National ID number, if shown",
                icon: "person.text.rectangle",
                capitalization: .characters
            )

            FormDateField("Date of issue", date: $details.issued, icon: "calendar.badge.plus")
            FormDateField("Date of expiry", date: $details.expires, icon: "calendar.badge.exclamationmark")
        }
    }
}

// MARK: - Address

private struct AddressForm: View {
    @Binding var details: AddressDetails

    var body: some View {
        Group {
            FormField(
                "Address line 1",
                text: $details.line1,
                placeholder: "Street number and name",
                icon: "house",
                contentType: .streetAddressLine1,
                capitalization: .words
            )

            FormField(
                "Address line 2",
                text: $details.line2,
                placeholder: "Flat, estate, or landmark (optional)",
                icon: "building.2",
                contentType: .streetAddressLine2,
                capitalization: .words
            )

            FormField(
                "City",
                text: $details.city,
                placeholder: "e.g. Lagos, Abuja, Port Harcourt",
                icon: "building.columns",
                contentType: .addressCity,
                capitalization: .words
            )

            HStack(spacing: 12) {
                FormField(
                    "State",
                    text: $details.region,
                    placeholder: "e.g. Lagos, FCT",
                    icon: "map",
                    contentType: .addressState,
                    capitalization: .words
                )

                FormField(
                    "Postcode",
                    text: $details.postcode,
                    placeholder: "Postal code, if you have one",
                    icon: "number",
                    contentType: .postalCode,
                    capitalization: .characters
                )
            }

            FormField(
                "Country",
                text: $details.country,
                placeholder: "e.g. Nigeria",
                icon: "globe",
                contentType: .countryName,
                capitalization: .words
            )
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

private struct FormSexField: View {
    @Binding var sex: PassportSex?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                .frame(width: 18)

            Text("Sex")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))

            Spacer(minLength: 8)

            Picker("Sex", selection: $sex) {
                Text("Select").tag(Optional<PassportSex>.none)
                ForEach(PassportSex.allCases) { option in
                    Text(option.label).tag(Optional(option))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(
                sex == nil
                    ? AppColors.textMute(colorScheme: colorScheme)
                    : AppColors.textPrimary(colorScheme: colorScheme)
            )
        }
        .padding(.vertical,10)
        .padding(.leading)
        .padding(.trailing,3)
        .frame(maxWidth: .infinity)
        .glassyBackgroundWithStroke(cornerRadius: 15)
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
                withAnimation(.spring()) { isPicking.toggle() }
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

            
        }
        .glassyBackgroundWithStroke(cornerRadius: 15)
        .clipped()
        .padding(.bottom,isPicking ? 0 : 10)

        if isPicking {
            VStack{
                DatePicker(
                    title,
                    selection: Binding { date ?? .now } set: { date = $0 },
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.blurReplace)

                if date != nil {
                    Button("Clear") {
                        withAnimation(.spring()) {
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
            .glassyBackgroundWithStroke(cornerRadius: 15)
            .clipped()
            .transition(.blurReplace)
        }
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
