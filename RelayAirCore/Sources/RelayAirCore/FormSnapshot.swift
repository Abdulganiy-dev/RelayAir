import Foundation

/// Where a field description came from.
///
/// The Mac can learn about a field in more than one way, and the routes differ
/// in how much they can be trusted. Carrying the route to the phone lets it say
/// so, rather than presenting a guess and a certainty identically.
public enum FieldSource: String, Codable, Sendable {
    /// Read from the app's Accessibility tree. Works everywhere, and is the only
    /// route that can state for certain that a field is secure.
    case accessibility
    /// Read from a page's DOM by a browser extension. Not built yet.
    case dom
    /// Inferred from pixels. Cannot tell a password box from a text box, so
    /// anything from here is a suggestion.
    case vision
}

/// What a field is *for*, as far as the Mac can tell.
///
/// Mirrors the categories the browser extension's classifier produces, so the
/// phone renders one vocabulary no matter which route found the field.
public enum SemanticFieldType: String, Codable, Sendable, CaseIterable {
    case email
    case phone
    case firstName = "first_name"
    case lastName = "last_name"
    case fullName = "full_name"
    case address
    case city
    case state
    case zip
    case country
    case password
    case oneTimeCode = "one_time_code"
    case username
    case company
    case checkbox
    case radio
    case select
    case textarea
    case number
    case date
    case url
    case search
    case unknown

    /// Whether filling this by mistake is expensive.
    public var isSensitive: Bool {
        switch self {
        case .password, .oneTimeCode: true
        default: false
        }
    }

    public var displayName: String {
        switch self {
        case .email: "Email"
        case .phone: "Phone"
        case .firstName: "First name"
        case .lastName: "Last name"
        case .fullName: "Full name"
        case .address: "Address"
        case .city: "City"
        case .state: "State"
        case .zip: "Postcode"
        case .country: "Country"
        case .password: "Password"
        case .oneTimeCode: "One-time code"
        case .username: "Username"
        case .company: "Company"
        case .checkbox: "Checkbox"
        case .radio: "Option"
        case .select: "Menu"
        case .textarea: "Text area"
        case .number: "Number"
        case .date: "Date"
        case .url: "Web address"
        case .search: "Search"
        case .unknown: "Text"
        }
    }

    /// SF Symbol for the phone's field list.
    public var symbolName: String {
        switch self {
        case .email: "envelope"
        case .phone: "phone"
        case .firstName, .lastName, .fullName: "person"
        case .address, .city, .state, .country: "mappin.and.ellipse"
        case .zip: "number"
        case .password: "lock"
        case .oneTimeCode: "number.square"
        case .username: "at"
        case .company: "building.2"
        case .checkbox: "checkmark.square"
        case .radio: "largecircle.fill.circle"
        case .select: "chevron.up.chevron.down"
        case .textarea: "text.alignleft"
        case .number: "numbersign"
        case .date: "calendar"
        case .url: "link"
        case .search: "magnifyingglass"
        case .unknown: "character.cursor.ibeam"
        }
    }
}

/// A field's position on screen, in points, origin top-left.
///
/// Screen coordinates rather than window-relative ones, so the Mac can hand
/// them straight to the cursor without reconciling scroll or window position.
public struct FieldFrame: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }
}

/// One fillable control the Mac found.
///
/// Deliberately carries no field *contents*. The phone needs to know what a box
/// is asking for so a person can choose it, not what somebody already typed in
/// it — see ``hasExistingValue`` for the one bit of that which is useful.
public struct FormField: Codable, Hashable, Sendable, Identifiable {
    /// Handle for asking the Mac to focus this field. Only meaningful to the
    /// snapshot it came from — a later snapshot renumbers everything.
    public var id: String

    /// Best human-readable name: the associated label, falling back through
    /// description, placeholder, and finally the control's kind.
    public var label: String

    /// What the field appears to be for.
    public var semanticType: SemanticFieldType

    /// How sure ``semanticType`` is, 0…1. Low values mean "we found a text box
    /// and couldn't tell you more than that".
    public var confidence: Double

    /// The underlying control kind — an AX role today, a DOM tag later. Kept raw
    /// for diagnosis; the phone should show ``semanticType`` instead.
    public var role: String

    /// The field masks what's typed into it. From `AXSecureTextField`, which is
    /// authoritative — this is not inferred from the label.
    public var isSecure: Bool

    /// The form marks this field as required.
    public var isRequired: Bool

    /// The field can currently accept input.
    public var isEnabled: Bool

    /// The field already has something in it, so filling would append to or
    /// replace existing content. The content itself is never read.
    public var hasExistingValue: Bool

    /// Placeholder text, when the control has any.
    public var placeholder: String?

    /// Where the field is on screen, when it could be determined.
    public var frame: FieldFrame?

    /// Choices, for menus and comboboxes.
    public var options: [String]?

    public init(
        id: String,
        label: String,
        semanticType: SemanticFieldType,
        confidence: Double,
        role: String,
        isSecure: Bool = false,
        isRequired: Bool = false,
        isEnabled: Bool = true,
        hasExistingValue: Bool = false,
        placeholder: String? = nil,
        frame: FieldFrame? = nil,
        options: [String]? = nil
    ) {
        self.id = id
        self.label = label
        self.semanticType = semanticType
        self.confidence = confidence
        self.role = role
        self.isSecure = isSecure
        self.isRequired = isRequired
        self.isEnabled = isEnabled
        self.hasExistingValue = hasExistingValue
        self.placeholder = placeholder
        self.frame = frame
        self.options = options
    }
}

/// Everything the Mac could work out about the form in front of the user.
public struct FormSnapshot: Codable, Hashable, Sendable {
    public var fields: [FormField]

    /// Which route produced this.
    public var source: FieldSource

    /// The app the fields belong to — "Safari", "Mail", "Slack".
    public var appName: String?

    /// Title of the window they were found in.
    public var windowTitle: String?

    /// Address of the page, when the window was a browser the Mac can ask.
    /// Lets the phone show where a password is about to go.
    public var url: String?

    public var capturedAt: Date

    public init(
        fields: [FormField],
        source: FieldSource,
        appName: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        capturedAt: Date
    ) {
        self.fields = fields
        self.source = source
        self.appName = appName
        self.windowTitle = windowTitle
        self.url = url
        self.capturedAt = capturedAt
    }

    public var isEmpty: Bool { fields.isEmpty }

    /// Where the fields are, in the user's terms — "Safari — Sign in".
    public var contextDescription: String {
        switch (appName, windowTitle) {
        case let (app?, title?) where !title.isEmpty: "\(app) — \(title)"
        case let (app?, _): app
        case let (_, title?): title
        default: "Unknown window"
        }
    }
}
