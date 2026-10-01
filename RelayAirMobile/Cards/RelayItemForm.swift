//
//  RelayItemForm.swift
//  RelayAirMobile
//
//  One form per relay kind. Shared inputs keep the different item forms feeling like
//  one screen wearing different labels rather than unrelated screens.
//
//  Keyboard, content type and capitalisation are set per field. On a form that is
//  mostly numbers and proper nouns, getting those wrong is the difference between
//  typing a card number in two seconds and fighting the keyboard for ten.
//

import SwiftUI

enum CustomFieldEditorMode: Equatable, Identifiable {
    case adding
    case editing(UUID)

    var id: String {
        switch self {
        case .adding: "adding"
        case .editing(let id): id.uuidString
        }
    }
}

struct RelayItemForm: View {
    let type: RelayType
    /// Separate from `details` because it is stored separately: the tag lives on the row
    /// in plain text so a list can show it, while everything in `details` sits behind
    /// Face ID.
    @Binding var tag: String
    @Binding var details: RelayItemDetails
    var customFieldEditorMode: Binding<CustomFieldEditorMode?> = .constant(nil)
    var onCustomFieldAdded: (UUID) -> Void = { _ in }

    private var customDetails: Binding<CustomRelayDetails> {
        Binding(
            get: { details.custom ?? CustomRelayDetails() },
            set: { details.custom = $0 }
        )
    }

    var body: some View {

        FormStack {

            FormField(
                "Tag",
                text: $tag,
                placeholder: type.tagExample,
                icon: "tag",
                capitalization: .sentences
            )

            switch type {
            case .creditCard: CreditCardForm(details: $details.creditCard)
            case .passport:   PassportForm(details: $details.passport)
            case .address:    AddressForm(details: $details.address)
            case .custom:
                CustomRelayForm(
                    details: customDetails,
                    editorMode: customFieldEditorMode,
                    onFieldAdded: onCustomFieldAdded
                )
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

// MARK: - Custom

private struct CustomRelayForm: View {
    @Binding var details: CustomRelayDetails
    @Binding var editorMode: CustomFieldEditorMode?
    let onFieldAdded: (UUID) -> Void
    @State private var draftTitle = ""
    @State private var draftKind: CustomFieldKind?
    @State private var pendingDeletionID: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if details.fields.isEmpty {
                Text("Add a field with the + button to choose what this item stores.")
                    .customTextStyle(.supporting, color: .muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach($details.fields) { $field in
                CustomFieldRow(
                    field: $field,
                    canEdit: editorMode == nil,
                    onEdit: { editorMode = .editing(field.id) },
                    onDelete: { pendingDeletionID = field.id }
                )
                .id(field.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $editorMode) { _ in
            builder
                .presentationDetents([.medium, .large])
                .presentationBackground(AppColors.background(colorScheme: colorScheme))
        }
        .onChange(of: editorMode, initial: true) { _, mode in
            switch mode {
            case .adding:
                draftTitle = ""
                draftKind = nil
            case .editing(let id):
                if let field = details.fields.first(where: { $0.id == id }) {
                    draftTitle = field.title
                    draftKind = field.value.kind
                } else {
                    editorMode = nil
                }
            case nil:
                draftTitle = ""
                draftKind = nil
            }
        }
        .confirmationDialog(
            "Delete this field?",
            isPresented: Binding(
                get: { pendingDeletionID != nil },
                set: { if !$0 { pendingDeletionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Field", role: .destructive) {
                guard let id = pendingDeletionID else { return }
                details.fields.removeAll { $0.id == id }
                pendingDeletionID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletionID = nil }
        } message: {
            Text("The field and its value will be removed.")
                .customTextStyle(.body)
        }
    }

    private var builder: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(editorMode == .adding ? "Add a custom field" : "Edit custom field")
                        .customTextStyle(.prominent, color: .inverted)

                    Text(
                        editorMode == .adding
                            ? "Name what you want to save, then choose how you'll enter it."
                            : "Rename this field or choose a new type. Changing its type clears its value."
                    )
                    .customTextStyle(.supporting, color: .muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .modifier(CustomFieldBuilderScrollBlur())

                CustomTextField(
                    title: "Field title",
                    text: $draftTitle,
                    shouldIncludeLineLimit: false,
                    placeholder: "e.g. Account number",
                    leadingSystemImageName: "textformat",
                    autocapitalization: .sentences
                )
                .modifier(CustomFieldBuilderScrollBlur())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Value type")
                        .customTextStyle(.caption, color: .muted)
                        .modifier(CustomFieldBuilderScrollBlur())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CustomFieldKind.allCases) { kind in
                            Button {
                                draftKind = kind
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: kind.icon)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(kind.title)
                                        .customTextStyle(.supportingEmphasis, color: .inverted)
                                    Spacer(minLength: 0)
                                    if draftKind == kind {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                                .padding(.horizontal, 14)
                                .frame(minHeight: RelayFormFieldLayout.controlHeight)
                                .relayRowBackground(cornerRadius: RelayFormFieldLayout.cornerRadius)
                                .overlay {
                                    RoundedRectangle(cornerRadius: RelayFormFieldLayout.cornerRadius)
                                        .strokeBorder(
                                            draftKind == kind ? AppColors.iconBrand(colorScheme: colorScheme) : .clear,
                                            lineWidth: 1.5
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .hapticFeedback(style: .light)
                            .accessibilityAddTraits(draftKind == kind ? .isSelected : [])
                            .modifier(CustomFieldBuilderScrollBlur())
                        }
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .top) {
            HStack(spacing: 18) {
                CircularButton(icon: "xmark") { editorMode = nil }
                    .accessibilityLabel("Cancel")

                Spacer()

                CircularButton(
                    icon: editorMode == .adding ? "plus" : "checkmark",
                    iconColor: canCommit ? nil : AppColors.iconDisabled(colorScheme: colorScheme)
                ) { commitDraft() }
                    .accessibilityLabel(editorMode == .adding ? "Add field" : "Update field")
                    .disabled(!canCommit)
                    .opacity(canCommit ? 1 : 0.45)
            }
            .padding()
        }
    }

    private var canCommit: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draftKind != nil
    }

    private func commitDraft() {
        guard canCommit, let kind = draftKind else { return }
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        switch editorMode {
        case .adding:
            let field = CustomRelayField(title: title, value: .empty(for: kind))
            details.fields.append(field)
            onFieldAdded(field.id)
            editorMode = nil
        case .editing(let id):
            guard let index = details.fields.firstIndex(where: { $0.id == id }) else { return }
            details.fields[index].title = title
            if details.fields[index].value.kind != kind {
                details.fields[index].value = .empty(for: kind)
            }
            editorMode = nil
        case nil:
            return
        }
    }
}

private struct CustomFieldBuilderScrollBlur: ViewModifier {
    func body(content: Content) -> some View {
      
        return content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            view.blur(radius: !phase.isIdentity ? 8 : 0)
        }
    }
}

private extension CustomFieldKind {
    var icon: String {
        switch self {
        case .text: "text.alignleft"
        case .number: "number"
        case .date: "calendar"
        case .gender: "person"
        }
    }
}

private struct CustomFieldRow: View {
    @Binding var field: CustomRelayField
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var textValue: Binding<String> {
        Binding(
            get: {
                switch field.value {
                case .text(let value), .number(let value): value
                default: ""
                }
            },
            set: { newValue in
                switch field.value {
                case .text: field.value = .text(newValue)
                case .number: field.value = .number(newValue)
                default: break
                }
            }
        )
    }

    private var dateValue: Binding<Date?> {
        Binding(
            get: { if case .date(let value) = field.value { value } else { nil } },
            set: { field.value = .date($0) }
        )
    }

    private var genderValue: Binding<PassportSex?> {
        Binding(
            get: { if case .gender(let value) = field.value { value } else { nil } },
            set: { field.value = .gender($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RelayFormFieldLayout.titleSpacing) {
            HStack(spacing: 12) {
                Text(field.title)
                    .customTextStyle(.caption, color: .muted)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Edit \(field.title) field")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Delete \(field.title) field")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
            .buttonStyle(.plain)
            .hapticFeedback(style: .light)
            .disabled(!canEdit)

            switch field.value {
            case .text:
                FormField(
                    field.title,
                    text: textValue,
                    placeholder: "Enter text",
                    icon: CustomFieldKind.text.icon,
                    capitalization: .sentences,
                    showsTitle: false
                )
            case .number:
                FormField(
                    field.title,
                    text: textValue,
                    placeholder: "Enter number",
                    icon: CustomFieldKind.number.icon,
                    keyboard: .numberPad,
                    format: .digitsOnly,
                    showsTitle: false
                )
            case .date:
                FormDateField(field.title, date: dateValue, icon: CustomFieldKind.date.icon, showsTitle: false)
            case .gender:
                FormSexField(field.title, sex: genderValue, showsTitle: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let showsTitle: Bool

    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        capitalization: TextInputAutocapitalization? = nil,
        format: FieldFormat? = nil,
        showsTitle: Bool = true
    ) {
        self.title = title
        _text = text
        self.placeholder = placeholder
        self.icon = icon
        self.keyboard = keyboard
        self.contentType = contentType
        self.capitalization = capitalization
        self.format = format
        self.showsTitle = showsTitle
    }

    var body: some View {
        CustomTextField(
            title: title,
            text: $text,
            showsTitle: showsTitle,
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
    let title: String
    @Binding var sex: PassportSex?
    let showsTitle: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String = "Sex", sex: Binding<PassportSex?>, showsTitle: Bool = true) {
        self.title = title
        _sex = sex
        self.showsTitle = showsTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RelayFormFieldLayout.titleSpacing) {
            if showsTitle {
                Text(title)
                    .customTextStyle(.caption, color: .muted)
            }

            Menu {
                Button {
                    sex = nil
                } label: {
                    if sex == nil {
                        Label("Select", systemImage: "checkmark")
                            .customTextStyle(.body, color: .inverted)
                    } else {
                        Text("Select")
                            .customTextStyle(.body, color: .inverted)
                    }
                }
                .hapticFeedback(style: .light)

                Divider()

                ForEach(PassportSex.allCases) { option in
                    Button {
                        sex = option
                    } label: {
                        if sex == option {
                            Label(option.label, systemImage: "checkmark")
                                .customTextStyle(.body, color: .inverted)
                        } else {
                            Text(option.label)
                                .customTextStyle(.body, color: .inverted)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                        .frame(width: 18)
                        .accessibilityHidden(true)

                    Text(sex?.label ?? "Select")
                        .customTextStyle(.body, color: sex == nil ? .muted : .inverted)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: RelayFormFieldLayout.controlHeight)
                .padding(.horizontal, RelayFormFieldLayout.horizontalPadding)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(sex?.label ?? "Not selected")
            .relayRowBackground(cornerRadius: RelayFormFieldLayout.cornerRadius)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A date that has not been set yet. Rendered as a row that says so, rather than
/// defaulting to today — a passport that quietly claims to have been issued this
/// morning is worse than one that admits the field is empty.
private struct FormDateField: View {
    let title: String
    @Binding var date: Date?
    let icon: String
    let showsTitle: Bool

    @State private var isPicking = false
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, date: Binding<Date?>, icon: String, showsTitle: Bool = true) {
        self.title = title
        _date = date
        self.icon = icon
        self.showsTitle = showsTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RelayFormFieldLayout.titleSpacing) {
            if showsTitle {
                Text(title)
                    .customTextStyle(.caption, color: .muted)
            }

            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring()) { isPicking.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                            .frame(width: 18)

                        Text(date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Select")
                            .customTextStyle(.body, color: date == nil ? .muted : .inverted)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                            .rotationEffect(.degrees(isPicking ? 180 : 0))
                    }
                    .frame(minHeight: RelayFormFieldLayout.controlHeight)
                    .padding(.horizontal, RelayFormFieldLayout.horizontalPadding)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BouncyButtonSecondStyle())
                .hapticFeedback(style: .light)
                .accessibilityLabel(title)
                .accessibilityValue(date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not selected")

                if isPicking {
                    VStack(spacing: 0) {
                        DatePicker(
                            title,
                            selection: Binding { date ?? .now } set: { date = $0 },
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .customTextStyle(.body)
                        .labelsHidden()
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)

                        if date != nil {
                            Button("Clear") {
                                withAnimation(.spring()) {
                                    date = nil
                                    isPicking = false
                                }
                            }
                            .customTextStyle(.footnoteAction, color: .muted)
                            .padding(.bottom, 14)
                            .hapticFeedback(style: .light)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .relayRowBackground(cornerRadius: RelayFormFieldLayout.cornerRadius)
            .clipShape(RoundedRectangle(cornerRadius: RelayFormFieldLayout.cornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Credit card") {
    @Previewable @State var tag = ""
    @Previewable @State var details = RelayItemDetails()
    ScrollView {
        RelayItemForm(type: .creditCard, tag: $tag, details: $details).padding()
    }
    .background(AppColors.background(colorScheme: .light))
}

#Preview("Passport") {
    @Previewable @State var tag = ""
    @Previewable @State var details = RelayItemDetails()
    ScrollView {
        RelayItemForm(type: .passport, tag: $tag, details: $details).padding()
    }
    .background(AppColors.background(colorScheme: .light))
}

#Preview("Address") {
    @Previewable @State var tag = ""
    @Previewable @State var details = RelayItemDetails()
    ScrollView {
        RelayItemForm(type: .address, tag: $tag, details: $details).padding()
    }
    .background(AppColors.background(colorScheme: .light))
}
