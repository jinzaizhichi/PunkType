# 🎙️ PunkType

**Speak naturally. AI cleans it up. Auto-paste anywhere.**

PunkType is a macOS menu bar app that lets you speak your thoughts, then uses AI (DeepSeek Flash) to clean up filler words, stutters, and rambling — while preserving your exact meaning. The cleaned-up text is automatically pasted at your cursor.

> Built by [@punk2898](https://x.com/punk2898)

## How It Works

```
⌥ Option + Space → Speak → Apple STT (local) → DeepSeek Flash cleanup → Auto-paste ✨
```

1. Press `⌥ Option + Space` (configurable) to start recording
2. Speak naturally — stutters, filler words, "um"s are fine
3. Release to stop
4. Your local Mac transcribes the audio (free, private, fast)
5. DeepSeek Flash cleans up the text (removes filler words, fixes word order)
6. Cleaned text is auto-pasted at your cursor

## Features

- 🎚️ **Three output tiers** — ⚡极速 (raw transcription, zero wait) / ✨润色 (cleanup) / 📄格式 (cleanup + auto-layout for emails, reports, meeting notes, todos)
- 🎯 **Command mode** — Select text in any app, press the hotkey, speak an instruction ("翻译成英文" / "改得更正式" / "缩短一半") — the result replaces your selection
- 📖 **Personal dictionary** — Terms, names, and product names are auto-extracted after each output (up to 300) and injected back into prompts to fix recognition errors. Editable in Settings.
- ☁️ **Whisper fallback** — Optional OpenAI cloud transcription: auto-upgrade on 格式 tier, auto-fallback when local recognition fails
- 🚀 **Fast** — Local Apple Speech Recognition + DeepSeek Flash; heavy jobs (格式/命令) use Pro
- 🔒 **Private** — Your API key, your data. Nothing stored on our servers.
- 📋 **Auto-paste, clipboard-safe** — Text appears at your cursor, then your original clipboard is restored
- ⚙️ **Configurable** — Hotkey presets, models per tier, all three prompts editable, custom API endpoint, launch at login
- 🆓 **Open source** — MIT License. Audit the code, build it yourself.

## Installation

### Option 1: Download (coming soon)
Download `PunkType.app` from [Releases](https://github.com/punk2898/PunkType/releases), move to `/Applications`, and run.

### Option 2: Build from source

```bash
git clone https://github.com/punk2898/PunkType.git
cd PunkType
make app     # Builds PunkType.app
make install # Installs to /Applications
```

**Requirements:** macOS 14+ (Sonoma or later), Xcode Command Line Tools (`xcode-select --install`)

## Setup

1. **Get a DeepSeek API Key** at [platform.deepseek.com](https://platform.deepseek.com)
2. Launch PunkType (menu bar icon: 🎙️)
3. Click the menu bar icon → **Settings...**
4. Paste your API key
5. (Optional) Customize the model, prompt, or language

### First-time permissions
- **Microphone** — needed to record your voice
- **Speech Recognition** — needed for local transcription
- **Accessibility** (optional) — for auto-paste at cursor. Without this, text goes to clipboard instead.

## Configuration

### Models

| Model | Provider | Speed |
|-------|----------|-------|
| DeepSeek V4 Flash | DeepSeek | ⚡ Fastest |
| DeepSeek V4 Pro | DeepSeek | 🧠 Strongest |
| GPT-4o Mini | OpenAI | 💰 Cheapest |
| GPT-4o | OpenAI | 🎯 Most capable |
| Claude 3 Haiku | Anthropic | ⚡ Fast & smart |

### Custom API Endpoint
You can use any OpenAI-compatible API:
- [Groq](https://groq.com) — `https://api.groq.com/openai/v1/chat/completions`
- [OpenRouter](https://openrouter.ai) — `https://openrouter.ai/api/v1/chat/completions`
- Any self-hosted LLM

### Prompt Customization
Edit the **System Prompt** in Settings to control how the AI cleans up your text. The default prompt:
- Removes filler words (嗯, 啊, um, uh, like, you know)
- Fixes stutters and half-finished sentences
- Keeps word order natural
- Preserves all technical terms and proper nouns
- Maintains your speaking style

## Tech Stack

- **Swift 6 + SwiftUI** — Native macOS app
- **SFSpeechRecognizer** — Apple's on-device speech recognition
- **AVFoundation** — Audio recording
- **Carbon HotKeys** — Global keyboard shortcut
- **MenuBarExtra** — Menu bar integration (macOS 13+)

## Architecture

```
Sources/
├── App/
│   └── AppDelegate.swift        # Menu bar, hotkey, tier pipeline orchestration
├── Models/
│   ├── Settings.swift           # UserDefaults-backed config + default prompts
│   ├── HistoryManager.swift     # Recent transcriptions (Application Support)
│   └── DictionaryStore.swift    # Personal glossary, auto-extract + injection
├── Services/
│   ├── SpeechRecognizer.swift   # SFSpeechRecognizer wrapper + WAV capture
│   ├── DeepSeekService.swift    # Chat API client (OpenAI-compatible)
│   ├── OpenAIService.swift      # Whisper cloud transcription
│   ├── SelectionService.swift   # Read selected text via Accessibility API
│   └── PasteService.swift       # Cmd+V simulation + clipboard save/restore
└── Views/
    ├── SettingsView.swift       # Settings window UI
    └── RecordingOverlay.swift   # Floating waveform HUD
```

## License

MIT — do whatever you want. Contributions welcome.

## Todo

- [x] Customizable hotkey (presets)
- [x] Recording indicator overlay
- [x] Three output tiers (极速/润色/格式)
- [x] Command mode on selected text
- [x] Personal dictionary
- [x] Whisper cloud fallback
- [ ] Quick translation mode (point-and-cycle target language)
- [ ] Style profile (personal tone learning)
- [ ] Multiple language support in STT
- [x] iOS version (keyboard extension)

---

*"The best tool is the one you don't notice."*
