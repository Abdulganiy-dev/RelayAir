import Foundation
import Observation
import OSLog
import RelayAirCore

/// Drives the Mac's side of *Send. Approve. Fill.*
///
/// The Mac is the **Fill** end only. Approval happens on the iPhone, before
/// anything leaves it — by the time a command arrives here the user has already
/// signed off, so the Mac acts on it straight away rather than asking a second
/// time. The Mac's own gate is coarser and always on: the relay has to be
/// switched on, the device has to be enrolled and authenticated, and
/// Accessibility has to be granted.
///
/// ### Two ways to fill
///
/// A ``FillRequest`` with no target keeps the original behaviour: type into
/// whatever has focus, without the Mac learning what that was.
///
/// A request that names a target came from a phone looking at a list of fields
/// the Mac described to it, so the Mac focuses that field first. Producing that
/// list means reading the Accessibility tree — labels, kinds and positions, via
/// ``AccessibilityFieldInspector``. Field *contents* are still never read.
@MainActor
@Observable
final class RelayController {

    private(set) var state: RelayState = .paused

    /// What was filled most recently, for the menu bar's activity line.
    private(set) var lastFill: FillSummary?

    /// A redacted record of one completed transfer.
    ///
    /// Deliberately no text: the payload is routinely a password or a one-time
    /// code, and the menu bar sits in front of whoever is looking at the screen.
    struct FillSummary: Equatable {
        var characterCount: Int
        var followUp: FillRequest.FollowUp
        var deviceName: String?
        var at: Date

        var description: String {
            var line = "Filled \(characterCount) characters"
            if followUp != .none { line += ", then \(followUp.rawValue)" }
            if let deviceName { line += " · from \(deviceName)" }
            return line
        }
    }

    private let permissions: PermissionsModel
    private let screenCapture: ScreenCaptureService
    private let pairing: PairingManager
    private let injector = TextInjector()
    private let inspector = AccessibilityFieldInspector()
    private let link = RelayLink(role: .listener)
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Relay")

    /// Whether an iPhone is currently connected.
    var linkState: RelayLink.State { link.state }

    /// Name of the iPhone on the other end, if one is connected.
    var connectedDeviceName: String? {
        if case .connected(let name) = link.state { return name }
        return nil
    }

    init(permissions: PermissionsModel, screenCapture: ScreenCaptureService, pairing: PairingManager) {
        self.permissions = permissions
        self.screenCapture = screenCapture
        self.pairing = pairing
        link.authority = pairing
        link.commandHandler = { [weak self] command in
            guard let self else { return .failed("Relay Air is shutting down.") }
            return await self.handle(command)
        }
        // Revoking a device should cut it off now, not at its next reconnect.
        pairing.onRevoke = { [weak self] in
            self?.link.disconnectPeer()
        }
    }

    var isActive: Bool { state.isActive }

    // MARK: - Start / stop

    /// Begins listening. Requires Accessibility, since the relay is pointless if
    /// the Mac can't type.
    @discardableResult
    func start() -> Bool {
        guard !isActive else { return true }
        guard permissions.canControlInput else {
            state = .failed("Accessibility permission required")
            logger.warning("start() blocked: missing Accessibility permission")
            return false
        }
        state = .waiting
        link.start(pairing: pairing.pairing)
        logger.notice("Relay active, waiting for iPhone")
        return true
    }

    /// Re-advertises with the current pairing. Called after the code is
    /// regenerated, so a phone can't keep using the old secret.
    func restartLink() {
        guard isActive else { return }
        link.start(pairing: pairing.pairing)
    }

    /// Stops listening. Called when the user toggles the relay off, and on app
    /// termination.
    func stop() {
        guard isActive else { return }
        link.stop()
        state = .paused
        logger.notice("Relay paused")
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }

    /// Starts as soon as permissions allow; safe to call repeatedly.
    func startIfPermitted() {
        guard !isActive, permissions.canControlInput else { return }
        start()
    }

    // MARK: - Incoming commands

    /// Routes a command from an authenticated iPhone.
    ///
    /// Everything runs immediately. The device on the other end is enrolled,
    /// has proved its identity, and its user has already confirmed the transfer
    /// — asking again here would be a second prompt for the same decision.
    private func handle(_ command: RelayCommand) async -> RelayResponse {
        switch command {
        case .enroll, .authenticate:
            // RelayLink answers these itself; the app never gets a vote on who
            // is allowed in.
            return .failed("Handled by the link.")

        case .ping:
            return .pong

        case .captureScreen:
            guard permissions.isGranted(.screenRecording) else {
                return .failed("Screen Recording permission isn't granted on the Mac.")
            }
            do {
                let screenshot = try await screenCapture.captureForTransport()
                return .screenshot(screenshot)
            } catch {
                logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                return .failed(error.localizedDescription)
            }

        case .listFormFields:
            guard isActive else { return .failed("Relay Air is paused on the Mac.") }
            guard permissions.canControlInput else {
                return .failed("Accessibility permission isn't granted on the Mac.")
            }
            return .formFields(await inspector.snapshot())

        case .fill(let request):
            guard isActive else { return .failed("Relay Air is paused on the Mac.") }
            let outcome = await fill(request)
            return outcome == .filled ? .done : .failed(outcome.message)
        }
    }

    // MARK: - Fill

    /// How a fill ended. The phone shows these, so they say what the person can
    /// do about it rather than what went wrong internally.
    enum FillOutcome: Equatable {
        case filled
        case noPermission
        /// The named field is gone, or the user has moved to another app since
        /// the list was taken.
        case staleTarget
        case typingFailed

        var message: String {
            switch self {
            case .filled: "Filled."
            case .noPermission: "Accessibility permission isn't granted on the Mac."
            case .staleTarget: "That field has moved on. Ask for the field list again."
            case .typingFailed: "The Mac couldn't type into the focused field."
            }
        }
    }

    /// Types `request` into the field it names, or into whatever has keyboard
    /// focus when it names none.
    ///
    /// A named target is focused first, and a target that can't be focused stops
    /// the fill — the text is routinely a password, and typing it into whatever
    /// happens to be focused instead is worse than not typing it at all.
    @discardableResult
    func fill(_ request: FillRequest) async -> FillOutcome {
        guard permissions.canControlInput else {
            state = .failed("Accessibility permission required")
            return .noPermission
        }

        if let target = request.target, await !inspector.focus(fieldID: target) {
            state = .failed("Couldn't focus the requested field")
            logger.error("Refusing fill: target field is stale")
            return .staleTarget
        }

        state = .filling
        let didFill = await injector.perform(request)

        guard didFill else {
            state = .failed("Couldn't type into the focused field")
            logger.error("Fill failed")
            return .typingFailed
        }

        lastFill = FillSummary(
            characterCount: request.text.count,
            followUp: request.followUp,
            deviceName: connectedDeviceName,
            at: Date()
        )
        state = .waiting
        logger.notice("Filled \(request.text.count, privacy: .public) characters")
        return .filled
    }

    /// Convenience for the common case.
    @discardableResult
    func fill(text: String) async -> Bool {
        await fill(FillRequest(text: text)) == .filled
    }

    /// Clears a `.failed` state and goes back to listening.
    func clearError() {
        guard case .failed = state else { return }
        state = permissions.canControlInput ? .waiting : .paused
    }
}
