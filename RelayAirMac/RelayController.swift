import Foundation
import Observation
import OSLog
import RelayAirCore

/// Drives the Mac's side of *Send. Approve. Fill.*
///
/// The Mac no longer inspects the focused field through the Accessibility API —
/// it just types into whatever has focus. That means it has no idea what's on
/// the other end, which is exactly why the approval step exists.
///
/// The transport is not built yet, so ``receive(_:)`` and ``approve()`` are the
/// hand-driven entry points that a real connection will call later.
@MainActor
@Observable
final class RelayController {

    private(set) var state: RelayState = .paused

    /// The payload waiting on the user's approval, if any.
    private(set) var pendingRequest: FillRequest?

    private let permissions: PermissionsModel
    private let screenCapture: ScreenCaptureService
    private let injector = TextInjector()
    private let link = PeerLink(role: .receiver)
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Relay")

    /// Whether an iPhone is currently connected.
    var linkState: PeerLink.State { link.state }

    init(permissions: PermissionsModel, screenCapture: ScreenCaptureService) {
        self.permissions = permissions
        self.screenCapture = screenCapture
        link.commandHandler = { [weak self] command in
            guard let self else { return .failed("Relay Air is shutting down.") }
            return await self.handle(command)
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
        link.start()
        logger.notice("Relay active, waiting for iPhone")
        return true
    }

    /// Stops listening and drops anything pending. Called when the user toggles
    /// the relay off and on app termination.
    func stop() {
        guard isActive else { return }
        link.stop()
        pendingRequest = nil
        state = .paused
        logger.notice("Relay paused")
    }

    // MARK: - Incoming commands

    /// Routes a command from the iPhone.
    ///
    /// `.captureScreen` runs immediately — the user initiated it from their own
    /// paired device and the result goes straight back to them. `.fill` is the
    /// one that touches other apps, so it goes through the approval gate.
    private func handle(_ command: RelayCommand) async -> RelayResponse {
        switch command {
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
            receive(request)
            return .awaitingApproval
        }
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

    // MARK: - Step 2: approval

    /// Step 1 → 2. A transfer arrived and now needs the user's sign-off.
    ///
    /// Nothing is typed until ``approve()`` is called — that gap is the whole
    /// point of the middle step.
    func receive(_ request: FillRequest) {
        guard isActive else {
            logger.warning("Dropped an incoming request: relay is paused")
            return
        }
        pendingRequest = request
        state = .awaitingApproval
        logger.notice("Transfer received, awaiting approval")
    }

    /// Discards the pending transfer without typing it.
    func reject() {
        guard pendingRequest != nil else { return }
        pendingRequest = nil
        state = .waiting
        logger.notice("Transfer rejected")
    }

    // MARK: - Step 3: fill

    /// Step 2 → 3. Types the approved payload into whatever has focus.
    @discardableResult
    func approve() async -> Bool {
        guard let request = pendingRequest else { return false }
        pendingRequest = nil
        return await fill(request)
    }

    /// Types `request` immediately, skipping the approval gate.
    ///
    /// Only for local testing and hotkeys — anything arriving from the iPhone
    /// should go through ``receive(_:)`` and ``approve()``.
    @discardableResult
    func fill(_ request: FillRequest) async -> Bool {
        guard permissions.canControlInput else {
            state = .failed("Accessibility permission required")
            return false
        }

        state = .filling
        let didFill = await injector.perform(request)

        if didFill {
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
