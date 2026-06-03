# SmartNotch

A Notchie-style overlay that sits **right under your MacBook's notch** and answers any
question — by voice or by typing — using **Google Gemini**. The overlay is **invisible
to screen-sharing apps** (Zoom, Google Meet, Microsoft Teams), so you can use it during
calls or interviews without anyone seeing it.

```
        ┌───────────────────────┐
        │     ●  Listening…     │   ← floats just below the notch
        │  How long is a marathon?
        │  42.195 km (26.2 miles).
        └───────────────────────┘
```

## Features

- **Hold Fn + Space anywhere** → starts recording. Release → sends to Gemini.
- **Voice or text** — click the menu-bar icon → *Ask SmartNotch* for a typing field.
- **On-device Apple Speech** for instant partial transcripts, **Gemini multimodal audio fallback** when STT misses.
- **Streams answers token-by-token** in 2 sentences max (configurable system prompt).
- **Invisible to screen capture** (`NSWindow.sharingType = .none`).
- **API key stored in macOS Keychain.** Never written to disk.

## Build (60 seconds)

You need: macOS 13+, Xcode 15+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd SmartNotch
xcodegen generate
open SmartNotch.xcodeproj
```

Then in Xcode:

1. Select the **SmartNotch** target → *Signing & Capabilities* → pick your team (or leave "Sign to Run Locally").
2. ⌘R to run.

### Don't have XcodeGen?

Create a new Xcode project: **macOS → App → SwiftUI**, name it `SmartNotch`, then drag the contents
of the `SmartNotch/` folder into it, replacing the default `Info.plist` and `.entitlements`. Add
**Hardened Runtime** and check **Audio Input** under capabilities.

## Permissions (first run)

macOS will ask for three things — grant all:

| Permission | Why |
|---|---|
| **Microphone** | record your question |
| **Speech Recognition** | on-device transcription |
| **Input Monitoring** | listen for `Fn + Space` system-wide |

If the hotkey doesn't fire, open **System Settings → Privacy & Security → Input Monitoring**
and toggle SmartNotch on. (You'll be prompted automatically on first hotkey use.)

## Add your Gemini key

1. Click the menu-bar ✨ icon → **Settings…** (or press ⌘,)
2. Paste your key from <https://aistudio.google.com/app/apikey>
3. Pick a model — `gemini-2.0-flash` is the sweet spot for speed.

## Using it

- **Voice:** hold `Fn + Space`, ask anything, release. Answer appears under the notch.
- **Type:** click the menu-bar icon → *Ask SmartNotch*, type, press Return.
- The answer auto-dismisses ~15 s after streaming finishes.

## Privacy of the overlay

The overlay window sets `NSWindow.sharingType = .none`, which means macOS excludes it from
all CG-based screen capture APIs. Zoom, Meet, Teams, OBS, QuickTime — they'll see your desktop
*without* SmartNotch on it. (Note: this defeats software-level capture, but a phone pointed at
your screen will of course still see it.)

## Files

```
SmartNotch/
├── SmartNotchApp.swift          # @main, menu bar, delegate
├── AppState.swift               # ObservableObject (mode, transcript, answer, key)
├── KeychainStore.swift          # API key persistence
├── NotchOverlayController.swift # NSPanel + screen-capture-invisible window
├── NotchOverlayView.swift       # SwiftUI pill UI under the notch
├── HotKeyManager.swift          # Fn+Space CGEventTap (hold-to-record)
├── AudioRecorder.swift          # AVAudioRecorder → .m4a (Gemini fallback)
├── SpeechTranscriber.swift      # SFSpeechRecognizer (on-device partials)
├── GeminiClient.swift           # SSE streaming + multimodal audio
├── SettingsView.swift           # API key, model, system prompt
├── Info.plist                   # LSUIElement, usage strings
└── SmartNotch.entitlements      # audio-input, network.client
project.yml                      # XcodeGen spec
```

## Changing the shortcut

Edit `HotKeyManager.swift` — it triggers when `flags.contains(.maskSecondaryFn)` and Space is
pressed. Swap the modifier check for `.maskCommand | .maskShift` (etc.) and the keycode for
whatever you like (`kVK_Space`, `kVK_ANSI_K`, …).
