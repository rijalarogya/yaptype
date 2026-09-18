# Agent notes

Yaptype is a native SwiftUI + AppKit dictation app for Apple Silicon Macs. It stays in the menu bar and also opens a main window for Note Taker, file transcription, history, and settings.

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
- Add GitHub Actions or any GitHub-hosted runners. Build and package only on this Mac.

## Build

```bash
xcodebuild -scheme Yaptype -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  build
```
