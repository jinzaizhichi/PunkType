import AppKit
@preconcurrency import ApplicationServices

// MARK: - Paste Service
// Try multiple approaches: CGEvent (Maccy-style) → AppleScript → clipboard-only
// The user's original clipboard is saved before pasting and restored afterwards.

enum PasteService {

    @MainActor
    static func copyAndPaste(_ text: String) -> String {
        let pb = NSPasteboard.general

        // Without Accessibility, CGEvent posts are silently dropped — don't
        // pretend we pasted, and don't restore the clipboard (the user needs
        // our text to stay there for a manual ⌘V).
        guard AXIsProcessTrusted() else {
            pb.clearContents()
            pb.setString(text, forType: .string)
            print("[PunkType] ⚠️ Accessibility not granted — text left on clipboard")
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            return "Copied — ⌘V"
        }

        let savedItems = savePasteboard(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)
        let ourChangeCount = pb.changeCount

        let pasted = tryCGEventPaste() || tryAppleScriptPaste() || tryLegacyPaste()

        if pasted {
            print("[PunkType] ✅ Paste event posted")
            // Restore the user's clipboard after the target app consumed the paste.
            // Skip if the clipboard changed again in the meantime (user copied something).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if pb.changeCount == ourChangeCount {
                    restorePasteboard(pb, items: savedItems)
                }
            }
            return "Pasted ✓"
        }

        // All paste methods failed — leave our text on the clipboard for manual ⌘V
        print("[PunkType] ⚠️ All paste methods failed — on clipboard")
        return "Copied — ⌘V"
    }

    // MARK: - Clipboard save/restore

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
        print("[PunkType] ♻️ Clipboard restored")
    }

    // MARK: - Maccy-style CGEvent
    private static func tryCGEventPaste() -> Bool {
        let cmdFlag = CGEventFlags(rawValue: UInt64(CGEventFlags.maskCommand.rawValue) | 0x000008)
        let vKey: CGKeyCode = 0x09

        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return false }

        vDown.flags = cmdFlag
        vUp.flags = cmdFlag

        vDown.post(tap: .cgSessionEventTap)
        usleep(20000)
        vUp.post(tap: .cgSessionEventTap)

        return true
    }

    // MARK: - AppleScript keystroke
    private static func tryAppleScriptPaste() -> Bool {
        let script = "tell application \"System Events\" to keystroke \"v\" using command down"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        return error == nil
    }

    // MARK: - Legacy Cmd+V simulation
    private static func tryLegacyPaste() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        // Cmd down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else { return false }
        cmdDown.flags = .maskCommand
        cmdUp.flags = .maskCommand

        // V key
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else { return false }
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        cmdDown.post(tap: .cgSessionEventTap)
        usleep(10000)
        vDown.post(tap: .cgSessionEventTap)
        usleep(50000)
        vUp.post(tap: .cgSessionEventTap)
        usleep(10000)
        cmdUp.post(tap: .cgSessionEventTap)

        return true
    }
}
