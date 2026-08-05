import Foundation
import Observation
import OSLog
import UIKit
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
        /// In flight. The Mac types it as soon as it lands, so this is brief.
        case sending
        case filled
        case failed(String)
    }

    private(set) var outcome: CaptureOutcome = .idle
    private(set) var sendOutcome: SendOutcome = .idle
    private(set) var pairing: PairingPayload?
    /// Set when a scanned code couldn't be used.
    private(set) var pairingError: String?

    private let link = RelayLink(role: .client)
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Sender")

    /// The credential the Mac issued this phone at enrolment. Without it the
    /// next connection re-enrols, which only succeeds while the Mac is showing
    /// its code.
    private var credential: DeviceCredential?

    /// What this phone calls itself in the Mac's device list.
    private var deviceName: String {
        let name = UIDevice.current.name
        return name.isEmpty ? "iPhone" : name
    }

    var linkState: RelayLink.State { link.state }
    var isConnected: Bool { link.state.isConnected }
    var isPaired: Bool { pairing != nil }
    var isBusy: Bool { outcome == .capturing }
    var isSending: Bool { sendOutcome == .sending }
    var pairedMacName: String? { pairing?.displayName }

    // MARK: - Lifecycle

    /// Loads any stored pairing and starts looking for that Mac.
    ///
    /// On first connection iOS shows the Local Network prompt; if the user
    /// declines, discovery silently never succeeds.
    func begin() {
        link.onEnrolled = { [weak self] issued in
            guard let self else { return }
            self.credential = issued
            PairingStore.saveCredential(issued)
            self.logger.notice("Enrolled with the Mac")
        }
        pairing = PairingStore.load()
        credential = PairingStore.loadCredential()
        restart()
    }

    func end() {
        link.stop()
    }

    private func restart() {
        link.start(pairing: pairing, credential: credential, deviceName: deviceName)
    }

    // MARK: - Pairing

    /// Handles a scanned QR string.
    ///
    /// A rescan always drops the old credential: the code may be from a
    /// different Mac, or the same Mac after the user unpaired this phone. Either
    /// way the phone has to enrol again rather than present a stale identity.
    func handleScan(_ raw: String) {
        do {
            let payload = try PairingPayload.parse(raw)
            guard PairingStore.save(payload) else {
                pairingError = "Couldn't save the pairing to the Keychain."
                return
            }
            pairing = payload
            credential = nil
            pairingError = nil
            outcome = .idle
            sendOutcome = .idle
            logger.notice("Paired with \(payload.displayName, privacy: .public)")
            restart()
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
    ///
    /// This only clears *this* end. The Mac keeps its record until it's removed
    /// there too — which is why the Mac's list is the authoritative one.
    func unpair() {
        link.stop()
        PairingStore.clear()
        pairing = nil
        credential = nil
        outcome = .idle
        sendOutcome = .idle
        pairingError = nil
    }

    /// Retries discovery after a failure, without re-scanning.
    func reconnect() {
        guard pairing != nil else { return }
        restart()
    }

    // MARK: - Step 1: send

    /// Sends `text` for the Mac to fill.
    ///
    /// Call this only after the user has confirmed — this is the point of no
    /// return, and the Mac types it the moment it arrives.
    func send(text: String, followUp: FillRequest.FollowUp = .none) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        sendOutcome = .sending
        let request = FillRequest(text: trimmed, followUp: followUp)

        do {
            // Typing is paced to avoid dropped characters, so a long payload
            // takes a moment — but nothing here waits on a person.
            let response = try await link.send(.fill(request), timeout: .seconds(45))
            switch response {
            case .done:
                sendOutcome = .filled
                logger.notice("Transfer filled on the Mac")
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
