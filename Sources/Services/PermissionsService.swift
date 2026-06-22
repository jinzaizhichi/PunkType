import AVFoundation
import Speech
import AppKit
@preconcurrency import ApplicationServices

// MARK: - Permissions Service
// Status + request helpers for the three permissions PunkType needs, plus deep
// links into the right System Settings panes (used by the onboarding window).

enum PermissionsService {

    enum Status { case granted, denied, notDetermined }

    // MARK: Status

    static func microphone() -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    static func speech() -> Status {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    @MainActor static func accessibility() -> Status {
        AXIsProcessTrusted() ? .granted : .denied
    }

    // MARK: Requests

    static func requestMicrophone(_ completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func requestSpeech(_ completion: @escaping @Sendable (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    @MainActor static func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: System Settings deep links

    static func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    static let micPane = "Privacy_Microphone"
    static let speechPane = "Privacy_SpeechRecognition"
    static let accessibilityPane = "Privacy_Accessibility"

    /// True only when all three are granted.
    @MainActor static var allGranted: Bool {
        microphone() == .granted && speech() == .granted && accessibility() == .granted
    }
}
