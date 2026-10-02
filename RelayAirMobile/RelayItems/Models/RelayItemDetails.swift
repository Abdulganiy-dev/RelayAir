//
//  RelayItemDetails.swift
//  RelayAirMobile
//
//  The data behind a relay item — what actually gets sent to the Mac. Separate from
//  `CardContent`, which is only what the card *looks* like: a user can put "Amex" on
//  the front and still have the real number stored here.
//
//  One container holds a section per kind rather than an enum with associated values.
//  An enum would need a computed binding per case to reach `$details.creditCard`, and
//  the item's kind never changes once it is being created, so the unused sections buy
//  clean bindings without putting private details on the visible item row.
//

import Foundation

struct RelayItemDetails: Equatable, Codable {
    var creditCard = CreditCardDetails()
    var passport = PassportDetails()
    var address = AddressDetails()
    var custom: CustomRelayDetails?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case creditCard
        case passport
        case address
        case custom
    }

    /// Allows the database migration's `{}` default to decode as an empty item while
    /// retaining normal decoding for records that already contain relay details.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creditCard = try container.decodeIfPresent(CreditCardDetails.self, forKey: .creditCard)
            ?? CreditCardDetails()
        passport = try container.decodeIfPresent(PassportDetails.self, forKey: .passport)
            ?? PassportDetails()
        address = try container.decodeIfPresent(AddressDetails.self, forKey: .address)
            ?? AddressDetails()
        custom = try container.decodeIfPresent(CustomRelayDetails.self, forKey: .custom)
    }

    /// Whether the section for this kind has enough to be worth saving. Only the
    /// fields you cannot use the item without — everything else is optional, because
    /// a half-filled card is still better than no card.
    func isComplete(for type: RelayType) -> Bool {
        switch type {
        case .creditCard: creditCard.isComplete
        case .passport:   passport.isComplete
        case .address:    address.isComplete
        case .custom:     custom?.isComplete == true
        }
    }


    /// The hint shown under an item's tag in a list. This is copied onto the row so the
    /// wallet can render without decoding the rest of the details.
    func subtitle(for type: RelayType) -> String {
        switch type {
        case .creditCard:
            let last4 = creditCard.last4
            return last4.isEmpty ? "" : "•••• \(last4)"

        case .passport:
            return passport.nationality.trimmed

        case .address:
            return address.city.trimmed

        case .custom:
            return ""
        }
    }
}

// MARK: - Credit card

struct CreditCardDetails: Equatable, Codable {
    var number = ""
    var holder = ""
    var expiry = ""
    var securityCode = ""

    var digits: String { number.filter(\.isNumber) }

    var last4: String { String(digits.suffix(4)) }

    /// Most networks land between 13 and 19 digits, so the range is the check rather
    /// than a single length.
    var isComplete: Bool {
        (13...19).contains(digits.count)
            && !holder.trimmed.isEmpty
            && expiry.filter(\.isNumber).count == 4
    }
}

// MARK: - Passport

enum PassportSex: String, CaseIterable, Codable, Identifiable {
    case female = "F"
    case male = "M"
    case unspecified = "X"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .unspecified: "Unspecified"
        }
    }
}

struct PassportDetails: Equatable, Codable {
    var fullName = ""
    var sex: PassportSex?
    var dateOfBirth: Date?
    var placeOfBirth = ""
    var number = ""
    var nationality = ""
    var passportType = ""
    var issuingAuthority = ""
    var personalNumber = ""
    var issued: Date?
    var expires: Date?

    var isComplete: Bool {
        !fullName.trimmed.isEmpty
            && !number.trimmed.isEmpty
            && !nationality.trimmed.isEmpty
            && dateOfBirth != nil
            && expires != nil
    }
}

// MARK: - Address

struct AddressDetails: Equatable, Codable {
    var line1 = ""
    var line2 = ""
    var city = ""
    var region = ""
    var postcode = ""
    var country = ""

    var isComplete: Bool {
        !line1.trimmed.isEmpty && !city.trimmed.isEmpty && !postcode.trimmed.isEmpty
    }

    /// Single-line form, for relaying into a field that wants the whole thing.
    var oneLine: String {
        [line1, line2, city, region, postcode, country]
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Custom

enum CustomFieldKind: String, CaseIterable, Codable, Identifiable {
    case text
    case number
    case date
    case gender

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum CustomFieldValue: Equatable, Codable {
    case text(String)
    case number(String)
    case date(Date?)
    case gender(PassportSex?)

    var kind: CustomFieldKind {
        switch self {
        case .text: .text
        case .number: .number
        case .date: .date
        case .gender: .gender
        }
    }

    var isComplete: Bool {
        switch self {
        case .text(let value): !value.trimmed.isEmpty
        case .number(let value): !value.isEmpty && value.allSatisfy { $0 >= "0" && $0 <= "9" }
        case .date(let value): value != nil
        case .gender(let value): value != nil
        }
    }

    static func empty(for kind: CustomFieldKind) -> Self {
        switch kind {
        case .text: .text("")
        case .number: .number("")
        case .date: .date(nil)
        case .gender: .gender(nil)
        }
    }
}

struct CustomRelayField: Equatable, Codable, Identifiable {
    let id: UUID
    var title: String
    var value: CustomFieldValue

    init(id: UUID = UUID(), title: String, value: CustomFieldValue) {
        self.id = id
        self.title = title
        self.value = value
    }
}

struct CustomRelayDetails: Equatable, Codable {
    var fields: [CustomRelayField] = []

    var isComplete: Bool { !fields.isEmpty && fields.allSatisfy { $0.value.isComplete } }

    private enum CodingKeys: String, CodingKey {
        case fields
        case value
    }

    init(fields: [CustomRelayField] = []) {
        self.fields = fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let fields = try container.decodeIfPresent([CustomRelayField].self, forKey: .fields) {
            self.fields = fields
        } else if let legacyValue = try container.decodeIfPresent(String.self, forKey: .value) {
            self.fields = [CustomRelayField(title: "Details", value: .text(legacyValue))]
        } else {
            self.fields = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fields, forKey: .fields)
    }
}

// MARK: - Input formatting

/// Applied as the user types. Both of these are formats people already have muscle
/// memory for from the physical card, so the field should meet them there rather than
/// make them match a pattern.
enum FieldFormat {
    case cardNumber
    case expiry
    case digitsOnly

    func apply(to raw: String) -> String {
        let digits = String(raw.filter(\.isNumber))

        switch self {
        case .cardNumber:
            let digits = String(digits.prefix(19))
            return stride(from: 0, to: digits.count, by: 4)
                .map { start in
                    let lower = digits.index(digits.startIndex, offsetBy: start)
                    let upper = digits.index(lower, offsetBy: min(4, digits.count - start))
                    return String(digits[lower..<upper])
                }
                .joined(separator: " ")

        case .expiry:
            let digits = String(digits.prefix(4))
            guard digits.count > 2 else { return digits }
            let month = digits.prefix(2)
            let year = digits.dropFirst(2)
            return "\(month)/\(year)"
        case .digitsOnly:
            return String(raw.filter { $0 >= "0" && $0 <= "9" })
        }
    }
}

// Kept file-scoped: ContentView.swift already declares its own `trimmed`, and an
// internal one here collides with it.
private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
