import AppKit
@preconcurrency import ApplicationServices

// MARK: - Selection Service
// Reads the selected text of the frontmost app. Called ONLY from the explicit
// command hotkey (⌥⌘S) — never from plain dictation — so the ⌘C fallback's cost
// (a synthesized copy + up to ~0.4s wait + clipboard churn) is only paid when
// the user deliberately asks for command mode, and a lingering selection can
// never turn a normal dictation into a slow command.
//
// 1. Accessibility API (AXSelectedText) — instant, works for native apps.
// 2. Fallback: simulate ⌘C and read the clipboard — works almost everywhere
//    (browsers, Electron: 飞书 / VS Code / Slack …), then restores the clipboard.

enum SelectionService {

    @MainActor
    static func selectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }

        if let ax = axSelectedText(), !ax.isEmpty {
            print("[PunkType] 🔎 Selection via AX (\(ax.count) chars)")
            return ax
        }
        if let copied = clipboardSelectedText(), !copied.isEmpty {
            print("[PunkType] 🔎 Selection via ⌘C (\(copied.count) chars)")
            return copied
        }
        print("[PunkType] 🔎 No selection detected")
        return nil
    }

    // MARK: - Accessibility API

    @MainActor
    private static func axSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 1.0) // never hang on a slow app

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else { return nil }

        let focused = focusedRef as! AXUIElement
        AXUIElementSetMessagingTimeout(focused, 1.0)

        var selectionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectionRef
        ) == .success, let text = selectionRef as? String else { return nil }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - ⌘C fallback

    @MainActor
    private static func clipboardSelectedText() -> String? {
        let pb = NSPasteboard.general
        let savedChangeCount = pb.changeCount
        let savedItems = savePasteboard(pb)

        sendCommandC()

        // Wait briefly for the host app to put the selection on the clipboard.
        var copied: String?
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            if pb.changeCount != savedChangeCount {
                copied = pb.string(forType: .string)
                break
            }
            usleep(15_000)
        }

        restorePasteboard(pb, items: savedItems)
        return copied?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sendCommandC() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let cKey: CGKeyCode = 0x08
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    // MARK: - Clipboard save / restore

    private static func savePasteboard(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pb.pasteboardItems ?? []).map { item in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { copy[type] = data }
            }
            return copy
        }
    }

    private static func restorePasteboard(_ pb: NSPasteboard, items: [[NSPasteboard.PasteboardType: Data]]) {
        guard !items.isEmpty else { return }
        pb.clearContents()
        let restored = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(restored)
    }
}
