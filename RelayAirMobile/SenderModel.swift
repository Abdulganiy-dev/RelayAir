import Foundation
import Observation
import OSLog
import RelayAirCore

/// The iPhone's side of the link: finds the Mac and sends it commands.
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

    private(set) var outcome: CaptureOutcome = .idle

    private let link = PeerLink(role: .sender)
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Sender")

    var linkState: PeerLink.State { link.state }
    var isConnected: Bool { link.state.isConnected }
    var isBusy: Bool { outcome == .capturing }

    // MARK: - Lifecycle

    /// Starts looking for the Mac. On first call iOS shows the Local Network
    /// prompt; if the user declines, discovery silently never succeeds.
    func connect() {
        link.start()
    }

    func disconnect() {
        link.stop()
    }

    // MARK: - Commands

    /// Asks the Mac to screenshot itself and send the image back.
    func captureMacScreen() async {
        guard !isBusy else { return }
        outcome = .capturing

        do {
            // Capture, encode and transfer take longer than a round trip, so
            // this gets more headroom than the default.
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
