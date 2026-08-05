import Testing
import Foundation
@testable import RelayAirCore

@Suite("Pairing payload")
struct PairingTests {

    @Test("A generated pairing survives the QR round trip")
    func qrRoundTrip() throws {
        let original = PairingPayload.generate(displayName: "Abdul's MacBook Pro")
        let parsed = try PairingPayload.parse(original.qrURL.absoluteString)

        #expect(parsed == original)
        #expect(parsed.secret.count == 32)
        #expect(parsed.serviceName == original.serviceName)
    }

    @Test("Display names with spaces and punctuation survive encoding")
    func awkwardDisplayName() throws {
        let original = PairingPayload.generate(displayName: "Ana & Bo's Mac (work) — 15\"")
        let parsed = try PairingPayload.parse(original.qrURL.absoluteString)
        #expect(parsed.displayName == original.displayName)
    }

    @Test("Every generated pairing is distinct")
    func secretsAreUnique() {
        let payloads = (0..<50).map { _ in PairingPayload.generate(displayName: "Mac") }
        #expect(Set(payloads.map(\.secret)).count == 50)
        #expect(Set(payloads.map(\.serviceName)).count == 50)
    }

    @Test("The Bonjour instance name is DNS-safe")
    func serviceNameIsDNSSafe() {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz234567-")
        for _ in 0..<50 {
            let name = PairingPayload.generate(displayName: "Mac").serviceName
            #expect(name.allSatisfy { allowed.contains($0) })
            // Bonjour instance names must fit in 63 bytes.
            #expect(name.utf8.count <= 63)
        }
    }

    @Test("Non-Relay-Air QR codes are rejected")
    func rejectsForeignCodes() {
        #expect(throws: PairingPayload.ParseError.self) {
            try PairingPayload.parse("https://example.com")
        }
        #expect(throws: PairingPayload.ParseError.self) {
            try PairingPayload.parse("WIFI:S=CoffeeShop;T=WPA;P=hunter2;;")
        }
        #expect(throws: PairingPayload.ParseError.self) {
            try PairingPayload.parse("relayair://something-else?v=1")
        }
    }

    @Test("A future format version is refused rather than misread")
    func rejectsFutureVersion() throws {
        let payload = PairingPayload.generate(displayName: "Mac")
        let bumped = payload.qrURL.absoluteString.replacingOccurrences(of: "v=1", with: "v=99")
        #expect(throws: PairingPayload.ParseError.self) {
            try PairingPayload.parse(bumped)
        }
    }

    @Test("A truncated key is refused")
    func rejectsShortKey() {
        let short = Data(repeating: 7, count: 16).base64URLEncodedString()
        let url = "relayair://pair?v=1&s=relay-abcdef&n=Mac&k=\(short)"
        #expect(throws: PairingPayload.ParseError.self) {
            try PairingPayload.parse(url)
        }
    }

    @Test("base64url encoding is URL-safe and reversible")
    func base64URLRoundTrip() {
        for length in [1, 15, 16, 31, 32, 100] {
            let data = Data((0..<length).map { UInt8($0 % 256) })
            let encoded = data.base64URLEncodedString()
            #expect(!encoded.contains("+"))
            #expect(!encoded.contains("/"))
            #expect(!encoded.contains("="))
            #expect(Data(base64URLEncoded: encoded) == data)
        }
    }
}

@Suite("Wire messages")
struct RelayMessageTests {

    @Test("A command round-trips through JSON")
    func commandRoundTrip() throws {
        let message = RelayMessage.command(.captureScreen)
        let decoded = try RelayMessage.decode(message.encoded())
        #expect(decoded == message)
    }

    @Test("A response keeps the id of the command it answers")
    func responseCorrelates() throws {
        let command = RelayMessage.command(.captureScreen)
        let shot = Screenshot(
            imageData: Data(repeating: 0xAB, count: 128_000),
            width: 1400, height: 875,
            sourceWidth: 3456, sourceHeight: 2160,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let decoded = try RelayMessage.decode(
            RelayMessage.response(.screenshot(shot), id: command.id).encoded()
        )

        #expect(decoded.id == command.id)
        guard case .response(.screenshot(let received)) = decoded.payload else {
            Issue.record("Expected a screenshot payload")
            return
        }
        #expect(received.imageData == shot.imageData)
        #expect(received.sourceWidth == 3456)
    }

    @Test("Fill requests keep their strategy and follow-up key")
    func fillRoundTrip() throws {
        let request = FillRequest(text: "hunter2", strategy: .pasteboard, followUp: .return)
        let decoded = try RelayMessage.decode(RelayMessage.command(.fill(request)).encoded())
        guard case .command(.fill(let received)) = decoded.payload else {
            Issue.record("Expected a fill payload")
            return
        }
        #expect(received == request)
    }

    @Test("Garbage bytes fail to decode instead of crashing")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            try RelayMessage.decode(Data([0x00, 0xFF, 0x42]))
        }
    }
}
