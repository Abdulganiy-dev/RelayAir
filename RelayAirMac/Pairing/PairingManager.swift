import Foundation
import Observation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import OSLog
import RelayAirCore

/// Owns this Mac's pairing identity and renders it as a QR code.
///
/// The Mac is the source of truth: it mints the secret once, keeps it in the
/// Keychain, and shows it as a QR for the iPhone to scan. Regenerating
/// invalidates every previously paired phone, which is the "revoke" button.
@MainActor
@Observable
final class PairingManager {

    private(set) var pairing: PairingPayload?

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Pairing")
    private let context = CIContext()

    var isPaired: Bool { pairing != nil }

    /// Loads the stored pairing, creating one on first launch.
    func loadOrCreate() {
        if let existing = PairingStore.load() {
            pairing = existing
            logger.notice("Loaded existing pairing")
            return
        }
        regenerate()
    }

    /// Mints a new secret. Any phone paired with the old one stops working.
    func regenerate() {
        let fresh = PairingPayload.generate(displayName: Self.macName())
        guard PairingStore.save(fresh) else {
            logger.error("Couldn't persist the new pairing to the Keychain")
            return
        }
        pairing = fresh
        logger.notice("Generated a new pairing")
    }

    /// Renders the pairing code as a QR image.
    ///
    /// - Parameter side: Desired edge length in points. The generator emits a
    ///   small bitmap, so it's scaled up with nearest-neighbour to keep the
    ///   modules crisp instead of blurred.
    func qrImage(side: CGFloat = 220) -> NSImage? {
        guard let pairing else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(pairing.qrURL.absoluteString.utf8)
        // Medium error correction: still scannable off a glossy screen without
        // making the modules too dense to read at this size.
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
    }

    private static func macName() -> String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }
}
