import AppKit
@preconcurrency import ApplicationServices

// MARK: - Focus Service
// Decides whether to auto-paste at the cursor or show the result panel, by
// combining two signals:
//
//  1. Frontmost app (always reliable): did the user switch away while the AI
//     was working? If so → panel.
//  2. Accessibility focused-element role (reliable only when the app exposes
//     it): is the focus on an editable field, a non-text control, or unknown?
//
// Bias: only pop the panel when we're CONFIDENT there's nowhere to paste
// (switched apps, or AX positively reports a non-text focus). When AX can't
// tell — terminals, Electron — we paste, because a false panel during normal
// dictation is more annoying than occasionally pasting into a no-op (the text
// is also saved to history and the clipboard).

enum FocusService {

    enum FocusState { case editable, nonEditable, unknown }

    @MainActor
    static func frontmostPID() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    @MainActor
    static func editableFocusState() -> FocusState {
        guard AXIsProcessTrusted() else { return .unknown }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else {
            return .unknown // app doesn't expose focus → don't pop on this alone
        }

        let element = focusedRef as! AXUIElement

        // Editable signals
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String

        let editableRoles: Set<String> = [
            "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField",
        ]
        if let role, editableRoles.contains(role) { return .editable }

        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
           settable.boolValue {
            return .editable
        }
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success {
            return .editable
        }

        // Positively non-editable controls
        // Only roles that are clearly not text entry. Deliberately excludes
        // AXWebArea / AXScrollArea — those can host editable text and would
        // cause false panels in browsers and editors.
        let nonEditableRoles: Set<String> = [
            "AXButton", "AXImage", "AXMenuItem", "AXMenuButton",
            "AXCheckBox", "AXRadioButton", "AXSlider", "AXLink",
            "AXStaticText", "AXMenuBar", "AXMenuBarItem",
            "AXList", "AXOutline", "AXTable",
        ]
        if let role, nonEditableRoles.contains(role) { return .nonEditable }

        return .unknown
    }
}
