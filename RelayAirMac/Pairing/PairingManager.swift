import Foundation
import Observation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import OSLog
import RelayAirCore

/// Owns this Mac's pairing identity, its list of enrolled iPhones, and the QR
/// code that lets a new one join.
///
/// Two layers, deliberately:
///
/// - The **QR secret** keys the TLS handshake. It says "this connection is
///   between two devices that have met", nothing more.
/// - A **per-device key**, minted here and handed over at enrolment, says
///   *which* iPhone this is. Unpairing deletes the Mac's copy, after which that
///   phone's proofs stop verifying — which is what makes "Unpair" mean
///   something rather than just hiding a row.
///
/// New devices are only accepted while ``isAcceptingNewDevices`` is true, i.e.
/// while the user is actually looking at the code. Otherwise anyone who
/// photographed it once could enrol silently later.
@MainActor
@Observable
final class PairingManager {

    private(set) var pairing: PairingPayload?
    private(set) var devices: [DeviceRecord] = []

    /// How many surfaces are currently displaying the pairing code.
    ///
    /// A count rather than a flag because both the menu bar panel and the setup
    /// window can show it, and either closing shouldn't cancel pairing mode
    /// while the other is still open.
    private var codeDisplayCount = 0

    /// True while the pairing code is on screen somewhere. Gates enrolment.
    var isShowingCode: Bool { codeDisplayCount > 0 }

    /// Called when a device is revoked, so the link can drop it immediately.
    var onRevoke: (() -> Void)?

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Pairing")
    private let context = CIContext()

    /// Rendered QR, keyed on the pairing it encodes and the size asked for.
    @ObservationIgnored
    private var qrCache: (side: CGFloat, serviceName: String, image: NSImage)?

    var isPaired: Bool { !devices.isEmpty }

    // MARK: - Lifecycle

    /// Loads the stored pairing and device list, creating a pairing on first launch.
    func load() {
        devices = PairingStore.loadDevices()

        if let existing = PairingStore.load() {
            pairing = existing
            logger.notice("Loaded pairing with \(self.devices.count, privacy: .public) device(s)")
            return
        }
        regenerate()
    }

    /// Mints a new QR secret. Every enrolled phone is dropped, because their
    /// TLS keying material is gone.
    func regenerate() {
        let fresh = PairingPayload.generate(displayName: Self.macName())
        guard PairingStore.save(fresh) else {
            logger.error("Couldn't persist the new pairing to the Keychain")
            return
        }
        pairing = fresh
        qrCache = nil
        devices.removeAll()
        PairingStore.saveDevices(devices)
        onRevoke?()
        logger.notice("Generated a new pairing code; all devices dropped")
    }

    // MARK: - Pairing mode

    func beginShowingCode() { codeDisplayCount += 1 }

    func endShowingCode() { codeDisplayCount = max(0, codeDisplayCount - 1) }

    // MARK: - Devices

    /// Revokes one iPhone. It can reconnect only by scanning the code again.
    func unpair(_ device: DeviceRecord) {
        devices.removeAll { $0.id == device.id }
        PairingStore.saveDevices(devices)
        onRevoke?()
        logger.notice("Unpaired \(device.name, privacy: .public)")
    }

    func unpairAll() {
        devices.removeAll()
        PairingStore.saveDevices(devices)
        onRevoke?()
        logger.notice("Unpaired every device")
    }

    // MARK: - QR

    /// Renders the pairing code as a QR image.
    ///
    /// Cached, because this is called from a SwiftUI `body`: without the cache
    /// every unrelated view update — a status change, an animation frame — runs
    /// a CoreImage filter and a bitmap render, which is what made the panel feel
    /// sluggish. The code only changes when the pairing does.
    ///
    /// - Parameter side: Desired edge length in points. The generator emits a
    ///   small bitmap, so it's scaled up with nearest-neighbour interpolation
    ///   to keep the modules crisp instead of blurred.
    func qrImage(side: CGFloat = 190) -> NSImage? {
        guard let pairing else { return nil }

        if let cached = qrCache, cached.side == side, cached.serviceName == pairing.serviceName {
            return cached.image
        }

        let image = renderQR(pairing, side: side)
        if let image {
            qrCache = (side: side, serviceName: pairing.serviceName, image: image)
        }
        return image
    }

    private func renderQR(_ pairing: PairingPayload, side: CGFloat) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(pairing.qrURL.absoluteString.utf8)
        // Medium correction: still scannable off a glossy screen without making
        // the modules too dense to read at this size.
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

// MARK: - DeviceAuthority

extension PairingManager: RelayLink.DeviceAuthority {

    func key(for deviceID: UUID) -> Data? {
        devices.first { $0.id == deviceID }?.key
    }

    var isAcceptingNewDevices: Bool { isShowingCode }

    func enroll(name: String) -> DeviceCredential? {
        let record = DeviceRecord(
            id: UUID(),
            name: name,
            key: DeviceAuth.newDeviceKey(),
            enrolledAt: Date(),
            lastSeenAt: Date()
        )
        devices.append(record)
        guard PairingStore.saveDevices(devices) else {
            devices.removeAll { $0.id == record.id }
            logger.error("Couldn't persist the new device")
            return nil
        }
        return record.credential
    }

    func markSeen(deviceID: UUID, name: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].lastSeenAt = Date()
        devices[index].name = name
        PairingStore.saveDevices(devices)
    }
}
