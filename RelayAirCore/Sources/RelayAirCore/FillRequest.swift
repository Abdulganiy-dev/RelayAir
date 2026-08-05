import Foundation

/// An instruction to type text into whatever the Mac currently has focused.
///
/// This is the seam where the iPhone's approved payload meets the Mac's typing.
public struct FillRequest: Codable, Hashable, Sendable {
    /// How the text should reach the field.
    public enum Strategy: String, Codable, Sendable {
        /// Put the text on the pasteboard and send ⌘V, restoring the previous
        /// contents afterwards. Fast, and works nearly everywhere.
        case pasteboard
        /// Synthesise per-character key events. Slower, but the only option for
        /// fields that validate individual keystrokes.
        case synthesizedTyping
        /// Try `pasteboard`, then fall back to `synthesizedTyping`.
        case automatic
    }

    /// Key to send once the text has landed.
    public enum FollowUp: String, Codable, Sendable {
        case none
        case tab
        case `return`
    }

    public var text: String
    public var strategy: Strategy
    public var followUp: FollowUp

    public init(text: String, strategy: Strategy = .automatic, followUp: FollowUp = .none) {
        self.text = text
        self.strategy = strategy
        self.followUp = followUp
    }
}
