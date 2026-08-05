import Foundation
import Observation
import OSLog
import RelayAirCore

/// The iPhone's side of the link: pairs with a Mac, then sends it commands.
@MainActor
@Observable
final class SenderModel {

    /// Result of the most recent screenshot request.
    enum CaptureOutcome: Equatable {
        case idle
        case capturing
        case captured(Screenshot)
        case failed(String)
    }

    /// Where a text transfer has got to.
    enum SendOutcome: Equatable {
        case idle
        /// On its way, or sitting in front of the user on the Mac.
        case awaitingApproval
        case filled
        case rejected
        case failed(String)
    }

    private(set) var outcome: CaptureOutcome = .idle
    private(set) var sendOutcome: SendOutcome = .idle
    private(set) var pairing: PairingPayload?
    /// Set when a scanned code couldn't be used.
    private(set) var pairingError: String?

    private let link = RelayLink(role: .client)
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Sender")

    var linkState: RelayLink.State { link.state }
    var isConnected: Bool { link.state.isConnected }
    var isPaired: Bool { pairing != nil }
    var isBusy: Bool { outcome == .capturing }
    var isSending: Bool { sendOutcome == .awaitingApproval }
    var pairedMacName: String? { pairing?.displayName }

    // MARK: - Lifecycle

    /// Loads any stored pairing and starts looking for that Mac.
    ///
    /// On first connection iOS shows the Local Network prompt; if the user
    /// declines, discovery silently never succeeds.
    func begin() {
        pairing = PairingStore.load()
        link.start(pairing: pairing)
    }

    func end() {
        link.stop()
    }

    // MARK: - Pairing

    /// Handles a scanned QR string.
    func handleScan(_ raw: String) {
        do {
            let payload = try PairingPayload.parse(raw)
            guard PairingStore.save(payload) else {
                pairingError = "Couldn't save the pairing to the Keychain."
                return
            }
            pairing = payload
            pairingError = nil
            outcome = .idle
            logger.notice("Paired with \(payload.displayName, privacy: .public)")
            link.start(pairing: payload)
        } catch {
            pairingError = error.localizedDescription
        }
    }

    func reportScanError(_ message: String) {
        pairingError = message
    }

    func clearPairingError() {
        pairingError = nil
    }

    /// Forgets the Mac. The QR has to be scanned again to reconnect.
    func unpair() {
        link.stop()
        PairingStore.clear()
        pairing = nil
        outcome = .idle
    }

    // MARK: - Step 1: send

    /// Sends `text` for the Mac to fill.
    ///
    /// The response deliberately takes as long as the user does — the Mac holds
    /// it open until they approve or reject — so this reports `awaitingApproval`
    /// throughout and only settles once they've decided.
    func send(text: String, followUp: FillRequest.FollowUp = .none) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        sendOutcome = .awaitingApproval
        let request = FillRequest(text: trimmed, followUp: followUp)

        do {
            // Long enough for someone to notice the menu bar and decide.
            let response = try await link.send(.fill(request), timeout: .seconds(120))
            switch response {
            case .done:
                sendOutcome = .filled
                logger.notice("Transfer filled on the Mac")
            case .rejected:
                sendOutcome = .rejected
            case .failed(let reason):
                sendOutcome = .failed(reason)
            default:
                sendOutcome = .failed("The Mac sent back an unexpected reply.")
            }
        } catch {
            sendOutcome = .failed(error.localizedDescription)
        }
    }

    func clearSendOutcome() {
        sendOutcome = .idle
    }

    // MARK: - Other commands

    /// Asks the Mac to screenshot itself and send the image back.
    func captureMacScreen() async {
        guard !isBusy else { return }
        outcome = .capturing

        do {
            // Capture, downscale, encode and transfer take longer than a round
            // trip, so this gets more headroom than the default.
            let response = try await link.send(.captureScreen, timeout: .seconds(30))
            switch response {
            case .screenshot(let screenshot):
                logger.notice("Received \(screenshot.byteCount / 1024, privacy: .public) KB screenshot")
                outcome = .captured(screenshot)
            case .failed(let reason):
                outcome = .failed(reason)
            default:
                outcome = .failed("The Mac sent back an unexpected reply.")
            }
        } catch {
            outcome = .failed(error.localizedDescription)
        }
    }

    func clearOutcome() {
        outcome = .idle
    }
}
