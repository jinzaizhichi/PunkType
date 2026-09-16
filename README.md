# 🎙️ PunkType

**Speak naturally, get finished text. / 说人话，出成品。**

[English](#english) · [简体中文](#简体中文)

---

<a name="english"></a>

## English

Press a hotkey in any text field, speak, and AI turns it into clean, well-formed text typed straight at your cursor.

PunkType is a macOS menu-bar app: you speak → your Mac (or Whisper) transcribes → DeepSeek removes filler and formats the text → it's pasted at your cursor. Free, open source, bring-your-own API key, nothing sent to any server of ours.

### Install

#### Option 1: Download (recommended)

Grab the latest `PunkType-vX.X.X-macos.zip` from [Releases](https://github.com/punk2898/PunkType/releases), unzip, and drag `PunkType.app` into `/Applications`.

> Builds are signed with a Developer ID and **notarized by Apple**, so you can just **double-click to open** — no Gatekeeper right-click dance.

#### Option 2: Build from source

```bash
git clone https://github.com/punk2898/PunkType.git
cd PunkType
make app      # Builds PunkType.app
make install  # Installs to /Applications and launches
```

**Requirements:** macOS 14+ (Sonoma or later), Xcode Command Line Tools (`xcode-select --install`)

### Setup

1. Get a DeepSeek API key at [platform.deepseek.com](https://platform.deepseek.com).
2. Launch PunkType (waveform icon in the menu bar).
3. Click the menu bar icon → **Settings**, paste your API key. (The endpoint defaults to DeepSeek; see Configuration to use another provider.)
4. Grant first-run permissions when prompted:
   - **Microphone** — to record
   - **Speech Recognition** — for local transcription
   - **Accessibility** — for auto-paste & reading selected text (without it, text only goes to the clipboard)

### How to use

```
⌥ Space → Speak → Local/Whisper STT → DeepSeek cleanup → Auto-paste ✨
```

- **Dictation**: press `⌥ Space` in any text field, speak, press again to stop — the result is typed at your cursor.
- **Command mode**: select some text first, then press `⌥⌘ S` and speak an instruction ("summarize this", "make it more formal"). The result appears in a panel — **Copy** it or **Replace** the selection.
- **Translate** (`⌥⌘ T`): speak, and it's translated into your target language and inserted at the cursor.
- **Ask** (`⌥⌘ A`): speak a question, get the answer in a panel.

### Features

- 🎚️ **Three output tiers** — ⚡ Fast (raw transcription, zero wait) / ✨ Polish (cleanup) / 📄 Format (cleanup + auto-layout for emails, reports, meeting notes, todos)
- 🎯 **Command mode** — Select text in any app, speak an instruction, get the result in a panel to copy or replace
- 🌐 **Translate & Ask** — Dedicated hotkeys to translate on the fly or ask a quick question by voice
- 📜 **History** — Your recent outputs are kept locally (Settings → History), ready to copy again
- 🧠 **App-aware tone** — Automatically adapts to the frontmost app: casual in chat, formal in email, term-preserving in code/terminal
- 🎭 **Style profile** — Optionally learns how you express yourself so polished output reads more like you (learns only constructive style, never profanity or disfluencies)
- 📖 **Personal dictionary** — Terms, names, and product names are auto-extracted after each output and injected back into prompts to fix recognition errors. Editable in Settings.
- ☁️ **Whisper fallback** — Optional OpenAI cloud transcription: auto-upgrade on the Format tier, auto-fallback when local recognition fails
- 🚀 **Fast** — Local Apple Speech Recognition + DeepSeek V4.1 Flash for everyday use
- 🔒 **Private** — Your API key, your data. Nothing stored on any server of ours.
- 📋 **Auto-paste, clipboard-safe** — Text appears at your cursor, then your original clipboard is restored
- ⚙️ **Configurable** — Hotkey presets, per-tier models, all prompts editable, custom API endpoint, launch at login
- 🆓 **Open source** — MIT License. Audit the code, build it yourself.

### Configuration

#### Models

| Model | Provider | Notes |
|-------|----------|-------|
| DeepSeek V4.1 Flash (`deepseek-flash`) | DeepSeek | ⚡ Fast + high quality (default everyday tier) |
| DeepSeek V4 Pro (`deepseek-v4-pro`) | DeepSeek | 🧠 Heavier jobs |
| GPT-5.6 Luna | OpenAI | 💰 Cost-effective, fast |
| GPT-5.6 Terra | OpenAI | ⚖️ Balanced |
| GPT-5.6 Sol | OpenAI | 🎯 Flagship |

> To use the GPT-5.6 models, switch the endpoint to an OpenAI-compatible URL and enter the matching key.

#### Custom API endpoint

Works with any OpenAI-compatible API — just change the "Endpoint" field in Settings:

- [Groq](https://groq.com) — `https://api.groq.com/openai/v1/chat/completions`
- [OpenRouter](https://openrouter.ai) — `https://openrouter.ai/api/v1/chat/completions`
- Any self-hosted / corporate LLM gateway

#### Prompts

The "Prompt" tab in Settings lets you edit the **Polish / Format / Command** prompts separately, with reset-to-default.

### Tech stack

- **Swift 6 + SwiftUI** — Native macOS app
- **SFSpeechRecognizer** — Apple's on-device speech recognition
- **AVFoundation** — Audio recording
- **Carbon HotKeys** — Global keyboard shortcuts
- **MenuBarExtra** — Menu bar integration

### License

[MIT](LICENSE) — do whatever you want. Contributions welcome.

---

<a name="简体中文"></a>

## 简体中文

在任何输入框里，按下快捷键说话，AI 自动整理成通顺文字，直接打进光标处。

PunkType 是一个 macOS 菜单栏小工具：你说话 → 本机（或 Whisper）转写 → DeepSeek 清理口语、自动排版 → 粘贴到当前输入框。完全免费、开源，自带 API Key，无任何数据上报。

### 下载安装

#### 方式一：直接下载（推荐）

到 [Releases](https://github.com/punk2898/PunkType/releases) 下载最新的 `PunkType-vX.X.X-macos.zip`，解压后把 `PunkType.app` 拖进「应用程序」。

> 下载包为 Developer ID 签名并**经过苹果公证**，**双击即可打开**，无需右键绕过 Gatekeeper。

#### 方式二：从源码编译

```bash
git clone https://github.com/punk2898/PunkType.git
cd PunkType
make app      # 编译出 PunkType.app
make install  # 安装到「应用程序」并启动
```

**环境要求**：macOS 14+（Sonoma 及以上）、Xcode 命令行工具（`xcode-select --install`）

### 初次配置

1. 到 [platform.deepseek.com](https://platform.deepseek.com) 申请一个 DeepSeek API Key。
2. 启动 PunkType（菜单栏出现波形图标）。
3. 点菜单栏图标 → **设置**，填入你的 API Key。（接口默认走 DeepSeek；想用别家看下面「配置说明」。）
4. 首次使用按系统提示授予权限：
   - **麦克风** — 录音
   - **语音识别** — 本机转写
   - **辅助功能** — 自动粘贴、读取选中文字（不授予则只能复制到剪贴板）

### 怎么用

```
⌥ Space → 说话 → 本机/Whisper 转写 → DeepSeek 整理 → 自动粘贴 ✨
```

- **普通听写**：在任意输入框按 `⌥ Space`，说话，再按一下停止，结果直接打进光标处。
- **选中命令**：先选中一段文字，再按 `⌥⌘ S`，口述指令（「总结一下」「改得更正式」），结果在弹窗中展示，可**复制**或**替换原文**。
- **翻译**（`⌥⌘ T`）：口述内容翻译成目标语言，直接插入光标处。
- **询问**（`⌥⌘ A`）：口述一个问题，AI 回答弹窗展示。

### 功能

- 🎚️ **三档输出** — ⚡极速（转写直出，零等待）/ ✨润色（清理口语）/ 📄格式（清理 + 自动排版成邮件、汇报、纪要、待办）
- 🎯 **选中命令模式** — 在任意 App 选中文字，按快捷键口述指令，结果弹窗展示，可复制或替换
- 🌐 **翻译 & 询问** — 独立快捷键，随口翻译或语音提问
- 📜 **历史记录** — 最近的输出本地留存（设置 → 历史），随时再复制
- 🧠 **App 感知** — 自动按当前应用调整语气：聊天口语、邮件正式、代码/终端保留术语
- 🎭 **风格画像** — 可选学习你的表达习惯，润色越来越像你本人写的（只学正面表达风格，不学脏话与口头禅）
- 📖 **个人词典** — 每次出字后自动提取术语、人名、产品名，回注提示词纠正识别错误，可在设置里增删改
- ☁️ **Whisper 云端兜底** — 可选的 OpenAI 云端转写：格式档自动升级、本机识别失败时自动回落
- 🚀 **快** — 本机语音识别 + DeepSeek V4.1 Flash，日常听写即说即出
- 🔒 **隐私** — 你自己的 API Key、你自己的数据，不经过任何中间服务器
- 📋 **粘贴安全** — 自动粘贴到光标处，随后恢复你原来的剪贴板内容
- ⚙️ **可配置** — 快捷键预设、分档模型、提示词可编辑、自定义接口地址、开机自启
- 🆓 **开源** — MIT 许可证，代码可审计、可自行编译

### 配置说明

#### 模型

| 模型 | 提供方 | 特点 |
|------|--------|------|
| DeepSeek V4.1 Flash（`deepseek-flash`） | DeepSeek | ⚡ 快 + 高质量（默认日常档） |
| DeepSeek V4 Pro（`deepseek-v4-pro`） | DeepSeek | 🧠 重活档 |
| GPT-5.6 Luna | OpenAI | 💰 高性价比、快 |
| GPT-5.6 Terra | OpenAI | ⚖️ 均衡 |
| GPT-5.6 Sol | OpenAI | 🎯 旗舰 |

> 使用 GPT-5.6 系列时，把接口地址换成 OpenAI 兼容地址，并填入对应 Key。

#### 自定义接口地址

支持任何 OpenAI 兼容接口，改设置里的「接口地址」即可换后端：

- [Groq](https://groq.com) — `https://api.groq.com/openai/v1/chat/completions`
- [OpenRouter](https://openrouter.ai) — `https://openrouter.ai/api/v1/chat/completions`
- 自建/公司内网的任意大模型网关

#### 提示词

设置里的「提示词」页可分别编辑**润色 / 格式 / 选中命令**三套提示词，随时恢复默认。

### 技术栈

- **Swift 6 + SwiftUI** — 原生 macOS App
- **SFSpeechRecognizer** — 苹果本机语音识别
- **AVFoundation** — 录音
- **Carbon HotKeys** — 全局快捷键
- **MenuBarExtra** — 菜单栏常驻

### 许可证

[MIT](LICENSE) — 随便用，欢迎贡献。

---

*"The best tool is the one you don't notice. / 最好的工具，是你感觉不到它存在的工具。"*
