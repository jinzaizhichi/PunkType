import SwiftUI
import AppKit
import Carbon
import AVFoundation
import Speech
@preconcurrency import ApplicationServices

// MARK: - App Entry Point

@main
struct PunkTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var historyManager = HistoryManager.shared
    @ObservedObject private var settings = Settings.shared

    var body: some Scene {
        MenuBarExtra("PunkType", systemImage: appDelegate.isRecording ? "mic.fill.badge.ellipsis" : "mic.fill") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(appDelegate.isRecording ? Color.red : Color.green)
                        .frame(width: 6, height: 6)
                    Text(appDelegate.statusText)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                Divider()

                Button(action: { appDelegate.toggleRecording() }) {
                    HStack {
                        Image(systemName: appDelegate.isRecording ? "stop.circle" : "mic.circle")
                        Text(appDelegate.isRecording ? "停止录音" : "开始录音（\(settings.hotkeyPreset.label)）")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

                // Output tier
                Divider()

                Text("输出档位")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)

                ForEach(Settings.tiers, id: \.self) { tier in
                    Button(action: { settings.tier = tier }) {
                        HStack {
                            Image(systemName: settings.tier == tier ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(settings.tier == tier ? .accentColor : .secondary)
                            Text(Settings.tierLabels[tier] ?? tier)
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                }

                if !appDelegate.lastResult.isEmpty {
                    Divider()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appDelegate.lastResult, forType: .string)
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("复制上次结果")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }

                // History section
                if !historyManager.entries.isEmpty {
                    Divider()

                    Text("历史")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 2)

                    ForEach(historyManager.entries.prefix(5)) { entry in
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.cleanedText, forType: .string)
                        }) {
                            HStack {
                                Text(entry.preview)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Text(entry.timeAgo)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                    }

                    if historyManager.entries.count > 5 {
                        Text("还有 \(historyManager.entries.count - 5) 条 — 在「设置 → 历史」查看")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                }

                Divider()

                Button(action: { appDelegate.openSettings() }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("设置…")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut(",", modifiers: [.command])
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

                Divider()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack {
                        Image(systemName: "power")
                        Text("退出")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut("q", modifiers: [.command])
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .padding(.bottom, 4)
            }
            .frame(width: 240)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var hotKeyRef: EventHotKeyRef?
    private var settingsWindow: NSWindow?
    private var overlayPanel: NSPanel?

    /// Drives the floating overlay independently of the (localizable) status text.
    enum OverlayPhase { case hidden, listening, processing, done }

    @Published var isRecording = false
    @Published var statusText = "准备就绪"
    @Published var overlayPhase: OverlayPhase = .hidden
    @Published var lastResult: String = ""
    @Published var audioLevel: Float = 0

    /// Frontmost app PID captured when recording started — used to detect
    /// whether the user switched away before the result was ready.
    private var recordingFrontmostPID: pid_t?

    /// Selected text captured when recording started → command mode
    private var commandTarget: String?

    let settings = Settings.shared
    private(set) var speechRecognizer: any SpeechTranscribing = SpeechRecognizer(locale: Settings.shared.language)
    private var activeEngineKey = ""

    /// (Re)build the speech engine for the active tier's STT choice.
    /// "apple-fast" → SpeechAnalyzer; "local"/"whisper" → SFSpeech (which also
    /// writes the WAV that the Whisper upload path needs).
    private func ensureRecognizer() {
        let engine = settings.sttEngine(for: settings.tier)
        let useModern = engine == "apple-fast"
        let key = "\(useModern)|\(settings.language)"
        guard key != activeEngineKey else { return }
        activeEngineKey = key
        if useModern, #available(macOS 26.0, *) {
            speechRecognizer = ModernSpeechRecognizer(localeIdentifier: settings.language)
            print("[PunkType] 🎙️ Engine: SpeechAnalyzer (\(settings.language))")
        } else {
            speechRecognizer = SpeechRecognizer(locale: settings.language)
            print("[PunkType] 🎙️ Engine: SFSpeechRecognizer (\(settings.language))")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotkeyHandler()
        registerHotkey()

        // Trigger system Accessibility prompt once (silent if already granted)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Global Hotkey

    private func setupHotkeyHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let target = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(ptr).takeUnretainedValue()
                Task { @MainActor in
                    delegate.toggleRecording()
                }
                return noErr
            },
            1,
            &eventType,
            target,
            nil
        )
    }

    /// (Re)register the global hotkey from the current settings preset.
    func registerHotkey() {
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }

        let preset = settings.hotkeyPreset
        let hotKeyID = EventHotKeyID(signature: 0x70756E6B, id: 1)
        RegisterEventHotKey(
            preset.keyCode,
            preset.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        print("[PunkType] ⌨️ Hotkey registered: \(preset.label)")
    }

    // MARK: - Overlay Window

    private func showOverlay() {
        if overlayPanel == nil {
            let overlay = RecordingOverlay(appDelegate: self)
            let hosting = NSHostingController(rootView: overlay)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 240, height: 56),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hosting
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
            panel.hidesOnDeactivate = false

            overlayPanel = panel
        }

        // Bottom center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = overlayPanel!.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.minY + 60
            overlayPanel?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        overlayPanel?.orderFront(nil)
    }

    private func hideOverlay(after seconds: Double = 1.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.overlayPanel?.orderOut(nil)
        }
    }

    // MARK: - Command Result Panel

    private var commandPanel: NSPanel?

    /// Command-mode result → panel where paste means "替换原文".
    private func showCommandResult(instruction: String, result: String) {
        showResultPanel(
            title: "处理结果",
            subtitle: instruction.isEmpty ? "" : "指令：\(instruction)",
            result: result,
            pasteLabel: "替换原文"
        )
    }

    /// Show a text result in a floating, non-activating panel so the host app
    /// keeps focus (so the paste button can land in it after you click back).
    private func showResultPanel(title: String, subtitle: String, result: String, pasteLabel: String) {
        closeCommandResult()

        let view = CommandResultView(
            title: title,
            subtitle: subtitle,
            result: result,
            pasteLabel: pasteLabel,
            onPaste: { [weak self] in
                self?.closeCommandResult()
                // Give focus a beat to settle back on the host field, then paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    _ = PasteService.copyAndPaste(result)
                }
            },
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
                self?.statusText = "已复制"
                self?.closeCommandResult()
            },
            onClose: { [weak self] in
                self?.closeCommandResult()
            }
        )

        let panelSize = NSSize(width: 460, height: 380)
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.setContentSize(panelSize)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false

        // Position: centered, slightly below screen center so it's easy to read
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        commandPanel = panel
    }

    private func closeCommandResult() {
        commandPanel?.orderOut(nil)
        commandPanel = nil
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // 极速档不走 LLM，无 key 也能用；其余档位需要 DeepSeek key
        if settings.tier != "fast" && !settings.isConfigured {
            showAlert(message: "Please configure your DeepSeek API Key in Settings first.")
            return
        }

        ensureRecognizer()

        // Remember where we started so we can tell if the user switches away.
        recordingFrontmostPID = FocusService.frontmostPID()

        // Command mode: text selected in the host app → speak an instruction
        commandTarget = settings.isConfigured ? SelectionService.selectedText() : nil

        isRecording = true
        overlayPhase = .listening
        if let target = commandTarget {
            let preview = String(target.prefix(10))
            statusText = "已选中「\(preview)\(target.count > 10 ? "…" : "")」说出指令"
        } else {
            statusText = "聆听中…"
        }
        showOverlay()

        // Wire up live audio level for waveform
        speechRecognizer.onAudioLevel = { @Sendable [weak self] level in
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        do {
            try speechRecognizer.startRecording()
        } catch {
            isRecording = false
            overlayPhase = .hidden
            statusText = "出错了"
            overlayPanel?.orderOut(nil)
            showAlert(message: error.localizedDescription)
        }
    }

    private func stopRecording() {
        isRecording = false
        overlayPhase = .processing
        statusText = "AI 处理中…"

        speechRecognizer.stopRecording { @Sendable [weak self] rawText in
            Task { @MainActor in
                guard let self else { return }
                await self.handleTranscription(localText: rawText)
            }
        }
    }

    // MARK: - STT result → Whisper upgrade/fallback → process

    private func handleTranscription(localText: String) async {
        var text = localText

        // 当前档选了 Whisper 时优先用 Whisper；本机识别为空时也兜底 Whisper
        let preferWhisper = settings.sttEngine(for: settings.tier) == "whisper"
        if settings.hasOpenAIKey,
           preferWhisper || text.isEmpty,
           let audioURL = speechRecognizer.lastAudioURL,
           FileManager.default.fileExists(atPath: audioURL.path) {
            statusText = "转写中…"
            do {
                let whisperText = try await OpenAIService.transcribe(
                    audioURL: audioURL,
                    apiKey: settings.openaiKey,
                    model: settings.openaiModel
                )
                if !whisperText.isEmpty {
                    text = whisperText
                }
            } catch {
                print("[PunkType] ⚠️ Whisper failed, using local text: \(error.localizedDescription)")
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = "未检测到语音"
            overlayPhase = .hidden
            overlayPanel?.orderOut(nil)
            commandTarget = nil
            return
        }

        await processAndPaste(trimmed)
    }

    // MARK: - Tier pipeline + Paste

    private func processAndPaste(_ rawText: String) async {
        statusText = "AI 处理中…"
        let dictionary = DictionaryStore.shared
        let target = commandTarget
        commandTarget = nil

        var output = rawText
        var usedModel = "raw"

        // Command mode is handled separately: the result is shown in a panel
        // (with 复制 / 替换原文 / 关闭) instead of being blindly pasted, because
        // the selection is often in a read-only place.
        if let target {
            var prompt = settings.commandPrompt
            if settings.injectGlossary, let glossary = dictionary.commandGlossary {
                prompt += glossary
            }
            do {
                let result = try await DeepSeekService.command(
                    instruction: rawText,
                    selectedText: target,
                    apiKey: settings.apiKey,
                    model: settings.heavyModel,
                    prompt: prompt,
                    endpoint: settings.apiEndpoint
                )
                self.lastResult = result
                overlayPhase = .hidden
                overlayPanel?.orderOut(nil)
                statusText = "准备就绪"
                showCommandResult(instruction: rawText, result: result)
                HistoryManager.shared.add(
                    cleanedText: result,
                    rawText: "指令：\(rawText)",
                    model: settings.heavyModel
                )
                if settings.injectGlossary, settings.isConfigured {
                    extractTermsInBackground(from: result)
                }
            } catch {
                print("[PunkType] ❌ Command failed: \(error.localizedDescription)")
                overlayPhase = .hidden
                statusText = "命令失败"
                hideOverlay(after: 1.0)
            }
            return
        }

        // Streaming path (per-tier): type the cleaned text into the cursor as it
        // streams, for lower perceived latency. Only when there's a confident
        // paste target up front; otherwise fall through to the normal path.
        if settings.stream(for: settings.tier), settings.tier != "fast", settings.isConfigured {
            let switchedAway = recordingFrontmostPID == nil
                || FocusService.frontmostPID() != recordingFrontmostPID
            let canType = !switchedAway && FocusService.editableFocusState() != .nonEditable
            if canType, await streamAndType(rawText, dictionary: dictionary) {
                return
            }
        }

        // Normal dictation: 极速 / 润色 / 格式 → auto-paste at cursor
        do {
            switch settings.tier {
            case "fast":
                break // raw transcription as-is
            case "format":
                var prompt = settings.formatPrompt
                if settings.injectGlossary, let glossary = dictionary.correctionGlossary {
                    prompt += glossary
                }
                let m = settings.model(for: "format")
                output = try await DeepSeekService.cleanup(
                    text: rawText,
                    apiKey: settings.apiKey,
                    model: m,
                    prompt: prompt,
                    endpoint: settings.apiEndpoint,
                    maxTokens: 2048,
                    timeout: 30
                )
                usedModel = m
            default: // polish
                var prompt = settings.systemPrompt
                if settings.injectGlossary, let glossary = dictionary.correctionGlossary {
                    prompt += glossary
                }
                let m = settings.model(for: "polish")
                output = try await DeepSeekService.cleanup(
                    text: rawText,
                    apiKey: settings.apiKey,
                    model: m,
                    prompt: prompt,
                    endpoint: settings.apiEndpoint
                )
                usedModel = m
            }
        } catch {
            // 清理失败 → 退回原始转写
            print("[PunkType] ⚠️ Cleanup failed, pasting raw: \(error.localizedDescription)")
            output = rawText
            usedModel = "raw (fallback)"
        }

        self.lastResult = output

        // Save to history regardless of where the text lands
        HistoryManager.shared.add(
            cleanedText: output,
            rawText: rawText,
            model: usedModel
        )
        // 异步抽词入库（不阻塞出字）
        if settings.injectGlossary, settings.isConfigured {
            extractTermsInBackground(from: output)
        }

        // Decide: paste at the cursor, or show the result in a panel?
        // Pop the panel only when we're confident there's nowhere to paste:
        //   • the user switched to a different app/desktop, OR
        //   • the same app reports focus on a clearly non-text control.
        // Otherwise (editable, or can't tell) → paste.
        let switchedAway = recordingFrontmostPID == nil
            || FocusService.frontmostPID() != recordingFrontmostPID
        let noTextHere = FocusService.editableFocusState() == .nonEditable
        guard !switchedAway && !noTextHere else {
            print("[PunkType] 📋 No paste target (switchedAway=\(switchedAway), noTextHere=\(noTextHere)) — showing panel")
            overlayPhase = .hidden
            overlayPanel?.orderOut(nil)
            statusText = "准备就绪"
            showResultPanel(
                title: "转写结果（未找到输入框）",
                subtitle: "点回输入框后可「插入到光标」，或直接复制",
                result: output,
                pasteLabel: "插入到光标"
            )
            return
        }

        let pasteStatus = PasteService.copyAndPaste(output)
        print("[PunkType] 📋 \(pasteStatus): \(output.prefix(50))...")
        self.statusText = pasteStatus
        self.overlayPhase = .done

        // Auto-dismiss overlay
        hideOverlay(after: 1.5)

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if self.overlayPhase == .done {
            self.statusText = "准备就绪"
            self.overlayPhase = .hidden
        }
    }

    /// Stream the cleaned text and type it at the cursor as tokens arrive.
    /// Returns true if it handled output; false if it should fall back to the
    /// normal (non-streaming) path (e.g. failed before any token).
    private func streamAndType(_ rawText: String, dictionary: DictionaryStore) async -> Bool {
        let isFormat = settings.tier == "format"
        var prompt = isFormat ? settings.formatPrompt : settings.systemPrompt
        if settings.injectGlossary, let glossary = dictionary.correctionGlossary {
            prompt += glossary
        }
        let model = settings.model(for: settings.tier)

        statusText = "AI 处理中…"
        var typed = ""
        do {
            let stream = DeepSeekService.streamCleanup(
                text: rawText,
                apiKey: settings.apiKey,
                model: model,
                prompt: prompt,
                endpoint: settings.apiEndpoint,
                maxTokens: isFormat ? 2048 : 1024
            )
            for try await delta in stream {
                if typed.isEmpty {
                    // First token arrived — clear the overlay so typing is visible
                    overlayPhase = .hidden
                    overlayPanel?.orderOut(nil)
                }
                typed += delta
                TypeService.insert(delta)
            }
        } catch {
            print("[PunkType] ⚠️ Streaming failed after \(typed.count) chars: \(error.localizedDescription)")
            if typed.isEmpty { return false } // nothing typed → safe to fall back
        }

        guard !typed.isEmpty else { return false }

        let output = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastResult = output
        self.statusText = "已粘贴 ✓"
        HistoryManager.shared.add(cleanedText: output, rawText: rawText, model: model)
        if settings.injectGlossary {
            extractTermsInBackground(from: output)
        }

        try? await Task.sleep(nanoseconds: 1_200_000_000)
        if self.statusText == "已粘贴 ✓" { self.statusText = "准备就绪" }
        return true
    }

    // MARK: - Dictionary post-processing

    private func extractTermsInBackground(from text: String) {
        let apiKey = settings.apiKey
        let model = settings.modelPolish // background extraction uses the light model
        let endpoint = settings.apiEndpoint
        Task {
            do {
                let terms = try await DeepSeekService.extractTerms(
                    from: text,
                    apiKey: apiKey,
                    model: model,
                    endpoint: endpoint
                )
                guard !terms.isEmpty else { return }
                await MainActor.run {
                    DictionaryStore.shared.merge(terms: terms)
                }
            } catch {
                print("[PunkType] ⚠️ Term extraction failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Settings Window

    func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
            .environmentObject(self)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "PunkType Settings"
        window.setContentSize(NSSize(width: 520, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Alerts

    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "PunkType"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}
