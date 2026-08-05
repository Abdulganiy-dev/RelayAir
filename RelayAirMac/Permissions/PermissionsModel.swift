import Foundation
import Observation
import OSLog
import RelayAirCore

/// Observable view of Relay Air's permission state.
///
/// TCC changes arrive without any notification, so the state is polled while the
/// app is running. The interval is deliberately slow — this exists to notice a
/// user flipping a switch in System Settings, not to be a hot loop.
@MainActor
@Observable
final class PermissionsModel {

    /// Permissions currently granted.
    private(set) var granted: Set<SystemPermission> = []

    /// Permissions whose system prompt we have already triggered. macOS shows
    /// each prompt at most once per app identity, so after this the UI must send
    /// the user to System Settings instead of re-prompting.
    private(set) var requested: Set<SystemPermission> = []

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "Permissions")
    private var pollTask: Task<Void, Never>?
    private let pollInterval: Duration = .seconds(1)

    init() {
        granted = Set(SystemPermission.allCases.filter(\.isGranted))
    }

    // MARK: - Queries

    func isGranted(_ permission: SystemPermission) -> Bool {
        granted.contains(permission)
    }

    /// Whether the app can actually perform this capability right now.
    func isAvailable(_ capability: Capability) -> Bool {
        isGranted(capability.permission)
    }

    var availableCapabilities: [Capability] {
        Capability.allCases.filter(isAvailable)
    }

    /// Every permission is in place.
    var isFullyPermitted: Bool {
        granted.count == SystemPermission.allCases.count
    }

    /// Nothing works at all without Accessibility, so it gets its own flag.
    var canControlInput: Bool {
        isGranted(.accessibility)
    }

    // MARK: - Polling

    func startPolling() {
        guard pollTask == nil else { return }
        // `self` is captured weakly, so the loop also exits if the model is
        // released without `stopPolling()` being called.
        pollTask = Task { [weak self, pollInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() {
        let current = Set(SystemPermission.allCases.filter(\.isGranted))
        guard current != granted else { return }

        for permission in current.subtracting(granted) {
            logger.notice("\(permission.rawValue, privacy: .public) granted")
        }
        for permission in granted.subtracting(current) {
            logger.notice("\(permission.rawValue, privacy: .public) revoked")
        }
        granted = current
    }

    // MARK: - Requests

    /// Shows the system prompt, or opens System Settings if the prompt has
    /// already been used up.
    func request(_ permission: SystemPermission) {
        guard !isGranted(permission) else {
            permission.openSettings()
            return
        }

        guard !requested.contains(permission) else {
            permission.openSettings()
            return
        }

        requested.insert(permission)

        guard permission.requestBlocks else {
            permission.request()
            refresh()
            return
        }

        Task.detached(priority: .userInitiated) {
            permission.request()
            await MainActor.run { [weak self] in self?.refresh() }
        }
    }

    func openSettings(for permission: SystemPermission) {
        permission.openSettings()
    }
}
