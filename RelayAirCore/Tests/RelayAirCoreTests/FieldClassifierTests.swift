import Testing
import Foundation
@testable import RelayAirCore

/// What the classifier promises the person choosing a field on their phone.
///
/// The stakes are asymmetric. Mislabelling a text box costs a glance; letting a
/// password box look ordinary costs a password in a log somewhere. So the tests
/// that matter most here are the ones about secrecy and about precedence.
@Suite("Field classification")
struct FieldClassifierTests {

    // MARK: - Secrecy is not a guess

    @Test("A masked field is a password whatever its label says")
    func secureBeatsLabel() {
        let result = FieldClassifier.classify(
            label: "Search",
            role: .textField,
            isSecure: true
        )
        #expect(result.type == .password)
        #expect(result.confidence > 0.9)
    }

    @Test("The secure subrole alone is enough, with no label at all")
    func secureRoleWithoutLabel() {
        let result = FieldClassifier.classify(role: .secureTextField)
        #expect(result.type == .password)
    }

    @Test("A masked field asking for a code is a one-time code, not a password")
    func secureOneTimeCode() {
        for label in ["Verification code", "Enter your 2FA code", "One-time password"] {
            let result = FieldClassifier.classify(label: label, isSecure: true)
            #expect(result.type == .oneTimeCode, "\(label)")
        }
    }

    @Test("An unmasked box labelled Password is still classified, but not as securely")
    func labelSaysPasswordWithoutMasking() {
        let result = FieldClassifier.classify(label: "Password", role: .textField)
        #expect(result.type == .password)
        // Lower than the masked case: the label is evidence, the subrole is fact.
        #expect(result.confidence < 0.9)
    }

    // MARK: - The control's kind wins over its words

    @Test("A checkbox about email is a checkbox, not an email field")
    func checkboxNotEmail() {
        let result = FieldClassifier.classify(label: "Email me special offers", role: .checkBox)
        #expect(result.type == .checkbox)
    }

    @Test("Self-describing kinds are taken at face value")
    func selfDescribingRoles() {
        #expect(FieldClassifier.classify(role: .radioButton).type == .radio)
        #expect(FieldClassifier.classify(role: .popUpButton).type == .select)
        #expect(FieldClassifier.classify(role: .searchField).type == .search)
    }

    // MARK: - Precedence between overlapping words

    @Test("Compound names are settled before the bare name rule can claim them")
    func specificNamesBeatGenericName() {
        #expect(FieldClassifier.classify(label: "First name").type == .firstName)
        #expect(FieldClassifier.classify(label: "Last name").type == .lastName)
        #expect(FieldClassifier.classify(label: "User name").type == .username)
        #expect(FieldClassifier.classify(label: "Company name").type == .company)
        // Only a bare "name" falls through to the weak rule.
        #expect(FieldClassifier.classify(label: "Name").type == .fullName)
    }

    @Test("Username is not mistaken for a person's name")
    func usernameIsNotAName() {
        for label in ["Username", "username", "user_id", "Login"] {
            #expect(FieldClassifier.classify(label: label).type == .username, "\(label)")
        }
    }

    // MARK: - The many spellings of one idea

    @Test("Case, separators and run-together spellings all land in the same place")
    func normalizationVariants() {
        let spellings = ["First name", "first_name", "firstName", "FIRST NAME", "firstname", "First Name:"]
        for spelling in spellings {
            #expect(FieldClassifier.classify(label: spelling).type == .firstName, "\(spelling)")
        }
    }

    @Test("A developer id counts as evidence when there's no visible label")
    func identifierIsUsed() {
        let result = FieldClassifier.classify(identifier: "billing_postal_code", role: .textField)
        #expect(result.type == .zip)
    }

    @Test("A placeholder counts when the design has dropped labels")
    func placeholderIsUsed() {
        let result = FieldClassifier.classify(placeholder: "you@example.com", role: .textField)
        #expect(result.type == .email)
    }

    // MARK: - Common form vocabulary

    @Test("Everyday labels reach the type a person would expect")
    func commonLabels() {
        let cases: [(String, SemanticFieldType)] = [
            ("Email address", .email),
            ("E-mail", .email),
            ("Phone number", .phone),
            ("Mobile", .phone),
            ("Street address", .address),
            ("City", .city),
            ("Postcode", .zip),
            ("ZIP", .zip),
            ("Country", .country),
            ("Website", .url),
            ("Date of birth", .date),
            ("Search", .search)
        ]
        for (label, expected) in cases {
            #expect(FieldClassifier.classify(label: label).type == expected, "\(label)")
        }
    }

    // MARK: - Honest ignorance

    @Test("An unreadable text box says so instead of guessing")
    func unlabelledTextField() {
        let result = FieldClassifier.classify(role: .textField)
        #expect(result.type == .unknown)
        #expect(result.confidence < 0.5, "An unlabelled box should not look confident")
    }

    @Test("A text area with nothing to read falls back to its kind")
    func unlabelledTextArea() {
        #expect(FieldClassifier.classify(role: .textArea).type == .textarea)
    }

    @Test("Reading a real label is more confident than falling back to a kind")
    func confidenceOrdering() {
        let read = FieldClassifier.classify(label: "Email address", role: .textField)
        let guessed = FieldClassifier.classify(role: .textField)
        #expect(read.confidence > guessed.confidence)
    }

    @Test("Password and one-time code are the two that get special handling")
    func sensitivity() {
        #expect(SemanticFieldType.password.isSensitive)
        #expect(SemanticFieldType.oneTimeCode.isSensitive)
        #expect(!SemanticFieldType.email.isSensitive)
        #expect(!SemanticFieldType.unknown.isSensitive)
    }
}
