import Foundation

/// The kind of control a field is, independent of how it was found.
///
/// A small shared vocabulary so the Accessibility route and any later route can
/// feed the same classifier: `AXTextArea` and `<textarea>` both arrive here as
/// ``textArea``.
public enum ControlRole: String, Codable, Sendable {
    case textField
    case secureTextField
    case textArea
    case comboBox
    case popUpButton
    case checkBox
    case radioButton
    case searchField
    case unknown

    /// Whether the control's kind alone settles what it is, no reading required.
    var isSelfDescribing: Bool {
        switch self {
        case .checkBox, .radioButton, .popUpButton, .searchField, .secureTextField: true
        case .textField, .textArea, .comboBox, .unknown: false
        }
    }
}

/// Works out what a field is asking for, from its label and its kind.
///
/// Rule-based on purpose. The phone shows this to a person who then picks a
/// field themselves, so a wrong guess costs a glance rather than a wrong fill —
/// which is the wrong trade for a model, and the right one for a keyword table.
///
/// One signal here is not a guess: ``Result/type`` is `.password` whenever the
/// control reports itself secure, because the system told us so.
public enum FieldClassifier {

    public struct Result: Hashable, Sendable {
        public var type: SemanticFieldType
        /// 0…1. Below ~0.5 means "a text box, and little more than that".
        public var confidence: Double

        public init(type: SemanticFieldType, confidence: Double) {
            self.type = type
            self.confidence = confidence
        }
    }

    /// Classifies one field.
    ///
    /// - Parameters:
    ///   - label: The field's accessible name, if it has one.
    ///   - placeholder: Placeholder text, which often carries the real hint when
    ///     a design has dropped visible labels.
    ///   - identifier: A developer-facing id — a DOM `id`, an AX identifier.
    ///     Frequently the most honest description of the three.
    ///   - role: What kind of control it is.
    ///   - isSecure: The control masks its contents. Authoritative.
    public static func classify(
        label: String? = nil,
        placeholder: String? = nil,
        identifier: String? = nil,
        role: ControlRole = .unknown,
        isSecure: Bool = false
    ) -> Result {
        let haystack = normalize([label, placeholder, identifier])

        // A masked field is a password unless it's plainly asking for a code.
        // Both are sensitive, so a mix-up here is cosmetic rather than dangerous.
        if isSecure || role == .secureTextField {
            if matches(haystack, Self.oneTimeCodeKeywords) {
                return Result(type: .oneTimeCode, confidence: 0.9)
            }
            return Result(type: .password, confidence: 0.98)
        }

        // Kinds that describe themselves. Checking these before the keyword table
        // stops a checkbox labelled "Email me offers" being read as an email box.
        switch role {
        case .checkBox: return Result(type: .checkbox, confidence: 0.95)
        case .radioButton: return Result(type: .radio, confidence: 0.95)
        case .popUpButton: return Result(type: .select, confidence: 0.95)
        case .searchField: return Result(type: .search, confidence: 0.95)
        default: break
        }

        for rule in Self.rules where matches(haystack, rule.keywords) {
            return Result(type: rule.type, confidence: rule.confidence)
        }

        // A sample address for a placeholder is a strong hint carrying no word
        // we'd otherwise recognise. Checked after the rules so an explicit
        // "Username" label still wins on a login box that accepts either.
        if let placeholder, placeholder.contains("@"), placeholder.contains(".") {
            return Result(type: .email, confidence: 0.8)
        }

        // Nothing readable. Fall back to whatever the kind implies.
        switch role {
        case .textArea: return Result(type: .textarea, confidence: 0.7)
        case .comboBox: return Result(type: .select, confidence: 0.6)
        case .textField: return Result(type: .unknown, confidence: 0.2)
        default: return Result(type: .unknown, confidence: 0.15)
        }
    }

    // MARK: - Rules

    private struct Rule {
        var type: SemanticFieldType
        var keywords: [String]
        var confidence: Double
    }

    private static let oneTimeCodeKeywords = [
        "one time code", "one time password", "otp", "verification code",
        "confirmation code", "security code", "authentication code", "auth code",
        "2fa", "two factor", "passcode", "digit code", "sms code"
    ]

    /// Order is the whole design: the specific beats the generic, so "user name"
    /// is settled before the bare "name" rule can claim it.
    private static let rules: [Rule] = [
        Rule(type: .oneTimeCode, keywords: oneTimeCodeKeywords, confidence: 0.9),

        Rule(type: .email, keywords: ["email", "e mail"], confidence: 0.95),

        Rule(type: .username, keywords: [
            "username", "user name", "user id", "userid", "login", "log in",
            "screen name", "handle", "account name"
        ], confidence: 0.9),

        Rule(type: .password, keywords: [
            "password", "pass word", "passphrase", "pwd"
        ], confidence: 0.85),

        Rule(type: .firstName, keywords: [
            "first name", "given name", "forename", "fname"
        ], confidence: 0.92),

        Rule(type: .lastName, keywords: [
            "last name", "surname", "family name", "lname"
        ], confidence: 0.92),

        Rule(type: .fullName, keywords: [
            "full name", "your name", "name on card", "cardholder", "display name"
        ], confidence: 0.85),

        Rule(type: .phone, keywords: [
            "phone", "mobile", "telephone", "tel", "cell", "contact number"
        ], confidence: 0.9),

        Rule(type: .zip, keywords: [
            "zip", "zipcode", "postal code", "postcode", "post code"
        ], confidence: 0.92),

        Rule(type: .city, keywords: ["city", "town", "suburb"], confidence: 0.9),

        Rule(type: .state, keywords: [
            "state", "province", "county", "region"
        ], confidence: 0.85),

        Rule(type: .country, keywords: ["country", "nation"], confidence: 0.9),

        Rule(type: .address, keywords: [
            "address", "street", "apartment", "apt", "suite", "building",
            "address line"
        ], confidence: 0.88),

        Rule(type: .company, keywords: [
            "company", "organisation", "organization", "employer", "business",
            "workplace"
        ], confidence: 0.88),

        Rule(type: .url, keywords: [
            "url", "website", "web site", "homepage", "link", "web address"
        ], confidence: 0.88),

        Rule(type: .date, keywords: [
            "date", "birthday", "birth date", "dob", "expiry", "expiration",
            "valid until"
        ], confidence: 0.85),

        Rule(type: .search, keywords: ["search", "find", "query"], confidence: 0.85),

        Rule(type: .number, keywords: [
            "number", "amount", "quantity", "qty", "count", "age"
        ], confidence: 0.7),

        // Last, and weak on purpose: by here every compound "… name" is spoken for.
        Rule(type: .fullName, keywords: ["name"], confidence: 0.55)
    ]

    // MARK: - Matching

    /// Lowercases, splits camelCase, and turns punctuation into spaces, so
    /// `"firstName"`, `"first_name"` and `"First Name:"` all end up the same.
    ///
    /// Only a lowercase *letter* opens a camelCase boundary. Counting digits too
    /// would split "2FA" into "2 fa" and lose it.
    private static func normalize(_ parts: [String?]) -> String {
        var out = ""
        for part in parts.compactMap({ $0 }) where !part.isEmpty {
            var previousWasLower = false
            for character in part {
                if character.isUppercase, previousWasLower { out.append(" ") }
                if character.isLetter || character.isNumber {
                    out.append(Character(character.lowercased()))
                } else {
                    out.append(" ")
                }
                previousWasLower = character.isLowercase
            }
            out.append(" ")
        }
        // Pad so callers can test whole words with a plain `contains`.
        return " " + out.split(separator: " ").joined(separator: " ") + " "
    }

    /// Whole-word match, plus a run-together form for multi-word keywords so
    /// `"firstname"` still finds the `"first name"` rule.
    private static func matches(_ haystack: String, _ keywords: [String]) -> Bool {
        for keyword in keywords {
            if haystack.contains(" \(keyword) ") { return true }
            if keyword.contains(" ") {
                let compact = keyword.replacingOccurrences(of: " ", with: "")
                if haystack.contains(" \(compact) ") { return true }
            }
        }
        return false
    }
}
