import Foundation

/// The three steps of *Send. Approve. Fill.*
///
/// Shared so the iPhone's onboarding list and the Mac's menu bar describe the
/// same flow in the same words.
public enum RelayStep: Int, CaseIterable, Identifiable, Sendable {
    case send = 1
    case approve = 2
    case fill = 3

    public var id: Int { rawValue }
    public var number: Int { rawValue }

    public var title: String {
        switch self {
        case .send: "Send"
        case .approve: "Approve"
        case .fill: "Fill"
        }
    }

    /// Long-form description, for the iPhone's explanation list.
    ///
    /// Approval lives on the phone, before anything is transmitted. Once the
    /// Mac receives a transfer it acts on it — the decision has already been
    /// made, and a second prompt on the Mac would just be the same question
    /// asked twice.
    public var detail: String {
        switch self {
        case .send: "Choose what to relay from this iPhone."
        case .approve: "Confirm the transfer before anything leaves this device."
        case .fill: "The Mac types it into the focused field, straight away."
        }
    }

    public var symbol: String {
        switch self {
        case .send: "paperplane"
        case .approve: "checkmark.shield"
        case .fill: "cursorarrow.rays"
        }
    }
}

/// Where the Mac is in the relay, at any moment.
///
/// This is what the menu bar reports. `RelayController` advances it as commands
/// arrive over the link and as the user approves or rejects them.
public enum RelayState: Equatable, Sendable {
    /// Not listening. The user switched the relay off.
    case paused
    /// Listening for a send from the iPhone.
    case waiting
    /// Typing an approved transfer in. Step 3.
    case filling
    /// The last attempt failed; carries a reason for the menu.
    case failed(String)

    /// The step this state belongs to, if any.
    public var step: RelayStep? {
        switch self {
        case .paused, .failed: nil
        case .waiting: .send
        case .filling: .fill
        }
    }

    /// Short line for the menu bar.
    public var statusText: String {
        switch self {
        case .paused: "Paused"
        case .waiting: "Ready"
        case .filling: "Filling…"
        case .failed(let reason): reason
        }
    }

    /// SF Symbol for the menu bar item and the status row.
    public var symbol: String {
        switch self {
        case .paused: "pause.circle"
        case .failed: "exclamationmark.triangle"
        case .waiting, .filling: step?.symbol ?? "paperplane"
        }
    }

    public var isActive: Bool {
        self != .paused
    }
}
