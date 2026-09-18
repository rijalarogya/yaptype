# Yaptype

Yaptype is a free, open-source, Mac-only dictation app. Hold a hotkey, speak, release, and polished text is pasted wherever your cursor is. The main window also includes **Note Taker** for longer recordings and **File Transcription** for audio or video files.

It is a local alternative to cloud dictation tools such as Wispr Flow. Audio is transcribed on your Mac with downloadable [OpenAI Whisper](https://github.com/openai/whisper) models via [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift). Optional rewrite uses Apple Intelligence when available, otherwise a downloadable Qwen model, otherwise a small rule-based cleaner.

No account. No cloud STT. Apple Silicon only.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 14 Sonoma or later
- Xcode 16 or later to build from source

## Install

1. Download the latest `.dmg` from [Releases](../../releases) when published, or build from source below.
2. Drag **Yaptype** into `/Applications`. Launch it from Applications, not from the disk image.
3. Grant **Microphone** and **Accessibility**.
4. Download a Whisper model (Large v3 Turbo is the recommended daily driver).

Hold **Right Option** to dictate. Release to insert text. Press **Esc** to cancel.

Open the main window for **Note Taker** (live meeting transcripts and notes) and **File Transcription** (drop MP3, WAV, M4A, MP4, or MOV). Everything stays on this Mac.

## Models

Whisper models are downloaded from [argmaxinc/whisperkit-coreml](https://huggingface.co/argmaxinc/whisperkit-coreml) into `~/Library/Application Support/Yaptype/Models/`.

| Model | Best for |
| --- | --- |
| Tiny / Base English | Testing and low RAM |
| Small English | Older M-series laptops |
| Large v3 Turbo | Daily dictation |
| Large v3 Turbo compressed | Smaller turbo-quality download |

Rewrite:

1. Apple Intelligence on-device Foundation Models (macOS 26+, when enabled)
2. Downloadable `mlx-community/Qwen2.5-1.5B-Instruct-4bit`
3. Rule-based cleanup if neither LLM is ready

## Build from source

```bash
git clone https://github.com/rijalarogya/yaptype.git
cd yaptype
open Yaptype.xcodeproj
```

Or from the command line:

```bash
xcodebuild -scheme Yaptype -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  build
```

The app lands at `build/Build/Products/Release/Yaptype.app`. Copy it to `/Applications` so Accessibility permissions stick.

Package a disk image:

```bash
./scripts/package-dmg.sh
```

## Permissions

Yaptype is **not sandboxed**. System-wide hotkeys and pasting into other apps require Accessibility. - Microphone access is used while you dictate or record a note.

Notarizing a public release needs an Apple Developer ID. Unsigned local builds work after you right-click → Open the first time, or after copying a self-signed Debug build into Applications.

## Privacy

- Audio stays on device.
- History is a local JSON file in Application Support.
- There is no telemetry and no account.

## License

MIT. Whisper weights are subject to the OpenAI Whisper license. CoreML conversions are provided by Argmax. Qwen weights follow their Hugging Face licenses.
