import Foundation
import Network
import Observation
import OSLog

/// Which end of the link this is.
public enum RelayRole: Sendable {
    /// The Mac. Advertises over Bonjour and answers commands.
    case listener
    /// The iPhone. Browses for the paired Mac and sends commands.
    case client
}

/// The iPhone ↔ Mac link, over Network.framework.
///
/// - Discovery is Bonjour (`_relayair._tcp`), with peer-to-peer Wi-Fi enabled so
///   the two devices don't strictly need a router.
/// - Every connection is TLS with a pre-shared key derived from the QR pairing
///   secret, so only the paired device can complete a handshake.
/// - Messages are length-prefixed JSON — see ``RelayConnection``.
///
/// Both apps need Local Network access: `NSLocalNetworkUsageDescription` and
/// `NSBonjourServices` in Info.plist. There is no API to read that permission's
/// state, so a refusal looks like "never finds a peer" rather than an error.
@MainActor
@Observable
public final class RelayLink {

    public enum State: Equatable, Sendable {
        /// Not started.
        case idle
        /// Started, but no pairing exists yet — scan a QR code first.
        case unpaired
        /// Mac: advertising and waiting for the iPhone.
        case advertising
        /// iPhone: looking for the paired Mac.
        case searching
        case connecting
        /// TLS is up; the device is proving which device it is.
        case authenticating
        case connected(peerName: String)
        case failed(String)

        public var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        public var description: String {
            switch self {
            case .idle: "Not running"
            case .unpaired: "Not paired yet"
            case .advertising: "Waiting for your iPhone"
            case .searching: "Looking for your Mac…"
            case .connecting: "Connecting…"
            case .authenticating: "Verifying this device…"
            case .connected(let name): "Connected to \(name)"
            case .failed(let reason): reason
            }
        }
    }

    /// What the Mac consults to decide whether a device may connect.
    ///
    /// Implemented by the Mac app over its enrolled-device list. Revoking is
    /// deleting the record, after which ``key(for:)`` returns `nil` and the
    /// device's proofs stop verifying.
    @MainActor
    public protocol DeviceAuthority: AnyObject {
        /// The stored key for `deviceID`, or `nil` if unknown or revoked.
        func key(for deviceID: UUID) -> Data?
        /// Whether the Mac is currently showing its QR and accepting new devices.
        var isAcceptingNewDevices: Bool { get }
        /// Records a new device and returns the credential to hand back.
        func enroll(name: String) -> DeviceCredential?
        /// Notes that a known device just connected.
        func markSeen(deviceID: UUID, name: String)
    }

    public enum LinkError: LocalizedError, Equatable {
        case notConnected
        case notPaired
        case timedOut
        /// The TLS handshake never completed — almost always a secret mismatch.
        case handshakeFailed
        case messageTooLarge(Int)
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case .notConnected: "No device is connected."
            case .notPaired: "These devices aren't paired yet."
            case .timedOut: "The Mac didn't answer in time."
            case .handshakeFailed: "Couldn't verify that Mac. Re-scan the pairing code."
            case .messageTooLarge(let bytes): "That message is too large (\(bytes) bytes)."
            case .transport(let detail): detail
            }
        }
    }

    public private(set) var state: State = .idle

    /// Listener side. Called for each incoming command once the device has
    /// authenticated; the returned response goes back to the sender.
    public var commandHandler: (@MainActor (RelayCommand) async -> RelayResponse)?

    /// Listener side. Decides which devices may connect.
    public weak var authority: (any DeviceAuthority)?

    /// Client side. Called when the Mac issues a credential, so the phone can
    /// persist it.
    public var onEnrolled: (@MainActor (DeviceCredential) -> Void)?

    private let role: RelayRole
    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "RelayLink")
    private let queue = DispatchQueue(label: "com.ladulghanneey.RelayAir.link")

    private var pairing: PairingPayload?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: RelayConnection?

    /// Client side: this phone's credential and name.
    private var credential: DeviceCredential?
    private var deviceName: String = "iPhone"

    /// Listener side: whether the peer on the current connection has proved
    /// itself. Reset for every new connection.
    private var isPeerAuthenticated = false

    /// Commands sent and still waiting on a matching response.
    private var pending: [UUID: CheckedContinuation<RelayResponse, Error>] = [:]

    public init(role: RelayRole) {
        self.role = role
    }

    // MARK: - Lifecycle

    /// Starts advertising (Mac) or browsing (iPhone) using `pairing`.
    ///
    /// - Parameters:
    ///   - credential: Client side. `nil` on a phone that hasn't enrolled yet,
    ///     which makes the first connection an enrolment.
    ///   - deviceName: Client side. Shown in the Mac's device list.
    public func start(
        pairing: PairingPayload?,
        credential: DeviceCredential? = nil,
        deviceName: String = "iPhone"
    ) {
        stop()

        guard let pairing else {
            state = .unpaired
            return
        }
        self.pairing = pairing
        self.credential = credential
        self.deviceName = deviceName

        switch role {
        case .listener: startListening(pairing)
        case .client: startBrowsing(pairing)
        }
    }

    /// Tears everything down and fails anything in flight.
    public func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        isPeerAuthenticated = false

        failAllPending(with: LinkError.notConnected)
        state = .idle
    }

    /// Drops the current connection without tearing down discovery, so a
    /// revoked device is disconnected immediately rather than at its next
    /// reconnect.
    public func disconnectPeer() {
        connection?.cancel()
    }

    // MARK: - Listener (Mac)

    private func startListening(_ pairing: PairingPayload) {
        do {
            let listener = try NWListener(using: .relayAir(secret: pairing.symmetricKey))
            listener.service = NWListener.Service(
                name: pairing.serviceName,
                type: AppIdentifiers.bonjourServiceType
            )

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.state = .advertising
                        self.logger.notice("Advertising as \(pairing.serviceName, privacy: .public)")
                    case .failed(let error):
                        self.state = .failed(error.localizedDescription)
                        self.logger.error("Listener failed: \(error.localizedDescription, privacy: .public)")
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] newConnection in
                Task { @MainActor [weak self] in
                    self?.accept(newConnection)
                }
            }

            listener.start(queue: queue)
            self.listener = listener
            state = .advertising
        } catch {
            state = .failed(error.localizedDescription)
            logger.error("Couldn't create listener: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func accept(_ nwConnection: NWConnection) {
        // One phone at a time. A second connection replaces the first rather
        // than racing it.
        connection?.cancel()

        let peerName = pairing?.displayName ?? "iPhone"
        let relayConnection = RelayConnection(connection: nwConnection, queue: queue)
        attach(relayConnection, peerName: peerName)
        relayConnection.start()
        state = .connecting
    }

    // MARK: - Client (iPhone)

    private func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func startBrowsing(_ pairing: PairingPayload) {
        stopBrowsing()

        let browser = NWBrowser(
            for: .bonjour(type: AppIdentifiers.bonjourServiceType, domain: nil),
            using: .relayAir(secret: pairing.symmetricKey)
        )

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .failed(let error) = state {
                    self.state = .failed(error.localizedDescription)
                    self.logger.error("Browser failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
        state = .searching
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        // Only ever connect to the exact instance named in the QR code.
        guard connection == nil, let pairing else { return }

        let match = results.first { result in
            if case .service(let name, _, _, _) = result.endpoint {
                return name == pairing.serviceName
            }
            return false
        }

        guard let match else { return }

        logger.notice("Found \(pairing.serviceName, privacy: .public)")
        let relayConnection = RelayConnection(
            to: match.endpoint,
            secret: pairing.symmetricKey,
            queue: queue
        )
        attach(relayConnection, peerName: pairing.displayName)
        relayConnection.start()
        state = .connecting
    }

    // MARK: - Shared connection handling

    private func attach(_ relayConnection: RelayConnection, peerName: String) {
        isPeerAuthenticated = false

        relayConnection.onReady = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch self.role {
                case .listener:
                    // Wait for the phone to prove itself before reporting a
                    // usable connection.
                    self.state = .authenticating
                case .client:
                    // We've found the Mac; browsing on would keep multicasting
                    // mDNS queries for the whole session.
                    self.stopBrowsing()
                    self.state = .authenticating
                    await self.performHandshake(peerName: peerName)
                }
            }
        }

        relayConnection.onMessage = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handle(message)
            }
        }

        relayConnection.onClose = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.logger.notice("Connection closed: \(error.localizedDescription, privacy: .public)")
                }
                self.connection = nil
                self.isPeerAuthenticated = false
                self.failAllPending(with: error ?? LinkError.notConnected)

                // A failed handshake means the secret is wrong, and retrying
                // will fail identically — say so instead of spinning forever.
                if case .handshakeFailed = error as? LinkError {
                    self.state = .failed(LinkError.handshakeFailed.localizedDescription)
                    return
                }

                // Anything else is treated as transient, so a phone that walks
                // out of range reconnects when it comes back.
                switch self.role {
                case .listener:
                    self.state = .advertising
                case .client:
                    // Browsing was stopped on connect; start looking again.
                    self.state = .searching
                    if let pairing = self.pairing {
                        self.startBrowsing(pairing)
                    }
                }
            }
        }

        connection = relayConnection
    }

    private func handle(_ message: RelayMessage) {
        switch message.payload {
        case .response(let response):
            guard let continuation = pending.removeValue(forKey: message.id) else { return }
            continuation.resume(returning: response)

        case .command(let command):
            logger.notice("Received \(command.displayName, privacy: .public)")

            if command.isHandshake {
                reply(handleHandshake(command), to: message.id)
                return
            }

            // Everything else requires a device that has proved itself.
            guard isPeerAuthenticated else {
                logger.error("Refused \(command.displayName, privacy: .public) from an unauthenticated device")
                reply(.failed("This device isn't authorised."), to: message.id)
                return
            }

            guard let commandHandler else {
                reply(.failed("This device doesn't handle commands."), to: message.id)
                return
            }
            Task { @MainActor in
                let response = await commandHandler(command)
                self.reply(response, to: message.id)
            }
        }
    }

    // MARK: - Handshake (listener side)

    /// Handles enrolment and authentication. Never delegates to
    /// `commandHandler` — the app doesn't get a say in who is allowed in.
    private func handleHandshake(_ command: RelayCommand) -> RelayResponse {
        guard let authority else {
            return .failed("This Mac isn't accepting connections.")
        }

        switch command {
        case .enroll(let deviceName):
            // New devices are only accepted while the user is looking at the
            // QR code — otherwise anyone holding the code could enrol silently
            // long after it was shown.
            guard authority.isAcceptingNewDevices else {
                logger.error("Refused enrolment from \(deviceName, privacy: .public): not in pairing mode")
                return .failed("This Mac isn't showing its pairing code. Open Relay Air on the Mac and try again.")
            }
            guard let credential = authority.enroll(name: deviceName) else {
                return .failed("The Mac couldn't save the new device.")
            }
            logger.notice("Enrolled \(deviceName, privacy: .public)")
            return .enrolled(credential)

        case .authenticate(let proof):
            let verdict = DeviceAuth.verify(proof, key: authority.key(for: proof.deviceID))
            switch verdict {
            case .valid:
                isPeerAuthenticated = true
                authority.markSeen(deviceID: proof.deviceID, name: proof.deviceName)
                state = .connected(peerName: proof.deviceName)
                logger.notice("Authenticated \(proof.deviceName, privacy: .public)")
                return .authenticated
            case .unknownDevice:
                logger.error("Rejected an unknown or revoked device")
                return .failed("This iPhone isn't paired with the Mac any more. Scan the code again.")
            case .badSignature:
                logger.error("Rejected a device with a bad signature")
                return .failed("Couldn't verify this iPhone.")
            case .staleTimestamp:
                logger.error("Rejected a device with a stale timestamp")
                return .failed("This iPhone's clock is too far out of step with the Mac.")
            }

        default:
            return .failed("Unexpected handshake command.")
        }
    }

    // MARK: - Handshake (client side)

    /// Enrols if needed, then proves this device's identity.
    private func performHandshake(peerName: String) async {
        do {
            if credential == nil {
                let response = try await sendRaw(.enroll(deviceName: deviceName), timeout: .seconds(20))
                guard case .enrolled(let issued) = response else {
                    state = .failed(reason(from: response) ?? "The Mac wouldn't enrol this iPhone.")
                    return
                }
                credential = issued
                onEnrolled?(issued)
            }

            guard let credential else {
                state = .failed("No credential to authenticate with.")
                return
            }

            let proof = DeviceAuth.makeProof(credential: credential, deviceName: deviceName)
            let response = try await sendRaw(.authenticate(proof), timeout: .seconds(20))
            guard case .authenticated = response else {
                state = .failed(reason(from: response) ?? "The Mac wouldn't verify this iPhone.")
                return
            }

            state = .connected(peerName: peerName)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func reason(from response: RelayResponse) -> String? {
        if case .failed(let detail) = response { return detail }
        return nil
    }

    // MARK: - Sending

    /// Sends `command` and waits for the matching response.
    ///
    /// - Parameter timeout: Screen captures need more headroom than a ping.
    @discardableResult
    public func send(
        _ command: RelayCommand,
        timeout: Duration = .seconds(20)
    ) async throws -> RelayResponse {
        guard pairing != nil else { throw LinkError.notPaired }
        // Only a fully connected link accepts app commands; the handshake uses
        // `sendRaw` because it runs before that point by definition.
        guard state.isConnected else { throw LinkError.notConnected }
        return try await sendRaw(command, timeout: timeout)
    }

    private func sendRaw(
        _ command: RelayCommand,
        timeout: Duration
    ) async throws -> RelayResponse {
        guard let connection else { throw LinkError.notConnected }

        let message = RelayMessage.command(command)

        return try await withCheckedThrowingContinuation { continuation in
            pending[message.id] = continuation

            connection.send(message) { [weak self] error in
                guard let error else { return }
                Task { @MainActor [weak self] in
                    self?.failPending(message.id, with: LinkError.transport(error.localizedDescription))
                }
            }

            // Nothing guarantees a reply, so every send gets a deadline.
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.failPending(message.id, with: LinkError.timedOut)
            }
        }
    }

    private func reply(_ response: RelayResponse, to id: UUID) {
        connection?.send(RelayMessage.response(response, id: id))
    }

    private func failPending(_ id: UUID, with error: Error) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: error)
    }

    private func failAllPending(with error: Error) {
        let waiting = pending
        pending.removeAll()
        for continuation in waiting.values {
            continuation.resume(throwing: error)
        }
    }
}
