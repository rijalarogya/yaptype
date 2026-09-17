# Agent notes

Cadence is a native SwiftUI + AppKit menu-bar dictation app for Apple Silicon Macs.

## Do

- Keep transcription on-device with WhisperKit.
- Store models under Application Support, never in git.
- Use Accessibility insertion first, then clipboard snapshot + ⌘V.
- Prewarm the selected Whisper model so the first release after launch is not a CoreML compile stall.

## Do not

- Add Electron, Python, or a cloud STT backend.
- Sandbox the app.
- Name the product Wispr or Whisper Flow.
- Commit `.mlmodelc` files or Hugging Face snapshots.

## Build

```bash
xcodebuild -scheme Cadence -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  build
```
