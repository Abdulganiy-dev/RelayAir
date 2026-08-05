import Foundation

/// Something the iPhone asks the Mac to do.
public enum RelayCommand: Codable, Hashable, Sendable {
    /// First-time enrolment. Accepted only while the Mac is showing its QR.
    case enroll(deviceName: String)
    /// Proves which enrolled device this is. Must be the first command on
    /// every connection; nothing else is honoured until it succeeds.
    case authenticate(DeviceProof)
    /// Liveness check.
    case ping
    /// Capture the Mac's screen and send back a preview.
    case captureScreen
    /// Type text into whatever the Mac has focused. Already approved on the
    /// phone, so the Mac types it on arrival.
    case fill(FillRequest)

    /// Commands that are part of getting authenticated, rather than things a
    /// device asks for once it is.
    var isHandshake: Bool {
        switch self {
        case .enroll, .authenticate: true
        case .ping, .captureScreen, .fill: false
        }
    }

    public var displayName: String {
        switch self {
        case .enroll: "Enroll"
        case .authenticate: "Authenticate"
        case .ping: "Ping"
        case .captureScreen: "Capture screen"
        case .fill: "Fill text"
        }
    }
}

/// What the Mac sends back.
///
/// Responses are prompt: approval happened on the phone before the command was
/// sent, so the Mac acts on arrival rather than parking the reply while it waits
/// for a person.
public enum RelayResponse: Codable, Hashable, Sendable {
    case pong
    /// Enrolment succeeded; carries the credential the phone should keep.
    case enrolled(DeviceCredential)
    /// The device proved its identity and may now issue commands.
    case authenticated
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
    /// What was captured — "Safari — Apple", or "Whole screen" when the pointer
    /// wasn't over a window. Lets the phone show that the right thing was grabbed.
    public var source: String?
    public var capturedAt: Date

    public init(
        imageData: Data,
        width: Int,
        height: Int,
        sourceWidth: Int,
        sourceHeight: Int,
        source: String? = nil,
        capturedAt: Date
    ) {
        self.imageData = imageData
        self.width = width
        self.height = height
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.source = source
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
