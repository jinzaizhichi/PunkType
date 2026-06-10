# 🎙️ PunkType

[简体中文](README.md) · **English**

**Speak naturally. AI cleans it up. Auto-paste anywhere.**

PunkType is a macOS menu bar app: you speak → your Mac (or Whisper) transcribes → DeepSeek removes filler words and formats the text → it's pasted at your cursor. Free, open source, bring-your-own API key, nothing sent to any server of ours.

---

## Install

### Option 1: Download (recommended)

Grab the latest `PunkType-vX.X.X-macos.zip` from [Releases](https://github.com/punk2898/PunkType/releases), unzip, and drag `PunkType.app` into `/Applications`.

> **First launch**: right-click the app → **Open** → **Open** again, to get past Gatekeeper (the build is ad-hoc signed and not notarized).
> Or run: `xattr -dr com.apple.quarantine /Applications/PunkType.app`

### Option 2: Build from source

```bash
git clone https://github.com/punk2898/PunkType.git
cd PunkType
make app      # Builds PunkType.app
make install  # Installs to /Applications and launches
```

**Requirements:** macOS 14+ (Sonoma or later), Xcode Command Line Tools (`xcode-select --install`)

---

## Setup

1. Get a DeepSeek API Key at [platform.deepseek.com](https://platform.deepseek.com).
2. Launch PunkType (waveform icon in the menu bar).
3. Click the menu bar icon → **Settings**, paste your API key.
4. Grant first-run permissions when prompted:
   - **Microphone** — to record
   - **Speech Recognition** — for local transcription
   - **Accessibility** — for auto-paste & reading selected text (without it, text only goes to the clipboard)

---

## How to use

```
⌥ Space → Speak → Local/Whisper STT → DeepSeek cleanup → Auto-paste ✨
```

- **Dictation**: press `⌥ Space` in any text field, speak, press again to stop — the result is typed at your cursor.
- **Command mode**: select some text first, then press `⌥ Space` and speak an instruction ("summarize this", "translate to English", "make it more formal"). The result appears in a panel — **Copy** it or **Replace** the selection.

---

## Features

- 🎚️ **Three output tiers** — ⚡ Fast (raw transcription, zero wait) / ✨ Polish (cleanup) / 📄 Format (cleanup + auto-layout for emails, reports, meeting notes, todos)
- 🎯 **Command mode** — Select text in any app, speak an instruction, get the result in a panel to copy or replace the selection
- 📖 **Personal dictionary** — Terms, names, and product names are auto-extracted after each output (up to 300) and injected back into prompts to fix recognition errors. Editable in Settings.
- ☁️ **Whisper fallback** — Optional OpenAI cloud transcription: auto-upgrade on the Format tier, auto-fallback when local recognition fails
- 🚀 **Fast** — Local Apple Speech Recognition + DeepSeek Flash; heavy jobs (Format/Command) use Pro
- 🔒 **Private** — Your API key, your data. Nothing stored on any server of ours.
- 📋 **Auto-paste, clipboard-safe** — Text appears at your cursor, then your original clipboard is restored
- ⚙️ **Configurable** — Hotkey presets, per-tier models, all three prompts editable, custom API endpoint, launch at login
- 🆓 **Open source** — MIT License. Audit the code, build it yourself.

---

## Configuration

### Models

| Model | Provider | Notes |
|-------|----------|-------|
| DeepSeek V4 Flash | DeepSeek | ⚡ Fastest (default everyday tier) |
| DeepSeek V4 Pro | DeepSeek | 🧠 Strongest (Format/Command) |
| GPT-4o Mini | OpenAI | 💰 Cheapest |
| GPT-4o | OpenAI | 🎯 Most capable |
| Claude 3 Haiku | Anthropic | ⚡ Fast & smart |

### Custom API Endpoint

Works with any OpenAI-compatible API — just change the "Endpoint" field in Settings:

- [Groq](https://groq.com) — `https://api.groq.com/openai/v1/chat/completions`
- [OpenRouter](https://openrouter.ai) — `https://openrouter.ai/api/v1/chat/completions`
- Any self-hosted / corporate LLM gateway

### Prompts

The "Prompt" tab in Settings lets you edit the **Polish / Format / Command** prompts separately, with reset-to-default.

---

## Tech Stack

- **Swift 6 + SwiftUI** — Native macOS app
- **SFSpeechRecognizer** — Apple's on-device speech recognition
- **AVFoundation** — Audio recording
- **Carbon HotKeys** — Global keyboard shortcut
- **MenuBarExtra** — Menu bar integration

## Architecture

```
Sources/
├── App/
│   └── AppDelegate.swift        # Menu bar, hotkey, tier pipeline orchestration
├── Models/
│   ├── Settings.swift           # UserDefaults config + default prompts
│   ├── HistoryManager.swift     # Recent transcriptions
│   └── DictionaryStore.swift    # Personal glossary, auto-extract + injection
├── Services/
│   ├── SpeechRecognizer.swift   # SFSpeechRecognizer wrapper + WAV capture
│   ├── DeepSeekService.swift    # Chat API client (OpenAI-compatible)
│   ├── OpenAIService.swift      # Whisper cloud transcription
│   ├── SelectionService.swift   # Read selected text (AX API + ⌘C fallback)
│   └── PasteService.swift       # Cmd+V simulation + clipboard save/restore
└── Views/
    ├── SettingsView.swift       # Settings window UI
    ├── RecordingOverlay.swift   # Floating waveform HUD
    └── CommandResultView.swift  # Command-mode result panel
```

---

## License

[MIT](LICENSE) — do whatever you want. Contributions welcome.

---

*"The best tool is the one you don't notice."*
