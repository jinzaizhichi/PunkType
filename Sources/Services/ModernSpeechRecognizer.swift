import Speech
@preconcurrency import AVFoundation
import Accelerate

// MARK: - Modern Speech Recognizer (macOS 26 SpeechAnalyzer)
// Uses Apple's SpeechAnalyzer + SpeechTranscriber, which run on-device and are
// markedly faster than the classic SFSpeechRecognizer. Falls back to the older
// engine on macOS 25 and earlier (see AppDelegate engine selection).

@available(macOS 26.0, *)
final class ModernSpeechRecognizer: NSObject, SpeechTranscribing, @unchecked Sendable {

    nonisolated(unsafe) var onAudioLevel: (@Sendable (Float) -> Void)?
    nonisolated(unsafe) private(set) var lastAudioURL: URL?

    private let audioEngine = AVAudioEngine()
    private let locale: Locale
    private let lock = NSLock()

    nonisolated(unsafe) private var transcriber: SpeechTranscriber?
    nonisolated(unsafe) private var analyzer: SpeechAnalyzer?
    nonisolated(unsafe) private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    nonisolated(unsafe) private var analyzerFormat: AVAudioFormat?
    nonisolated(unsafe) private var converter: AVAudioConverter?
    nonisolated(unsafe) private var resultsTask: Task<Void, Never>?
    nonisolated(unsafe) private var audioFile: AVAudioFile?

    nonisolated(unsafe) private var finalText = ""
    nonisolated(unsafe) private var volatileText = ""

    init(localeIdentifier: String) {
        self.locale = Locale(identifier: localeIdentifier)
        super.init()
    }

    // Synchronous lock helpers (NSLock.lock() can't be called in async scope)
    private func resetText() { lock.lock(); finalText = ""; volatileText = ""; lock.unlock() }
    private func appendFinal(_ t: String) { lock.lock(); finalText += t; volatileText = ""; lock.unlock() }
    private func setVolatile(_ t: String) { lock.lock(); volatileText = t; lock.unlock() }
    private func snapshotText() -> String {
        lock.lock(); defer { lock.unlock() }
        return finalText.isEmpty ? volatileText : finalText
    }

    func startRecording() throws {
        print("[PunkType] ▶️ Modern startRecording()")
        resetText()

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        // Collect results (volatile = live partials, final = committed)
        resultsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.appendFinal(text)
                    } else {
                        self.setVolatile(text)
                    }
                }
            } catch {
                print("[PunkType] Modern results error: \(error)")
            }
        }

        // Async setup: ensure model assets, pick format, start analyzer, tap mic
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.ensureModelInstalled(for: transcriber)
                let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
                self.analyzerFormat = format

                let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
                self.inputContinuation = continuation
                try await analyzer.start(inputSequence: stream)
                try self.startAudioCapture()
            } catch {
                print("[PunkType] ❌ Modern setup failed: \(error)")
            }
        }
    }

    func stopRecording(completion: @escaping @Sendable (String) -> Void) {
        print("[PunkType] ⏹ Modern stopRecording()")
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioFile = nil
        inputContinuation?.finish()

        Task { [weak self] in
            guard let self else { completion(""); return }
            try? await self.analyzer?.finalizeAndFinishThroughEndOfInput()
            // Give the results stream a brief moment to drain the final result.
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.resultsTask?.cancel()

            let text = self.snapshotText()

            self.cleanup()
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Audio

    private func startAudioCapture() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        if let analyzerFormat, analyzerFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        }

        // WAV copy for optional Whisper fallback
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PunkType-modern.wav")
        try? FileManager.default.removeItem(at: wavURL)
        var fileSettings = inputFormat.settings
        fileSettings[AVFormatIDKey] = kAudioFormatLinearPCM
        fileSettings[AVLinearPCMBitDepthKey] = 16
        fileSettings[AVLinearPCMIsFloatKey] = false
        audioFile = try? AVAudioFile(
            forWriting: wavURL,
            settings: fileSettings,
            commonFormat: inputFormat.commonFormat,
            interleaved: inputFormat.isInterleaved
        )
        lastAudioURL = audioFile != nil ? wavURL : nil

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.audioFile?.write(from: buffer)

            // Level meter
            if let channelData = buffer.floatChannelData {
                var rms: Float = 0
                vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(buffer.frameLength))
                self.onAudioLevel?(min(rms * 8.0, 1.0))
            }

            // Feed analyzer (convert format if needed)
            if let out = self.convert(buffer) {
                self.inputContinuation?.yield(AnalyzerInput(buffer: out))
            }
        }

        try audioEngine.start()
        print("[PunkType] ✅ Modern audio started")
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let analyzerFormat else { return buffer }
        guard let converter else { return buffer } // formats already match
        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return nil }
        let consumed = ConsumeFlag()
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed.value {
                status.pointee = .noDataNow
                return nil
            }
            consumed.value = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }

    /// Reference box so the converter input block's one-shot flag isn't a
    /// captured `var` in concurrent code.
    private final class ConsumeFlag {
        var value = false
    }

    // MARK: - Model assets

    private func ensureModelInstalled(for transcriber: SpeechTranscriber) async throws {
        let installed = await Set(SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
        if installed.contains(locale.identifier(.bcp47)) { return }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            print("[PunkType] ⬇️ Downloading speech model for \(locale.identifier)…")
            try await request.downloadAndInstall()
        }
    }

    private func cleanup() {
        inputContinuation = nil
        analyzer = nil
        transcriber = nil
        converter = nil
        audioFile = nil
    }
}
