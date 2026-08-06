import AppKit
import ApplicationServices
import OSLog
import RelayAirCore

/// Reads the fillable fields in front of the user out of the Accessibility tree.
///
/// This is the Mac's first and broadest route to knowing what a form is asking
/// for. It needs no cooperation from the app being read, so it works the same in
/// Safari, Mail, Slack and a native login sheet — anywhere with a reasonable
/// Accessibility implementation.
///
/// Two things it deliberately does not do:
///
/// - **Read values.** Field contents are never copied. ``FormField/hasExistingValue``
///   records only whether a box was empty, which is what the phone needs to warn
///   that a fill would land on top of something.
/// - **Guess at secrecy.** ``FormField/isSecure`` comes from the
///   `AXSecureTextField` subrole, which the system sets. It is not inferred from
///   a label, so a box called "Password" that isn't actually masked won't claim
///   to be.
///
/// ### Element handles
///
/// `AXUIElement` references can't travel over the wire, so each snapshot mints
/// short string ids and keeps the mapping here. Ids mean nothing outside the
/// snapshot that produced them: taking a new snapshot invalidates the old ones,
/// and ``focus(fieldID:)`` refuses anything it doesn't recognise.
///
/// The traversal itself lives in ``AXFieldWalker``, off the main actor.
@MainActor
final class AccessibilityFieldInspector {

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Fields")

    /// Handles from the most recent snapshot, and the app they belong to.
    private var handles: [String: AXUIElement] = [:]
    private var snapshotPID: pid_t?

    // MARK: - Snapshot

    /// Describes the fields in the frontmost window.
    ///
    /// Never throws and never fails: an app the Mac can't read produces an empty
    /// snapshot, which is a real answer rather than an error. The phone shows
    /// "no fields found here" and the user can still fill by focus as before.
    func snapshot() async -> FormSnapshot {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return FormSnapshot(fields: [], source: .accessibility, capturedAt: Date())
        }

        let pid = app.processIdentifier
        let appName = app.localizedName
        let bundleID = app.bundleIdentifier

        // Off the main actor: these are cross-process calls and some apps are
        // slow to answer. Blocking the menu bar while Slack thinks is not worth
        // the simpler code.
        let walk = await Task.detached(priority: .userInitiated) {
            AXFieldWalker.walk(pid: pid)
        }.value

        // A browser can tell us the page directly, which is worth more to the
        // person approving a password than the window title is.
        let page = await BrowserContext.page(bundleID: bundleID, windowTitle: walk.windowTitle)

        handles = walk.handles
        snapshotPID = pid

        logger.notice(
            """
            Found \(walk.fields.count, privacy: .public) fields in \
            \(appName ?? "unknown", privacy: .public)\
            \(walk.truncated ? " (walk truncated)" : "", privacy: .public)
            """
        )

        return FormSnapshot(
            fields: walk.fields,
            source: .accessibility,
            appName: appName,
            windowTitle: page?.title ?? walk.windowTitle,
            url: page?.url,
            capturedAt: Date()
        )
    }

    // MARK: - Focus

    /// Puts keyboard focus on a field from the last snapshot.
    ///
    /// Refuses when the id is unknown, when the user has switched apps since the
    /// snapshot was taken, or when focus doesn't land where it was asked to. All
    /// three mean the same thing in practice — the screen is no longer what the
    /// phone is showing — and typing anyway would put text somewhere nobody
    /// chose.
    func focus(fieldID: String) async -> Bool {
        guard let element = handles[fieldID] else {
            logger.error("Unknown field id; the snapshot is stale")
            return false
        }

        guard let expected = snapshotPID,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == expected else {
            logger.error("Frontmost app changed since the snapshot; refusing to focus")
            return false
        }

        let result = AXUIElementSetAttributeValue(
            element,
            AXFieldWalker.Attribute.focused as CFString,
            kCFBooleanTrue
        )
        guard result == .success else {
            logger.error("Focusing field failed: AXError \(result.rawValue, privacy: .public)")
            return false
        }

        // Setting the attribute can report success without focus having moved
        // yet — a web view routes it through the page, which takes a turn of the
        // event loop. Poll briefly rather than accept the request at face value:
        // typing a password into the wrong box is the failure worth avoiding.
        let app = AXUIElementCreateApplication(expected)
        for attempt in 0..<Self.focusConfirmationAttempts {
            if let focused = AXFieldWalker.copy(app, AXFieldWalker.Attribute.focusedUIElement),
               CFEqual(focused, element) {
                return true
            }
            if attempt < Self.focusConfirmationAttempts - 1 {
                try? await Task.sleep(for: Self.focusConfirmationInterval)
            }
        }

        logger.error("Focus did not land on the requested field")
        return false
    }

    /// How long to give focus to settle before giving up. Generous enough for a
    /// web view, short enough that a genuine failure is still prompt.
    private static let focusConfirmationAttempts = 6
    private static let focusConfirmationInterval: Duration = .milliseconds(40)

    /// Drops the handles from the last snapshot.
    func invalidate() {
        handles.removeAll()
        snapshotPID = nil
    }
}

// MARK: - The traversal

/// Walks an app's Accessibility tree and pulls out the fillable controls.
///
/// Marked `nonisolated` as a whole: the target defaults to main-actor isolation,
/// and this runs on a background task because every attribute read is a
/// synchronous call into another process.
nonisolated enum AXFieldWalker {

    /// Bounds on one traversal.
    ///
    /// An unbounded walk of something like a full Gmail window takes seconds, so
    /// the walk stops at whichever of these it reaches first and returns what it
    /// has. A short list beats a long wait: the user is looking at the screen and
    /// can always ask again.
    enum Limits {
        static let maxElements = 6000
        static let maxDepth = 60
        static let maxFields = 80
        /// Per-message timeout for a single AX call.
        static let messageTimeout: Float = 0.4
        /// Wall-clock budget for the whole walk.
        static let walkBudget: Duration = .milliseconds(1500)
    }

    /// What one traversal produced. `AXUIElement` is a thread-safe CF type but
    /// isn't marked `Sendable`, hence the unchecked conformance.
    struct WalkResult: @unchecked Sendable {
        var fields: [FormField] = []
        var handles: [String: AXUIElement] = [:]
        var windowTitle: String?
        /// A limit was hit, so the list may be short.
        var truncated = false
    }

    static func walk(pid: pid_t) -> WalkResult {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Limits.messageTimeout)

        guard let window = focusedWindow(of: app) else { return WalkResult() }
        
        var result = WalkResult()
        result.windowTitle = string(window, Attribute.title)

        var visited = 0
        let deadline = ContinuousClock.now + Limits.walkBudget

        // Breadth-first, so a wide window yields its top-level fields before the
        // budget runs out on some deeply nested sidebar.
        var queue: [(element: AXUIElement, depth: Int)] = [(window, 0)]
        var head = 0

        while head < queue.count {
            guard visited < Limits.maxElements,
                  result.fields.count < Limits.maxFields,
                  ContinuousClock.now < deadline
            else {
                result.truncated = true
                break
            }

            let (element, depth) = queue[head]
            head += 1
            visited += 1

            if let field = describe(element, index: result.fields.count) {
                result.handles[field.id] = element
                result.fields.append(field)
                // A field's own children are its text content, not more fields.
                continue
            }

            guard depth < Limits.maxDepth else { continue }
            for child in children(of: element) {
                queue.append((child, depth + 1))
            }
        }

        return result
    }

    private static func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        if let focused = copy(app, Attribute.focusedWindow) {
            return (focused as! AXUIElement)
        }
        if let main = copy(app, Attribute.mainWindow) {
            return (main as! AXUIElement)
        }
        // Some apps expose neither until they've been interacted with.
        if let windows = copy(app, Attribute.windows) as? [AXUIElement] {
            return windows.first
        }
        return nil
    }

    // MARK: - Describing one element

    /// Turns an element into a ``FormField``, or `nil` if it isn't one.
    private static func describe(_ element: AXUIElement, index: Int) -> FormField? {
        guard let rawRole = string(element, Attribute.role) else { return nil }
        let subrole = string(element, Attribute.subrole)

        guard let role = controlRole(axRole: rawRole, subrole: subrole) else { return nil }

        // Hidden and collapsed subtrees report a zero frame. They aren't
        // fillable, and offering them would send the user chasing a box that
        // isn't on screen.
        let frame = frame(of: element)
        if let frame, frame.width <= 1 || frame.height <= 1 { return nil }

        let isSecure = role == .secureTextField
        let placeholder = string(element, Attribute.placeholderValue)
        let identifier = string(element, Attribute.domIdentifier)
            ?? string(element, Attribute.identifier)

        let label = accessibleName(element)
        let classification = FieldClassifier.classify(
            label: label,
            placeholder: placeholder,
            identifier: identifier,
            role: role,
            isSecure: isSecure
        )

        return FormField(
            id: "ax-\(index)",
            label: label ?? placeholder ?? classification.type.displayName,
            semanticType: classification.type,
            confidence: classification.confidence,
            role: rawRole,
            isSecure: isSecure,
            isRequired: bool(element, Attribute.required) ?? false,
            isEnabled: bool(element, Attribute.enabled) ?? true,
            hasExistingValue: hasContent(element, isSecure: isSecure),
            placeholder: placeholder,
            frame: frame,
            options: options(of: element, role: role)
        )
    }

    /// Whether the field already has something in it.
    ///
    /// Presence only — the value is tested and dropped, never retained or sent.
    private static func hasContent(_ element: AXUIElement, isSecure: Bool) -> Bool {
        // The system refuses to hand over a secure field's value anyway. Don't ask.
        guard !isSecure, let value = string(element, Attribute.value) else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The best human-readable name, in the order a screen reader would use.
    ///
    /// `AXTitleUIElement` comes first because it's the tree's own answer to
    /// "which label belongs to this box" — a real association rather than the
    /// nearest-text guessing a DOM scraper has to do.
    private static func accessibleName(_ element: AXUIElement) -> String? {
        if let labelElement = copy(element, Attribute.titleUIElement) {
            let label = labelElement as! AXUIElement
            if let text = string(label, Attribute.value) ?? string(label, Attribute.title),
               !text.isEmpty {
                return clean(text)
            }
        }
        for attribute in [Attribute.title, Attribute.description, Attribute.help] {
            if let text = string(element, attribute), !text.isEmpty { return clean(text) }
        }
        return nil
    }

    /// Trims the punctuation labels usually carry — "Email address:" → "Email address".
    private static func clean(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":*"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func options(of element: AXUIElement, role: ControlRole) -> [String]? {
        guard role == .popUpButton || role == .comboBox else { return nil }
        guard let children = copy(element, Attribute.children) as? [AXUIElement] else { return nil }
        let titles = children.compactMap { string($0, Attribute.title) }
        return titles.isEmpty ? nil : titles
    }

    private static func frame(of element: AXUIElement) -> FieldFrame? {
        guard let positionValue = copy(element, Attribute.position),
              let sizeValue = copy(element, Attribute.size)
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }

        // AX reports screen coordinates with the origin at the top-left of the
        // main display — the same convention `CGEvent` mouse positions use, so
        // these can drive the cursor without conversion.
        return FieldFrame(x: point.x, y: point.y, width: size.width, height: size.height)
    }

    /// Maps an AX role and subrole onto the shared vocabulary, or `nil` when the
    /// element isn't something a person can type into.
    ///
    /// Subrole is checked first because it's the more specific of the two: a
    /// password box is `AXTextField` with subrole `AXSecureTextField`, and only
    /// the subrole distinguishes it from an ordinary one.
    private static func controlRole(axRole: String, subrole: String?) -> ControlRole? {
        switch subrole {
        case "AXSecureTextField": return .secureTextField
        case "AXSearchField": return .searchField
        default: break
        }

        switch axRole {
        case "AXTextField": return .textField
        case "AXSecureTextField": return .secureTextField
        case "AXTextArea": return .textArea
        case "AXComboBox": return .comboBox
        case "AXPopUpButton": return .popUpButton
        case "AXCheckBox": return .checkBox
        case "AXRadioButton": return .radioButton
        default: return nil
        }
    }

    // MARK: - Attribute plumbing

    /// Attribute names as literals rather than the `kAX…` constants, so a
    /// constant that isn't exported on a given SDK can't break the build. The
    /// last two aren't in the public list at all: `AXRequired` is what AppKit and
    /// WebKit both publish for a required control, and `AXDOMIdentifier` is how
    /// WebKit and Chromium expose an element's `id`.
    enum Attribute {
        static let role = "AXRole"
        static let subrole = "AXSubrole"
        static let title = "AXTitle"
        static let description = "AXDescription"
        static let help = "AXHelp"
        static let value = "AXValue"
        static let placeholderValue = "AXPlaceholderValue"
        static let enabled = "AXEnabled"
        static let focused = "AXFocused"
        static let focusedWindow = "AXFocusedWindow"
        static let focusedUIElement = "AXFocusedUIElement"
        static let mainWindow = "AXMainWindow"
        static let windows = "AXWindows"
        static let children = "AXChildren"
        static let position = "AXPosition"
        static let size = "AXSize"
        static let titleUIElement = "AXTitleUIElement"
        static let identifier = "AXIdentifier"
        static let required = "AXRequired"
        static let domIdentifier = "AXDOMIdentifier"
    }

    static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        copy(element, attribute) as? Bool
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        copy(element, Attribute.children) as? [AXUIElement] ?? []
    }
}
