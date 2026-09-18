# Contributing to Yaptype

Yaptype is a native Swift macOS app. Please keep the dictation path local, fast, and free of cloud STT.

## Setup

- Apple Silicon Mac
- Xcode 16+
- `open Yaptype.xcodeproj`

Do not commit downloaded Whisper or MLX weights, `DerivedData`, or `xcuserdata`.

## Architecture

The hold-to-talk loop lives in `Yaptype/Services/DictationPipeline.swift`:

1. `HotkeyService` starts and stops capture
2. `AudioCaptureService` records 16 kHz mono PCM
3. `TranscriptionService` runs WhisperKit
4. `RewriteService` polishes the transcript
5. `TextInsertionService` inserts into the focused app

## Pull requests

- Keep the app unsandboxed. Accessibility paste and global hotkeys will not work in the App Store sandbox.
- Apple Silicon / arm64 only.
- Prefer on-device models. Do not add cloud transcription APIs.
- Add or update tests for pure Swift helpers such as `RuleBasedRewriter`.

## Releases

`./scripts/package-dmg.sh` builds a Release app on your Mac and wraps it in a disk image. Upload that DMG to a GitHub Release. Do not add GitHub Actions; cloud Mac runners burn the free minutes quota. Notarization is optional and requires an Apple Developer ID.
