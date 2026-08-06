import Testing
import Foundation
@testable import RelayAirCore

/// The wire contract for describing fields.
///
/// Both ends of this ship independently — a phone on the App Store keeps talking
/// to whatever Mac build the user has. So the tests that earn their place are the
/// ones about a new field arriving at an old reader, and an old message arriving
/// at a new one.
@Suite("Form snapshot wire format")
struct FormSnapshotWireTests {

    private func roundTrip(_ message: RelayMessage) throws -> RelayMessage {
        try RelayMessage.decode(message.encoded())
    }

    @Test("Asking for the field list survives the trip")
    func listCommandRoundTrips() throws {
        let message = RelayMessage.command(.listFormFields)
        #expect(try roundTrip(message) == message)
    }

    @Test("A snapshot survives the trip intact")
    func snapshotRoundTrips() throws {
        let snapshot = FormSnapshot(
            fields: [
                FormField(
                    id: "ax-0",
                    label: "Email address",
                    semanticType: .email,
                    confidence: 0.95,
                    role: "AXTextField",
                    isRequired: true,
                    frame: FieldFrame(x: 120, y: 340, width: 280, height: 24)
                ),
                FormField(
                    id: "ax-1",
                    label: "Password",
                    semanticType: .password,
                    confidence: 0.98,
                    role: "AXTextField",
                    isSecure: true,
                    isRequired: true
                )
            ],
            source: .accessibility,
            appName: "Safari",
            windowTitle: "Sign in",
            url: "https://example.com/login",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let decoded = try roundTrip(.response(.formFields(snapshot), id: UUID()))
        guard case .response(.formFields(let result)) = decoded.payload else {
            Issue.record("Payload changed shape in transit")
            return
        }
        #expect(result == snapshot)
        #expect(result.fields[1].isSecure)
        #expect(result.url == "https://example.com/login")
    }

    @Test("A targeted fill survives the trip")
    func targetedFillRoundTrips() throws {
        let request = FillRequest(text: "hunter2", followUp: .return, target: "ax-1")
        let decoded = try roundTrip(.command(.fill(request)))
        guard case .command(.fill(let result)) = decoded.payload else {
            Issue.record("Payload changed shape in transit")
            return
        }
        #expect(result.target == "ax-1")
        #expect(result.followUp == .return)
    }

    @Test("A fill from a phone that predates targeting still decodes")
    func untargetedFillIsBackwardCompatible() throws {
        // Exactly what an older build puts on the wire: no `target` key at all.
        let json = Data("""
        {"text":"hello","strategy":"automatic","followUp":"none"}
        """.utf8)

        let request = try JSONDecoder().decode(FillRequest.self, from: json)
        #expect(request.text == "hello")
        #expect(request.target == nil, "A missing target must mean 'type into focus', not a failure")
    }

    @Test("Every semantic type has a stable wire name and can be read back")
    func semanticTypesRoundTrip() throws {
        for type in SemanticFieldType.allCases {
            let encoded = try JSONEncoder().encode(type)
            #expect(try JSONDecoder().decode(SemanticFieldType.self, from: encoded) == type)
            #expect(!type.displayName.isEmpty)
            #expect(!type.symbolName.isEmpty)
        }
    }

    @Test("An empty snapshot is a real answer, not an error")
    func emptySnapshotIsValid() throws {
        let snapshot = FormSnapshot(
            fields: [],
            source: .accessibility,
            appName: "Preview",
            capturedAt: Date()
        )
        #expect(snapshot.isEmpty)
        #expect(snapshot.contextDescription == "Preview")

        let decoded = try roundTrip(.response(.formFields(snapshot), id: UUID()))
        guard case .response(.formFields(let result)) = decoded.payload else {
            Issue.record("Payload changed shape in transit")
            return
        }
        #expect(result.isEmpty)
    }

    @Test("The window context reads sensibly however much of it is known")
    func contextDescription() {
        func snapshot(app: String?, window: String?) -> FormSnapshot {
            FormSnapshot(
                fields: [], source: .accessibility,
                appName: app, windowTitle: window, capturedAt: Date()
            )
        }
        #expect(snapshot(app: "Safari", window: "Sign in").contextDescription == "Safari — Sign in")
        #expect(snapshot(app: "Safari", window: "").contextDescription == "Safari")
        #expect(snapshot(app: "Safari", window: nil).contextDescription == "Safari")
        #expect(snapshot(app: nil, window: "Sign in").contextDescription == "Sign in")
        #expect(snapshot(app: nil, window: nil).contextDescription == "Unknown window")
    }

    @Test("Listing fields is not a handshake command")
    func listingRequiresAuthentication() {
        // Anything that isn't a handshake is refused until the device has proved
        // itself, so this one property is what keeps the field list private.
        #expect(!RelayCommand.listFormFields.isHandshake)
        #expect(RelayCommand.listFormFields.displayName == "List fields")
    }
}
