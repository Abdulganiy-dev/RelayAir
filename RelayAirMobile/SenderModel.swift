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

    /// Result of the most recent request for what's on the Mac's screen.
    enum FieldsOutcome: Equatable {
        case idle
        case loading
        /// Arrived. May still hold no fields — an app the Mac can't read is a
        /// normal answer, and the UI says so rather than showing an error.
        case loaded(FormSnapshot)
        case failed(String)
    }

    private(set) var outcome: CaptureOutcome = .idle
    private(set) var sendOutcome: SendOutcome = .idle
    private(set) var fieldsOutcome: FieldsOutcome = .idle
    private(set) var pairing: PairingPayload?
    /// Set when a scanned code couldn't be used.
    private(set) var pairingError: String?

    /// The field the user picked from the list, if any. `nil` means "fill
    /// whatever the Mac has focused", which is how the app worked before there
    /// was a list.
    var selectedField: FormField?

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
    var isLoadingFields: Bool { fieldsOutcome == .loading }
    var pairedMacName: String? { pairing?.displayName }

    /// The fields the Mac last reported, if that request succeeded.
    var fields: [FormField] {
        if case .loaded(let snapshot) = fieldsOutcome { return snapshot.fields }
        return []
    }

    /// Where those fields are — "Safari — Sign in".
    var fieldsContext: String? {
        if case .loaded(let snapshot) = fieldsOutcome { return snapshot.contextDescription }
        return nil
    }

    /// The page the fields are on, when the Mac could tell. Worth showing before
    /// a password: it's the difference between a bank and something spelled like
    /// one.
    var fieldsURL: String? {
        if case .loaded(let snapshot) = fieldsOutcome { return snapshot.url }
        return nil
    }

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
            discardFields()
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
        discardFields()
    }

    /// Retries discovery after a failure, without re-scanning.
    func reconnect() {
        guard pairing != nil else { return }
        restart()
    }

    // MARK: - Step 1: send

    /// Sends `text` for the Mac to fill.
    ///
    /// Goes to ``selectedField`` when one is picked, and to whatever the Mac has
    /// focused when none is. Call this only after the user has confirmed — this
    /// is the point of no return, and the Mac types it the moment it arrives.
    func send(text: String, followUp: FillRequest.FollowUp = .none) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        sendOutcome = .sending
        let target = selectedField
        let request = FillRequest(text: trimmed, followUp: followUp, target: target?.id)

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
                // The Mac refuses a target it can no longer find, which means the
                // list this phone is showing describes a screen that has moved
                // on. Drop it rather than let the user pick from it again.
                if target != nil { discardFields() }
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

    // MARK: - Step 0: what's on the Mac's screen

    /// Asks the Mac which fields are in front of it.
    ///
    /// Descriptions only — labels, kinds and positions. The Mac never reads what
    /// is already typed in them, so nothing sensitive travels in this direction.
    func listMacFields() async {
        guard !isLoadingFields else { return }
        fieldsOutcome = .loading
        selectedField = nil

        do {
            let response = try await link.send(.listFormFields, timeout: .seconds(20))
            switch response {
            case .formFields(let snapshot):
                logger.notice("Mac reported \(snapshot.fields.count, privacy: .public) fields")
                fieldsOutcome = .loaded(snapshot)
                // One obvious candidate: save the user a tap.
                if snapshot.fields.count == 1 { selectedField = snapshot.fields.first }
            case .failed(let reason):
                fieldsOutcome = .failed(reason)
            default:
                fieldsOutcome = .failed("The Mac sent back an unexpected reply.")
            }
        } catch {
            fieldsOutcome = .failed(error.localizedDescription)
        }
    }

    /// Picks a field, or clears the choice when the same one is tapped again.
    func selectField(_ field: FormField) {
        selectedField = selectedField?.id == field.id ? nil : field
    }

    /// Forgets the field list. Ids only mean something to the snapshot that
    /// produced them, so a stale list is worse than none.
    func discardFields() {
        fieldsOutcome = .idle
        selectedField = nil
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
