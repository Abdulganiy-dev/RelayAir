import Testing
import Foundation
import Network
import CryptoKit
@testable import RelayAirCore

/// Proves the security property the whole QR-pairing design rests on: a device
/// without the pairing secret cannot open a connection, and is stopped during
/// the TLS handshake rather than being let in and refused afterwards.
///
/// These run over loopback with an explicit port, deliberately skipping Bonjour
/// so they exercise TLS-PSK and the framing alone.
@Suite("TLS pre-shared key", .serialized)
struct TLSPairingTests {

    private static let queue = DispatchQueue(label: "relayair.tests")

    /// Spins up a listener on an OS-assigned loopback port.
    private func startListener(
        secret: SymmetricKey,
        onConnection: @escaping (RelayConnection) -> Void
    ) throws -> (listener: NWListener, port: NWEndpoint.Port) {
        let listener = try NWListener(using: .relayAir(secret: secret), on: .any)

        listener.newConnectionHandler = { nwConnection in
            let connection = RelayConnection(connection: nwConnection, queue: Self.queue)
            onConnection(connection)
            connection.start()
        }

        let ready = Ready()
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.start(queue: Self.queue)

        guard ready.wait(timeout: .now() + 5), let port = listener.port else {
            listener.cancel()
            throw TestFailure.listenerNeverBecameReady
        }
        return (listener, port)
    }

    @Test("Matching secrets connect and exchange a message")
    func matchingSecretsSucceed() async throws {
        let secret = SymmetricKey(data: Data(repeating: 0x11, count: 32))

        // Listener echoes a pong for any command it receives.
        let held = Box<RelayConnection>()
        let (listener, port) = try startListener(secret: secret) { connection in
            held.value = connection
            connection.onMessage = { message in
                guard case .command = message.payload else { return }
                connection.send(RelayMessage.response(.pong, id: message.id))
            }
        }
        defer { listener.cancel() }

        let client = RelayConnection(
            to: .hostPort(host: "127.0.0.1", port: port),
            secret: secret,
            queue: Self.queue
        )
        defer { client.cancel() }

        let outbound = RelayMessage.command(.ping)
        let reply = Box<RelayMessage>()
        let gotReply = Ready()

        client.onReady = { client.send(outbound) }
        client.onMessage = { message in
            reply.value = message
            gotReply.signal()
        }
        client.start()

        #expect(gotReply.wait(timeout: .now() + 10), "No reply arrived over a correctly-paired link")
        #expect(reply.value?.id == outbound.id)
        if case .response(.pong) = reply.value?.payload {} else {
            Issue.record("Expected a pong, got \(String(describing: reply.value?.payload))")
        }
    }

    @Test("A mismatched secret never reaches the ready state")
    func mismatchedSecretIsRejected() async throws {
        let listenerSecret = SymmetricKey(data: Data(repeating: 0x11, count: 32))
        let attackerSecret = SymmetricKey(data: Data(repeating: 0x22, count: 32))

        // The listener would happily echo — if the handshake ever completed.
        let held = Box<RelayConnection>()
        let (listener, port) = try startListener(secret: listenerSecret) { connection in
            held.value = connection
            connection.onMessage = { message in
                connection.send(RelayMessage.response(.pong, id: message.id))
            }
        }
        defer { listener.cancel() }

        let attacker = RelayConnection(
            to: .hostPort(host: "127.0.0.1", port: port),
            secret: attackerSecret,
            queue: Self.queue
        )
        defer { attacker.cancel() }

        let becameReady = Ready()
        let closeError = Box<Error>()
        let closed = Ready()
        attacker.onReady = { becameReady.signal() }
        attacker.onClose = { error in
            closeError.value = error
            closed.signal()
        }
        // A short deadline keeps the test quick; the app uses the default.
        attacker.start(handshakeTimeout: .milliseconds(1500))

        #expect(
            !becameReady.wait(timeout: .now() + 3),
            "An unpaired peer completed the TLS handshake — the PSK is not being enforced"
        )
        // Network.framework parks a bad handshake in .waiting rather than
        // failing it, so the connection's own deadline is what ends it.
        #expect(closed.wait(timeout: .now() + 3), "The rejected connection should have closed")
        #expect(
            closeError.value as? RelayLink.LinkError == .handshakeFailed,
            "Expected handshakeFailed, got \(String(describing: closeError.value))"
        )
    }

    @Test("A near-miss secret is rejected too")
    func oneBitOffIsRejected() async throws {
        var wrongBytes = Data(repeating: 0x11, count: 32)
        wrongBytes[31] ^= 0x01

        let (listener, port) = try startListener(
            secret: SymmetricKey(data: Data(repeating: 0x11, count: 32))
        ) { _ in }
        defer { listener.cancel() }

        let client = RelayConnection(
            to: .hostPort(host: "127.0.0.1", port: port),
            secret: SymmetricKey(data: wrongBytes),
            queue: Self.queue
        )
        defer { client.cancel() }

        let becameReady = Ready()
        client.onReady = { becameReady.signal() }
        client.start(handshakeTimeout: .milliseconds(1500))

        #expect(!becameReady.wait(timeout: .now() + 3))
    }

    @Test("Length-prefix framing keeps back-to-back messages separate")
    func framingSeparatesMessages() async throws {
        let secret = SymmetricKey(data: Data(repeating: 0x33, count: 32))

        let held = Box<RelayConnection>()
        let received = Collector<RelayMessage>()
        let gotAll = Ready()

        let (listener, port) = try startListener(secret: secret) { connection in
            held.value = connection
            connection.onMessage = { message in
                if received.append(message) == 3 { gotAll.signal() }
            }
        }
        defer { listener.cancel() }

        let client = RelayConnection(
            to: .hostPort(host: "127.0.0.1", port: port),
            secret: secret,
            queue: Self.queue
        )
        defer { client.cancel() }

        // A tiny command, a large one, then a tiny one — sent without pausing,
        // so they will coalesce in the TCP stream if framing is wrong.
        let big = Screenshot(
            imageData: Data(repeating: 0x5A, count: 400_000),
            width: 100, height: 100, sourceWidth: 200, sourceHeight: 200,
            capturedAt: Date(timeIntervalSince1970: 0)
        )
        let messages = [
            RelayMessage.command(.ping),
            RelayMessage.response(.screenshot(big), id: UUID()),
            RelayMessage.command(.fill(FillRequest(text: "tail"))),
        ]

        client.onReady = { messages.forEach { client.send($0) } }
        client.start()

        #expect(gotAll.wait(timeout: .now() + 15), "Only \(received.count) of 3 messages arrived intact")
        #expect(received.values.map(\.id) == messages.map(\.id), "Messages arrived out of order or merged")
    }
}

// MARK: - Test helpers

private enum TestFailure: Error {
    case listenerNeverBecameReady
}

/// A one-shot signal usable from Network.framework's callback queue.
private final class Ready: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var signalled = false

    func signal() {
        lock.lock()
        defer { lock.unlock() }
        guard !signalled else { return }
        signalled = true
        semaphore.signal()
    }

    func wait(timeout: DispatchTime) -> Bool {
        semaphore.wait(timeout: timeout) == .success
    }
}

/// Keeps a reference alive across callbacks without tripping over concurrency.
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T?

    var value: T? {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); defer { lock.unlock() }; storage = newValue }
    }
}

private final class Collector<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [T] = []

    /// Appends and returns the new count.
    @discardableResult
    func append(_ item: T) -> Int {
        lock.lock()
        defer { lock.unlock() }
        storage.append(item)
        return storage.count
    }

    var values: [T] { lock.lock(); defer { lock.unlock() }; return storage }
    var count: Int { values.count }
}
