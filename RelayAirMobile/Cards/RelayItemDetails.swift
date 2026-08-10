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
//  the item's kind never changes once it is being created, so the unused sections cost
//  three empty structs and buy clean bindings.
//

import Foundation

struct RelayItemDetails: Equatable, Codable {

    
    var tag = ""

    var creditCard = CreditCardDetails()
    var passport = PassportDetails()
    var address = AddressDetails()

    /// Whether the section for this kind has enough to be worth saving. Only the
    /// fields you cannot use the item without — everything else is optional, because
    /// a half-filled card is still better than no card.
    func isComplete(for type: RelayType) -> Bool {
        switch type {
        case .creditCard: creditCard.isComplete
        case .passport:   passport.isComplete
        case .address:    address.isComplete
        }
    }


    func displayTitle(for type: RelayType) -> String {
        let tag = tag.trimmed
        guard tag.isEmpty else { return tag }

        switch type {
        case .creditCard:
            return creditCard.last4.isEmpty ? type.title : "Card •••• \(creditCard.last4)"

        case .passport:
            let name = passport.fullName.trimmed
            return name.isEmpty ? type.title : name

       
        case .address:
            let line = [address.line1, address.city]
                .map(\.trimmed)
                .first { !$0.isEmpty }
            return line ?? type.title
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

// MARK: - Input formatting

/// Applied as the user types. Both of these are formats people already have muscle
/// memory for from the physical card, so the field should meet them there rather than
/// make them match a pattern.
enum FieldFormat {
    case cardNumber
    case expiry

    func apply(to raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(maxDigits))

        switch self {
        case .cardNumber:
            return stride(from: 0, to: digits.count, by: 4)
                .map { start in
                    let lower = digits.index(digits.startIndex, offsetBy: start)
                    let upper = digits.index(lower, offsetBy: min(4, digits.count - start))
                    return String(digits[lower..<upper])
                }
                .joined(separator: " ")

        case .expiry:
            guard digits.count > 2 else { return digits }
            let month = digits.prefix(2)
            let year = digits.dropFirst(2)
            return "\(month)/\(year)"
        }
    }

    private var maxDigits: Int {
        switch self {
        case .cardNumber: 19
        case .expiry:     4
        }
    }
}

// Kept file-scoped: ContentView.swift already declares its own `trimmed`, and an
// internal one here collides with it.
private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
