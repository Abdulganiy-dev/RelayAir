import Foundation

/// Something the iPhone asks the Mac to do.
public enum RelayCommand: Codable, Hashable, Sendable {
    /// Liveness check.
    case ping
    /// Capture the Mac's screen and send back a preview.
    case captureScreen
    /// Type text into whatever the Mac has focused. Goes through the Mac's
    /// approval gate before anything is typed.
    case fill(FillRequest)

    public var displayName: String {
        switch self {
        case .ping: "Ping"
        case .captureScreen: "Capture screen"
        case .fill: "Fill text"
        }
    }
}

/// What the Mac sends back.
public enum RelayResponse: Codable, Hashable, Sendable {
    case pong
    /// The command was received and is waiting on the user's approval.
    case awaitingApproval
    /// The command completed with nothing to return.
    case done
    case screenshot(Screenshot)
    case failed(String)
}

/// A screen capture, downscaled and JPEG-encoded for the trip over the wire.
public struct Screenshot: Codable, Hashable, Sendable {
    /// JPEG data, ready to hand to `UIImage`/`NSImage`.
    public var imageData: Data
    /// Pixel dimensions of the transmitted image, after downscaling.
    public var width: Int
    public var height: Int
    /// Pixel dimensions of the original capture, before downscaling.
    public var sourceWidth: Int
    public var sourceHeight: Int
    public var capturedAt: Date

    public init(
        imageData: Data,
        width: Int,
        height: Int,
        sourceWidth: Int,
        sourceHeight: Int,
        capturedAt: Date
    ) {
        self.imageData = imageData
        self.width = width
        self.height = height
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.capturedAt = capturedAt
    }

    public var byteCount: Int { imageData.count }
}

/// Wire envelope. The `id` lets a sender match a response to the command that
/// caused it, so several commands can be in flight at once.
public struct RelayMessage: Codable, Hashable, Sendable {
    public enum Payload: Codable, Hashable, Sendable {
        case command(RelayCommand)
        case response(RelayResponse)
    }

    public var id: UUID
    public var payload: Payload

    public init(id: UUID = UUID(), payload: Payload) {
        self.id = id
        self.payload = payload
    }

    public static func command(_ command: RelayCommand, id: UUID = UUID()) -> RelayMessage {
        RelayMessage(id: id, payload: .command(command))
    }

    public static func response(_ response: RelayResponse, id: UUID) -> RelayMessage {
        RelayMessage(id: id, payload: .response(response))
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> RelayMessage {
        try JSONDecoder().decode(RelayMessage.self, from: data)
    }
}
