import Foundation

// MARK: - Speech Transcribing
// Common interface so the app can swap between the classic SFSpeechRecognizer
// (SpeechRecognizer) and the macOS 26 SpeechAnalyzer engine
// (ModernSpeechRecognizer) without the call sites caring which is in use.

protocol SpeechTranscribing: AnyObject {
    /// Live mic level (0…1), ~per audio buffer, for the waveform overlay.
    var onAudioLevel: (@Sendable (Float) -> Void)? { get set }

    /// WAV of the last session on disk, for optional Whisper cloud fallback.
    var lastAudioURL: URL? { get }

    func startRecording() throws
    func stopRecording(completion: @escaping @Sendable (String) -> Void)
}
