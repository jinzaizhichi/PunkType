import AppKit
@preconcurrency import ApplicationServices

// MARK: - Selection Service
// Reads the selected text of the frontmost app via the Accessibility API only.
//
// We deliberately do NOT use a ⌘C fallback: it actively copies on every
// recording and grabs any *lingering* selection (e.g. text still highlighted in
// a browser), which turned every dictation into a slow command. AX selection
// reflects the real current selection in native apps; when nothing is selected
// it returns empty → no command mode. Trade-off: command mode won't auto-trigger
// in apps that don't expose selection to AX (some Electron apps / terminals).

enum SelectionService {

    @MainActor
    static func selectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else { return nil }

        let focused = focusedRef as! AXUIElement

        var selectionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectionRef
        ) == .success, let text = selectionRef as? String else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
