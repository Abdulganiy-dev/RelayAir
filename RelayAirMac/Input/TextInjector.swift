import CoreGraphics
import AppKit
import OSLog
import RelayAirCore

/// Types text into whatever application currently has keyboard focus.
///
/// Two routes:
///
/// | Route | Speed | Compatibility |
/// |---|---|---|
/// | ``paste(_:)`` | fast | almost everything; the pasteboard is saved and restored |
/// | ``type(_:)`` | slow | everything, including fields that validate each keystroke |
///
/// Both need the **Accessibility** permission. Posting a `CGEvent` without it
/// fails silently — no error, no crash, nothing happens — which is the most
/// common cause of "why isn't it typing".
@MainActor
final class TextInjector {

    private let logger = Logger(subsystem: AppIdentifiers.loggingSubsystem, category: "TextInjector")

    /// Delay between synthesised keystrokes. Too fast and apps drop characters.
    private let keystrokeDelay: Duration = .milliseconds(6)
    /// How long to wait for the target app to read the pasteboard before restoring it.
    private let pasteboardRestoreDelay: Duration = .milliseconds(250)

    // MARK: - Entry point

    /// Fulfils `request` against the focused field.
    @discardableResult
    func perform(_ request: FillRequest) async -> Bool {
        let succeeded: Bool

        switch request.strategy {
        case .pasteboard:
            succeeded = await paste(request.text)
        case .synthesizedTyping:
            succeeded = await type(request.text)
        case .automatic:
            // `||` can't short-circuit across an async call, so spell it out.
            if await paste(request.text) {
                succeeded = true
            } else {
                succeeded = await type(request.text)
            }
        }

        guard succeeded else {
            logger.error("Fill failed using strategy \(request.strategy.rawValue, privacy: .public)")
            return false
        }

        switch request.followUp {
        case .none: break
        case .tab: await pressKey(.tab)
        case .return: await pressKey(.return)
        }

        return true
    }

    // MARK: - Route 1: pasteboard + ⌘V

    /// Copies `text`, sends ⌘V, then restores the previous pasteboard contents.
    @discardableResult
    func paste(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let saved = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }

        let sent = await pressKey(.v, modifiers: .maskCommand)

        try? await Task.sleep(for: pasteboardRestoreDelay)
        restorePasteboard(saved, to: pasteboard)

        return sent
    }

    /// Captures every representation on the pasteboard so restoring it is lossless.
    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { contents[type] = data }
            }
            return contents
        }
    }

    private func restorePasteboard(
        _ snapshot: [[NSPasteboard.PasteboardType: Data]],
        to pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: - Route 2: synthesised typing

    /// Types `text` as Unicode key events.
    @discardableResult
    func type(_ text: String) async -> Bool {
        guard let source = makeSource() else { return false }

        // Chunked because very long strings can overflow a single event's buffer.
        for chunk in text.chunked(into: 20) {
            var utf16 = Array(chunk.utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return false }

            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            try? await Task.sleep(for: keystrokeDelay)
        }
        return true
    }

    // MARK: - Key events

    /// Virtual key codes. Values are from `Carbon/Events.h`.
    enum Key: CGKeyCode {
        case `return` = 36
        case tab = 48
        case space = 49
        case escape = 53
        case delete = 51
        case a = 0
        case v = 9
        case c = 8
    }

    /// Posts a key down/up pair, optionally with modifiers held.
    @discardableResult
    func pressKey(_ key: Key, modifiers: CGEventFlags = []) async -> Bool {
        guard let source = makeSource(),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false)
        else { return false }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        try? await Task.sleep(for: keystrokeDelay)
        return true
    }

    /// Selects everything in the focused field, so the next fill replaces it.
    @discardableResult
    func selectAll() async -> Bool {
        await pressKey(.a, modifiers: .maskCommand)
    }

    /// Moves focus to the next field.
    @discardableResult
    func focusNextField() async -> Bool {
        await pressKey(.tab)
    }

    private func makeSource() -> CGEventSource? {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("Could not create CGEventSource")
            return nil
        }
        // Don't let the user's held-down modifiers leak into our synthetic events.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        return source
    }
}

private extension String {
    /// Splits into substrings of at most `size` characters.
    func chunked(into size: Int) -> [String] {
        guard size > 0, count > size else { return isEmpty ? [] : [self] }
        var chunks: [String] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[index..<end]))
            index = end
        }
        return chunks
    }
}
