import Foundation
import Network
import CryptoKit
import OSLog

/// One authenticated TLS connection, with length-prefixed message framing.
///
/// Framing: a 4-byte big-endian payload length, then that many bytes of JSON.
/// TCP is a byte stream with no notion of message boundaries, so without this
/// two commands sent back-to-back can arrive coalesced in a single read.
final class RelayConnection {

    /// Refuse anything larger than this. A full-screen JPEG runs a few hundred
    /// KB; the ceiling exists so a hostile or corrupt length prefix can't make
    /// us allocate gigabytes.
    static let maxMessageBytes = 16 * 1024 * 1024

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "RelayConnection")

    /// Called on the connection's queue when a complete message arrives.
    var onMessage: ((RelayMessage) -> Void)?
    /// Called once, when the connection becomes usable.
    var onReady: (() -> Void)?
    /// Called once, when the connection ends for any reason.
    var onClose: ((Error?) -> Void)?

    private var hasClosed = false

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    /// Wraps an outbound connection to `endpoint`, authenticated with `secret`.
    convenience init(to endpoint: NWEndpoint, secret: SymmetricKey, queue: DispatchQueue) {
        self.init(
            connection: NWConnection(to: endpoint, using: .relayAir(secret: secret)),
            queue: queue
        )
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.logger.notice("Connection ready")
                self.onReady?()
                self.receiveNextMessage()
            case .failed(let error):
                self.close(error: error)
            case .cancelled:
                self.close(error: nil)
            case .waiting(let error):
                // Usually "no route to host" while the peer is still coming up.
                self.logger.debug("Connection waiting: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        connection.cancel()
    }

    // MARK: - Sending

    func send(_ message: RelayMessage, completion: ((Error?) -> Void)? = nil) {
        let body: Data
        do {
            body = try message.encoded()
        } catch {
            completion?(error)
            return
        }

        guard body.count <= Self.maxMessageBytes else {
            completion?(RelayLink.LinkError.messageTooLarge(body.count))
            return
        }

        var framed = Data(capacity: body.count + 4)
        withUnsafeBytes(of: UInt32(body.count).bigEndian) { framed.append(contentsOf: $0) }
        framed.append(body)

        connection.send(content: framed, completion: .contentProcessed { error in
            completion?(error)
        })
    }

    // MARK: - Receiving

    private func receiveNextMessage() {
        // Exact 4-byte read: min == max means Network waits for the whole header.
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error { self.close(error: error); return }
            guard let data, data.count == 4 else {
                if isComplete { self.close(error: nil) }
                return
            }

            let length = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian)
            guard length > 0, length <= Self.maxMessageBytes else {
                self.close(error: RelayLink.LinkError.messageTooLarge(length))
                return
            }
            self.receiveBody(length: length)
        }
    }

    private func receiveBody(length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error { self.close(error: error); return }
            guard let data, data.count == length else {
                if isComplete { self.close(error: nil) }
                return
            }

            if let message = try? RelayMessage.decode(data) {
                self.onMessage?(message)
            } else {
                self.logger.error("Dropped an undecodable message of \(length, privacy: .public) bytes")
            }

            // Keep the loop going for the next message on this connection.
            self.receiveNextMessage()
        }
    }

    private func close(error: Error?) {
        guard !hasClosed else { return }
        hasClosed = true
        connection.cancel()
        onClose?(error)
    }
}

// MARK: - TLS with a pre-shared key

extension NWParameters {

    /// TCP + TLS parameters authenticated by the pairing secret.
    ///
    /// This is where QR pairing turns into real security. The secret becomes a
    /// TLS pre-shared key, so a peer that never scanned the code **cannot
    /// complete the handshake** — it is rejected during TLS negotiation, before
    /// any application data exists. Encryption alone (what MultipeerConnectivity
    /// gave us) protects the bytes but says nothing about who is on the far end.
    static func relayAir(secret: SymmetricKey) -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2
        tcp.noDelay = true

        let parameters = NWParameters(tls: tlsOptions(secret: secret), tcp: tcp)
        // Allows AWDL / peer-to-peer Wi-Fi, so the two devices can talk even
        // without a shared router.
        parameters.includePeerToPeer = true
        return parameters
    }

    private static func tlsOptions(secret: SymmetricKey) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()

        // Derive the PSK rather than using the QR bytes directly, so the raw
        // pairing secret is never the literal key material on the wire.
        let derived = HMAC<SHA256>.authenticationCode(
            for: Data(RelayProtocol.pskLabel.utf8),
            using: secret
        )
        let keyData = derived.withUnsafeBytes { DispatchData(bytes: $0) }
        let identityData = Data(RelayProtocol.pskIdentity.utf8)
            .withUnsafeBytes { DispatchData(bytes: $0) }

        sec_protocol_options_add_pre_shared_key(
            options.securityProtocolOptions,
            keyData as __DispatchData,
            identityData as __DispatchData
        )

        // TLS_PSK_WITH_AES_128_GCM_SHA256 (RFC 5487). PSK suites must be
        // requested explicitly; they are not in the default set.
        if let suite = tls_ciphersuite_t(rawValue: 0x00A8) {
            sec_protocol_options_append_tls_ciphersuite(options.securityProtocolOptions, suite)
        }

        return options
    }
}

/// Protocol-level constants shared by both ends.
enum RelayProtocol {
    /// Domain-separation label for the PSK derivation.
    static let pskLabel = "RelayAir-PSK-v1"
    /// TLS PSK identity hint. Not a secret.
    static let pskIdentity = "relayair"
}
