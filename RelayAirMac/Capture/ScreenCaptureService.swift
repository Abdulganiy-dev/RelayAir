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

    /// A capture plus a note of where it came from.
    struct CaptureResult {
        var image: CGImage
        /// e.g. "Safari — Apple", or "Built-in Display" when nothing was under
        /// the pointer. Shown on the phone so it's obvious what got grabbed.
        var source: String
    }

    // MARK: - Window under the cursor

    /// Captures just the window the pointer is currently over.
    ///
    /// Falls back to the whole display when the pointer is over the desktop, or
    /// over something that isn't a capturable window.
    func captureWindowUnderCursor() async throws -> CaptureResult {
        guard SystemPermission.screenRecording.isGranted else {
            logger.warning("Capture refused: Screen Recording permission not granted")
            throw CaptureError.permissionDenied
        }

        // `CGEvent.location` is already in global display coordinates with a
        // top-left origin, which is what `SCWindow.frame` uses. Going via
        // `NSEvent.mouseLocation` would mean flipping y against the primary
        // screen's height — easy to get subtly wrong on multi-display setups.
        guard let cursor = CGEvent(source: nil)?.location else {
            return try await captureDisplay(containing: nil)
        }

        // Desktop windows are included here so the wallpaper can be recognised
        // and skipped deliberately, rather than being mistaken for a window.
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let window = frontmostWindow(at: cursor, in: content.windows) else {
            logger.notice("No window under the pointer; capturing the display instead")
            return try await captureDisplay(containing: cursor)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let configuration = SCStreamConfiguration()
        configuration.captureResolution = .best
        configuration.showsCursor = false
        configuration.ignoreGlobalClipDisplay = true

        // `frame` is in points; multiply by the display's backing scale so a
        // Retina window isn't captured at half resolution.
        let scale = backingScale(for: window, in: content.displays)
        configuration.width = max(1, Int(window.frame.width * scale))
        configuration.height = max(1, Int(window.frame.height * scale))

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        let source = describe(window)
        logger.notice("Captured window: \(source, privacy: .public)")
        return CaptureResult(image: image, source: source)
    }

    /// The topmost ordinary window containing `point`.
    ///
    /// `SCShareableContent.windows` comes back in front-to-back order, so the
    /// first match is the one the user is actually looking at.
    private func frontmostWindow(at point: CGPoint, in windows: [SCWindow]) -> SCWindow? {
        let ownPID = ProcessInfo.processInfo.processIdentifier

        return windows.first { window in
            // Layer 0 is the ordinary app-window layer. Anything above it is
            // menu bar items, the Dock, tooltips, screen-saver panels — none of
            // which is what "the window I'm pointing at" means.
            window.windowLayer == 0
                && window.isOnScreen
                && window.frame.contains(point)
                // Never photograph our own panel back to the phone.
                && window.owningApplication?.processID != ownPID
                // Skip slivers: title-bar-only ghosts and 1px helper windows.
                && window.frame.width >= 40
                && window.frame.height >= 40
        }
    }

    private func describe(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName
        let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (app, title) {
        case let (app?, title?) where !title.isEmpty:
            return "\(app) — \(title)"
        case let (app?, _):
            return app
        case let (_, title?) where !title.isEmpty:
            return title
        default:
            return "Window"
        }
    }

    private func backingScale(for window: SCWindow, in displays: [SCDisplay]) -> CGFloat {
        let host = displays.first { $0.frame.intersects(window.frame) } ?? displays.first
        guard let host, host.frame.width > 0 else { return 2 }
        return CGFloat(host.width) / host.frame.width
    }

    /// Whole-display capture, used when the pointer isn't over a window.
    private func captureDisplay(containing point: CGPoint?) async throws -> CaptureResult {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )

        // Pick the display the pointer is on, so a two-monitor setup doesn't
        // silently return the wrong screen.
        let display = point.flatMap { location in
            content.displays.first { $0.frame.contains(location) }
        } ?? content.displays.first

        guard let display else { throw CaptureError.noDisplayAvailable }

        let configuration = SCStreamConfiguration()
        configuration.captureResolution = .best
        configuration.showsCursor = false
        configuration.width = display.width
        configuration.height = display.height

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: []
            ),
            configuration: configuration
        )
        return CaptureResult(image: image, source: "Whole screen")
    }

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

    /// Captures the window under the pointer and packages it for the iPhone.
    ///
    /// A Retina window capture is still several megapixels of PNG, far more than
    /// a phone preview needs, so it's downscaled and JPEG-encoded first.
    ///
    /// - Parameters:
    ///   - maxDimension: Longest edge of the transmitted image, in pixels.
    ///   - quality: JPEG quality, 0–1.
    func captureForTransport(maxDimension: Int = 1400, quality: Double = 0.7) async throws -> Screenshot {
        let result = try await captureWindowUnderCursor()
        let scaled = downscale(result.image, maxDimension: maxDimension)

        guard let data = encodeJPEG(scaled, quality: quality) else {
            throw CaptureError.encodingFailed
        }

        logger.notice(
            "Captured \(result.image.width, privacy: .public)×\(result.image.height, privacy: .public) → \(data.count / 1024, privacy: .public) KB"
        )

        return Screenshot(
            imageData: data,
            width: scaled.width,
            height: scaled.height,
            sourceWidth: result.image.width,
            sourceHeight: result.image.height,
            source: result.source,
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
