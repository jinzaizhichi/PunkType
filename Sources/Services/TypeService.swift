import AppKit

// MARK: - Type Service
// Inserts text at the current cursor by synthesizing Unicode keyboard events
// (no clipboard involved). Used for streaming output, where we type each token
// delta as it arrives. Works for CJK and emoji via keyboardSetUnicodeString.

enum TypeService {

    @MainActor
    static func insert(_ text: String) {
        guard !text.isEmpty,
              let source = CGEventSource(stateID: .combinedSessionState) else { return }

        // keyboardSetUnicodeString has a bounded internal buffer; chunk to be safe.
        let units = Array(text.utf16)
        let chunkSize = 16
        var index = 0
        while index < units.count {
            let slice = Array(units[index ..< min(index + chunkSize, units.count)])
            postUnicode(slice, source: source)
            index += chunkSize
        }
    }

    private static func postUnicode(_ utf16: [UniChar], source: CGEventSource) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
