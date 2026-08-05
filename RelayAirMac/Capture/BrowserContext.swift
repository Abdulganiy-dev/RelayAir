import Foundation
import AppKit
import OSLog
import RelayAirCore

/// Asks a browser what page a captured window is showing.
///
/// A window title tells you a page is called "Apple"; only the browser knows it
/// is `https://www.apple.com`. Apple Events is the route because it asks the
/// browser directly, so it either answers correctly or fails outright — unlike
/// scraping the address bar through the Accessibility API, which silently
/// returns the wrong element whenever a browser reshuffles its toolbar.
///
/// Requirements, all already in place:
/// - `com.apple.security.automation.apple-events` in the entitlements (needed
///   because the app uses the Hardened Runtime).
/// - `NSAppleEventsUsageDescription` in Info.plist — without it the process is
///   killed rather than prompted.
/// - The user approving each browser under Privacy & Security ▸ Automation.
///   That prompt appears the first time a capture lands on that browser, not at
///   launch, because this is only called for a window we actually captured.
enum BrowserContext {

    /// Which scripting vocabulary a browser speaks.
    ///
    /// Only two exist in practice: Safari's, and the one every Chromium fork
    /// inherited from Chrome.
    enum Engine {
        /// `current tab of w`, then `name` and `URL` of that tab.
        case safari
        /// `active tab of w`, then `title` and `URL` of that tab.
        case chromium
    }

    /// A browser we know how to ask.
    struct Browser {
        let bundleID: String
        let name: String
        let engine: Engine

        /// Every browser understood, including the release channels people
        /// actually run day to day.
        ///
        /// Bundle IDs matter twice over: they select the entry *and* target the
        /// script. Sending Chrome's bundle ID to ask about Brave would return
        /// whatever Chrome happens to have open — a wrong answer rather than no
        /// answer, which is the worse failure.
        static let known: [Browser] = [
            Browser(bundleID: "com.apple.Safari", name: "Safari", engine: .safari),
            Browser(bundleID: "com.apple.SafariTechnologyPreview", name: "Safari Technology Preview", engine: .safari),

            Browser(bundleID: "com.google.Chrome", name: "Chrome", engine: .chromium),
            Browser(bundleID: "com.google.Chrome.beta", name: "Chrome Beta", engine: .chromium),
            Browser(bundleID: "com.google.Chrome.dev", name: "Chrome Dev", engine: .chromium),
            Browser(bundleID: "com.google.Chrome.canary", name: "Chrome Canary", engine: .chromium),

            Browser(bundleID: "com.brave.Browser", name: "Brave", engine: .chromium),
            Browser(bundleID: "com.brave.Browser.beta", name: "Brave Beta", engine: .chromium),
            Browser(bundleID: "com.brave.Browser.nightly", name: "Brave Nightly", engine: .chromium),

            Browser(bundleID: "com.microsoft.edgemac", name: "Edge", engine: .chromium),
            Browser(bundleID: "com.microsoft.edgemac.Beta", name: "Edge Beta", engine: .chromium),
            Browser(bundleID: "com.microsoft.edgemac.Dev", name: "Edge Dev", engine: .chromium),
            Browser(bundleID: "com.microsoft.edgemac.Canary", name: "Edge Canary", engine: .chromium),

            Browser(bundleID: "company.thebrowser.Browser", name: "Arc", engine: .chromium),
            Browser(bundleID: "company.thebrowser.dia", name: "Dia", engine: .chromium),
        ]

        init(bundleID: String, name: String, engine: Engine) {
            self.bundleID = bundleID
            self.name = name
            self.engine = engine
        }

        init?(bundleID: String) {
            guard let match = Self.known.first(where: { $0.bundleID == bundleID }) else { return nil }
            self = match
        }

        /// Returns `{{title, url}, …}`, one entry per window, front to back.
        ///
        /// Every window is returned rather than just the front one because the
        /// captured window is whichever the pointer was over, which is often
        /// *not* frontmost. The caller matches on title.
        ///
        /// `application id` rather than a name, so a localised or renamed app
        /// bundle still resolves. The `try` blocks skip windows with no tab —
        /// a downloads or settings window, say — instead of failing the whole
        /// script.
        var script: String {
            let tab: String
            let titleProperty: String
            switch engine {
            case .safari:
                tab = "current tab of w"
                titleProperty = "name"
            case .chromium:
                tab = "active tab of w"
                titleProperty = "title"
            }

            return """
            tell application id "\(bundleID)"
                set out to {}
                repeat with w in windows
                    try
                        set t to \(tab)
                        set end of out to {\(titleProperty) of t as text, URL of t as text}
                    end try
                end repeat
                return out
            end tell
            """
        }
    }

    /// One browser window's page.
    struct Page: Equatable {
        var title: String
        var url: String
    }

    private static let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "BrowserContext")

    /// How long to wait for the browser to answer before giving up.
    ///
    /// A responsive browser replies in tens of milliseconds. A wedged one would
    /// otherwise stall the capture, and a screenshot without a URL beats no
    /// screenshot at all.
    private static let timeoutSeconds: Double = 1.5

    /// Looks up the page shown in `windowTitle` of the app owning `bundleID`.
    ///
    /// - Returns: `nil` when the app isn't a browser we know, automation was
    ///   refused, the browser has no scripting dictionary, or nothing
    ///   matched — every one of which is non-fatal. A capture without a URL is
    ///   still a capture, so nothing here is allowed to fail the screenshot.
    static func page(bundleID: String?, windowTitle: String?) async -> Page? {
        guard let bundleID, let browser = Browser(bundleID: bundleID) else { return nil }

        // AppleScript launches a target that isn't running. That can't happen
        // via the capture path — we only get here for a window we just
        // photographed — but nothing should be able to start a browser as a
        // side effect of taking a screenshot.
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
            return nil
        }

        guard let pages = await runScript(browser), !pages.isEmpty else { return nil }

        // Match the window we actually captured. Titles are what both sides
        // agree on: `SCWindow.title` and the tab's title are the same string.
        if let title = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
           let match = pages.first(where: { $0.title == title }) {
            return match
        }

        // No match: the window may have no title, or the tab changed between
        // the capture and the query. Frontmost is the best remaining guess.
        logger.debug("No title match for \(browser.name, privacy: .public); using the front window")
        return pages.first
    }

    // MARK: - Running the script

    private static func runScript(_ browser: Browser) async -> [Page]? {
        await withCheckedContinuation { continuation in
            let resumed = OSAllocatedUnfairLock(initialState: false)

            /// Resumes at most once, whichever of the script or the timeout wins.
            func finish(_ value: [Page]?) {
                let alreadyResumed = resumed.withLock { done -> Bool in
                    defer { done = true }
                    return done
                }
                guard !alreadyResumed else { return }
                continuation.resume(returning: value)
            }

            // NSAppleScript blocks until the target app replies, so it runs off
            // the main thread. The instance is created and used on this one
            // thread only, which is what it requires.
            DispatchQueue.global(qos: .userInitiated).async {
                finish(execute(browser))
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
                logger.error("\(browser.name, privacy: .public) didn't answer in time")
                finish(nil)
            }
        }
    }

    private static func execute(_ browser: Browser) -> [Page]? {
        guard let script = NSAppleScript(source: browser.script) else { return nil }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            switch code {
            case -1743:
                // The user declined this browser under Privacy ▸ Automation.
                logger.notice("Automation permission refused for \(browser.name, privacy: .public)")
            case -600, -609:
                logger.debug("\(browser.name, privacy: .public) isn't running")
            case -1728:
                // No scripting dictionary, or it doesn't use these terms.
                logger.notice("\(browser.name, privacy: .public) doesn't answer this script")
            default:
                logger.error("AppleScript to \(browser.name, privacy: .public) failed: \(code, privacy: .public)")
            }
            return nil
        }

        return parse(result)
    }

    /// Unpacks `{{title, url}, …}` from the returned descriptor.
    ///
    /// AppleScript lists are 1-indexed.
    private static func parse(_ descriptor: NSAppleEventDescriptor) -> [Page] {
        guard descriptor.numberOfItems > 0 else { return [] }

        return (1...descriptor.numberOfItems).compactMap { index in
            guard let entry = descriptor.atIndex(index), entry.numberOfItems >= 2,
                  let title = entry.atIndex(1)?.stringValue,
                  let url = entry.atIndex(2)?.stringValue,
                  !url.isEmpty
            else { return nil }
            return Page(title: title, url: url)
        }
    }
}
