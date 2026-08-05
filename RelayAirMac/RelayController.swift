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
/// The Mac doesn't inspect the focused field through the Accessibility API —
/// it types into whatever has focus, and never learns what that was.
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

        case .fill(let request):
            guard isActive else { return .failed("Relay Air is paused on the Mac.") }
            let didFill = await fill(request)
            return didFill ? .done : .failed("The Mac couldn't type into the focused field.")
        }
    }

    // MARK: - Fill

    /// Types `request` into whatever currently has keyboard focus.
    @discardableResult
    func fill(_ request: FillRequest) async -> Bool {
        guard permissions.canControlInput else {
            state = .failed("Accessibility permission required")
            return false
        }

        state = .filling
        let didFill = await injector.perform(request)

        if didFill {
            lastFill = FillSummary(
                characterCount: request.text.count,
                followUp: request.followUp,
                deviceName: connectedDeviceName,
                at: Date()
            )
            state = .waiting
            logger.notice("Filled \(request.text.count, privacy: .public) characters")
        } else {
            state = .failed("Couldn't type into the focused field")
            logger.error("Fill failed")
        }
        return didFill
    }

    /// Convenience for the common case.
    @discardableResult
    func fill(text: String) async -> Bool {
        await fill(FillRequest(text: text))
    }

    /// Clears a `.failed` state and goes back to listening.
    func clearError() {
        guard case .failed = state else { return }
        state = permissions.canControlInput ? .waiting : .paused
    }
}
