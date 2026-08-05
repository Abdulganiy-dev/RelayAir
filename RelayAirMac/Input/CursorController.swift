import CoreGraphics
import AppKit
import OSLog
import RelayAirCore

/// Moves the pointer and clicks on the user's behalf.
///
/// Needs the **Accessibility** permission for anything that posts an event.
/// Without it `CGEvent.post` fails silently — no error, no crash, nothing
/// happens — which is the most common cause of "why isn't it doing anything".
///
/// ## Coordinate systems
///
/// Everything here uses **global display coordinates with a top-left origin**,
/// which is what CoreGraphics expects. AppKit's `NSEvent.mouseLocation` and
/// `NSScreen.frame` use a bottom-left origin instead, so ``location`` converts.
@MainActor
final class CursorController {

    enum Button {
        case left, right

        var cgButton: CGMouseButton {
            switch self {
            case .left: .left
            case .right: .right
            }
        }

        var downType: CGEventType {
            switch self {
            case .left: .leftMouseDown
            case .right: .rightMouseDown
            }
        }

        var upType: CGEventType {
            switch self {
            case .left: .leftMouseUp
            case .right: .rightMouseUp
            }
        }

        var dragType: CGEventType {
            switch self {
            case .left: .leftMouseDragged
            case .right: .rightMouseDragged
            }
        }
    }

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Cursor")

    /// Pause between the steps of a synthesised drag or multi-step move.
    private let stepDelay: Duration = .milliseconds(8)

    // MARK: - Reading

    /// Current pointer position in global display coordinates (top-left origin).
    var location: CGPoint {
        let appKitPoint = NSEvent.mouseLocation
        // Flip around the primary display, which defines the shared origin.
        guard let primaryHeight = NSScreen.screens.first?.frame.height else {
            return appKitPoint
        }
        return CGPoint(x: appKitPoint.x, y: primaryHeight - appKitPoint.y)
    }

    // MARK: - Moving

    /// Teleports the pointer without generating a mouse-moved event.
    ///
    /// Needs no permission, but because no event is posted, apps under the
    /// pointer won't update hover states. Use ``move(to:)`` when the target app
    /// has to notice.
    func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        // Warping briefly decouples the hardware mouse from the cursor; this
        // re-associates them so the user isn't left with a stuck pointer.
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// Moves the pointer by posting a real `mouseMoved` event, so the app under
    /// the pointer sees it.
    ///
    /// - Returns: `false` if the event could not be created or posted.
    @discardableResult
    func move(to point: CGPoint) -> Bool {
        guard let source = makeSource() else { return false }
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            logger.error("Could not create mouseMoved event")
            return false
        }
        event.post(tap: .cghidEventTap)
        return true
    }

    /// Moves in a straight line over `steps` events, which reads as a real
    /// gesture to apps that track pointer velocity.
    @discardableResult
    func glide(to point: CGPoint, steps: Int = 12) async -> Bool {
        guard steps > 1 else { return move(to: point) }

        let start = location
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let interpolated = CGPoint(
                x: start.x + (point.x - start.x) * t,
                y: start.y + (point.y - start.y) * t
            )
            guard move(to: interpolated) else { return false }
            try? await Task.sleep(for: stepDelay)
        }
        return true
    }

    // MARK: - Clicking

    /// Clicks at `point`, moving there first.
    ///
    /// - Parameter clickCount: 2 for a double-click, 3 for a triple-click. The
    ///   count is carried on the event so the target app groups them correctly.
    @discardableResult
    func click(at point: CGPoint, button: Button = .left, clickCount: Int = 1) async -> Bool {
        guard let source = makeSource() else { return false }
        guard move(to: point) else { return false }
        try? await Task.sleep(for: stepDelay)

        for _ in 1...max(1, clickCount) {
            guard let down = CGEvent(
                mouseEventSource: source,
                mouseType: button.downType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            ), let up = CGEvent(
                mouseEventSource: source,
                mouseType: button.upType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            ) else {
                logger.error("Could not create click events")
                return false
            }

            down.setIntegerValueField(.mouseEventClickState, value: Int64(max(1, clickCount)))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(max(1, clickCount)))

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            try? await Task.sleep(for: stepDelay)
        }
        return true
    }

    /// Convenience: double-click, which selects the word under the pointer in
    /// most text fields.
    @discardableResult
    func doubleClick(at point: CGPoint) async -> Bool {
        await click(at: point, clickCount: 2)
    }

    // MARK: - Dragging

    /// Presses at `start`, drags to `end`, and releases.
    @discardableResult
    func drag(from start: CGPoint, to end: CGPoint, button: Button = .left, steps: Int = 12) async -> Bool {
        guard let source = makeSource() else { return false }
        guard move(to: start) else { return false }
        try? await Task.sleep(for: stepDelay)

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: button.downType,
            mouseCursorPosition: start,
            mouseButton: button.cgButton
        ) else { return false }
        down.post(tap: .cghidEventTap)
        try? await Task.sleep(for: stepDelay)

        for step in 1...max(1, steps) {
            let t = Double(step) / Double(max(1, steps))
            let point = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            guard let dragged = CGEvent(
                mouseEventSource: source,
                mouseType: button.dragType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            ) else { return false }
            dragged.post(tap: .cghidEventTap)
            try? await Task.sleep(for: stepDelay)
        }

        guard let up = CGEvent(
            mouseEventSource: source,
            mouseType: button.upType,
            mouseCursorPosition: end,
            mouseButton: button.cgButton
        ) else { return false }
        up.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Event source

    private func makeSource() -> CGEventSource? {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("Could not create CGEventSource")
            return nil
        }
        // Without this, macOS swallows real input for ~250ms after each
        // synthetic event, which makes the pointer feel frozen.
        source.localEventsSuppressionInterval = 0
        return source
    }
}
