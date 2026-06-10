import AppKit
@preconcurrency import ApplicationServices

// MARK: - Selection Service
// Reads the selected text of the frontmost app.
// 1. Accessibility API (AXSelectedText) — works for native AppKit apps.
// 2. Fallback: simulate ⌘C and read the clipboard — works almost everywhere
//    (browsers, Electron apps like VS Code / 飞书 / 微信 / Slack / Notion),
//    then restores the user's original clipboard.
// Returns nil when nothing is selected.

enum SelectionService {

    @MainActor
    static func selectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }

        // 1) Try the Accessibility API first (fast, no clipboard side effects)
        if let ax = axSelectedText(), !ax.isEmpty {
            print("[PunkType] 🔎 Selection via AX (\(ax.count) chars)")
            return ax
        }

        // 2) Fall back to ⌘C → read clipboard → restore
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

        // Restore the user's original clipboard.
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
                if let data = item.data(forType: type) {
                    copy[type] = data
                }
            }
            return copy
        }
    }

    private static func restorePasteboard(_ pb: NSPasteboard, items: [[NSPasteboard.PasteboardType: Data]]) {
        guard !items.isEmpty else { return }
        pb.clearContents()
        let restored = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pb.writeObjects(restored)
    }
}
