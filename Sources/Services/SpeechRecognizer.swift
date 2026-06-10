import Speech
@preconcurrency import AVFoundation
import Accelerate

// MARK: - Speech Recognizer (macOS)
// AVAudioEngine tap feeds both the on-device SFSpeechRecognizer (streaming)
// and a WAV file on disk (for optional Whisper cloud transcription).
// stopRecording() waits for the recognizer's final result instead of
// returning the last partial, so the tail of the last sentence is not lost.

final class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate, @unchecked Sendable {
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private let lock = NSLock()

    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    nonisolated(unsafe) private var recognitionTask: SFSpeechRecognitionTask?
    nonisolated(unsafe) private var finalText = ""
    nonisolated(unsafe) private var completion: (@Sendable (String) -> Void)?
    nonisolated(unsafe) private var sessionEnded = false
    nonisolated(unsafe) private var session = 0
    nonisolated(unsafe) private var audioFile: AVAudioFile?
    nonisolated(unsafe) private(set) var lastAudioURL: URL?
    nonisolated(unsafe) var onAudioLevel: (@Sendable (Float) -> Void)?

    /// How long to wait for the recognizer's final result after stop before
    /// falling back to the last partial.
    private let finalResultTimeout: TimeInterval = 1.5

    init(locale: String = "zh-CN") {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))!
        super.init()
        speechRecognizer.delegate = self
    }

    func startRecording() throws {
        print("[PunkType] ▶️ startRecording()")
        recognitionTask?.cancel()
        recognitionTask = nil

        lock.lock()
        finalText = ""
        completion = nil
        sessionEnded = false
        session += 1
        let currentSession = session
        lock.unlock()

        // Setup recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("[PunkType] 📡 Format: \(recordingFormat)")

        // WAV copy of the session for optional Whisper transcription (16-bit PCM)
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PunkType-\(currentSession).wav")
        try? FileManager.default.removeItem(at: wavURL)
        var fileSettings = recordingFormat.settings
        fileSettings[AVFormatIDKey] = kAudioFormatLinearPCM
        fileSettings[AVLinearPCMBitDepthKey] = 16
        fileSettings[AVLinearPCMIsFloatKey] = false
        fileSettings[AVLinearPCMIsNonInterleaved] = false
        audioFile = try? AVAudioFile(
            forWriting: wavURL,
            settings: fileSettings,
            commonFormat: recordingFormat.commonFormat,
            interleaved: recordingFormat.isInterleaved
        )
        lastAudioURL = audioFile != nil ? wavURL : nil

        // Install tap for audio buffer + level monitoring + WAV capture
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            try? self.audioFile?.write(from: buffer)

            if let channelData = buffer.floatChannelData {
                let frameLength = Int(buffer.frameLength)
                var rms: Float = 0
                vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
                let normalized = min(rms * 8.0, 1.0)
                self.onAudioLevel?(normalized)
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            var isFinal = false
            if let result = result {
                self.finalText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            if error != nil || isFinal {
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                }
                self.deliverResult(forSession: currentSession)
            }
        }

        // Start engine — should be fast now because pre-warmed
        print("[PunkType] ▶️ audioEngine.start()...")
        try audioEngine.start()
        print("[PunkType] ✅ audioEngine started")
    }

    func stopRecording(completion: @escaping @Sendable (String) -> Void) {
        print("[PunkType] ⏹ stopRecording()")

        lock.lock()
        let currentSession = session
        if sessionEnded {
            // Recognition already finished (error or early final) — deliver immediately
            let text = finalText
            lock.unlock()
            completion(text)
            return
        }
        self.completion = completion
        lock.unlock()

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioFile = nil // closes the WAV file
        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        // Fallback: if the final result never arrives, deliver the last partial
        DispatchQueue.global().asyncAfter(deadline: .now() + finalResultTimeout) { [weak self] in
            self?.deliverResult(forSession: currentSession)
        }
    }

    /// Deliver the result exactly once per session.
    private func deliverResult(forSession expected: Int) {
        lock.lock()
        guard session == expected else {
            lock.unlock()
            return
        }
        sessionEnded = true
        let cb = completion
        completion = nil
        recognitionRequest = nil
        recognitionTask = nil
        audioFile = nil
        let text = finalText
        lock.unlock()

        if let cb {
            print("[PunkType] ✅ Final text delivered (\(text.count) chars)")
            cb(text)
        }
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            print("[PunkType] Speech recognizer became unavailable")
        }
    }
}
