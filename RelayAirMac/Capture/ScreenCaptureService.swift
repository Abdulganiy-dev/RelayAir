import ScreenCaptureKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit
import OSLog
import RelayAirCore

/// Captures screen pixels.
///
/// This is the only part of the app that needs the **Screen Recording**
/// permission, and it is deliberately isolated so the rest of Relay Air
/// keeps working when the user declines it. Nothing here is called until a
/// feature that needs pixels is switched on.
@MainActor
final class ScreenCaptureService {

    enum CaptureError: LocalizedError {
        case permissionDenied
        case noDisplayAvailable
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Relay Air needs Screen Recording permission to read the screen."
            case .noDisplayAvailable:
                "No capturable display was found."
            case .encodingFailed:
                "The screenshot couldn't be encoded."
            }
        }
    }

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "ScreenCapture")

    /// Captures the display containing `rect` and crops to it.
    ///
    /// - Parameter rect: Region in global screen coordinates. Pass `nil` for the
    ///   whole main display.
    func captureImage(of rect: CGRect? = nil) async throws -> CGImage {
        guard SystemPermission.screenRecording.isGranted else {
            logger.warning("Capture refused: Screen Recording permission not granted")
            throw CaptureError.permissionDenied
        }

        // Excluding desktop windows keeps wallpaper and Finder icons out of the shot.
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )

        guard let display = displayContaining(rect, in: content.displays) else {
            throw CaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let configuration = SCStreamConfiguration()
        configuration.captureResolution = .best
        configuration.showsCursor = false
        if let rect {
            // `sourceRect` is display-relative, with a top-left origin.
            configuration.sourceRect = rect.offsetBy(
                dx: -CGFloat(display.frame.origin.x),
                dy: -CGFloat(display.frame.origin.y)
            )
            configuration.width = Int(rect.width)
            configuration.height = Int(rect.height)
        } else {
            configuration.width = display.width
            configuration.height = display.height
        }

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    private func displayContaining(_ rect: CGRect?, in displays: [SCDisplay]) -> SCDisplay? {
        guard let rect else { return displays.first }
        return displays.first { $0.frame.intersects(rect) } ?? displays.first
    }

    // MARK: - For the wire

    /// Captures the main display and packages it for transmission to the iPhone.
    ///
    /// A Retina screenshot is ~8 MP of PNG, which is far more than a phone
    /// preview needs, so it's downscaled and JPEG-encoded first.
    ///
    /// - Parameters:
    ///   - maxDimension: Longest edge of the transmitted image, in pixels.
    ///   - quality: JPEG quality, 0–1.
    func captureForTransport(maxDimension: Int = 1400, quality: Double = 0.7) async throws -> Screenshot {
        let image = try await captureImage()
        let scaled = downscale(image, maxDimension: maxDimension)

        guard let data = encodeJPEG(scaled, quality: quality) else {
            throw CaptureError.encodingFailed
        }

        logger.notice(
            "Captured \(image.width, privacy: .public)×\(image.height, privacy: .public) → \(data.count / 1024, privacy: .public) KB"
        )

        return Screenshot(
            imageData: data,
            width: scaled.width,
            height: scaled.height,
            sourceWidth: image.width,
            sourceHeight: image.height,
            capturedAt: Date()
        )
    }

    /// Proportionally shrinks `image` so its longest edge is at most
    /// `maxDimension`. Returns the original if it's already small enough.
    private func downscale(_ image: CGImage, maxDimension: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = Double(maxDimension) / Double(longest)
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    private func encodeJPEG(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
