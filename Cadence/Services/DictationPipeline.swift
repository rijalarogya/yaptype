import AppKit
import Combine
import Foundation
import SwiftUI

enum DictationPhase: Equatable {
    case idle
    case recording
    case transcribing
    case rewriting
    case inserting
    case error(String)

    var hudTitle: String {
        switch self {
        case .idle: "Ready"
        case .recording: "Listening"
        case .transcribing: "Transcribing"
        case .rewriting: "Polishing"
        case .inserting: "Inserting"
        case .error: "Something went wrong"
        }
    }
}

@MainActor
final class DictationPipeline: ObservableObject {
    static let shared = DictationPipeline()

    @Published var phase: DictationPhase = .idle
    @Published var audioLevel: Float = 0
    @Published var lastTiming = TimingSample()
    @Published var statusMessage = "Hold \(AppSettings.shared.hotkey.title) to dictate"

    private let audio = AudioCaptureService()
    private let hotkey = HotkeyService.shared
    private let hud = HUDController.shared
    private let transcription = TranscriptionService.shared
    private let rewrite = RewriteService.shared
    private let models = ModelManager.shared
    private let history = HistoryStore.shared
    private let settings = AppSettings.shared
    private let permissions = PermissionService.shared
    private let inserter = TextInsertionService()
    private var levelTimer: Timer?
    private var finishing = false

    func start() {
        permissions.refresh()
        rewrite.refreshAvailability()
        hotkey.onPress = { [weak self] in self?.beginRecording() }
        hotkey.onRelease = { [weak self] in self?.finishRecording() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        hotkey.start(preset: settings.hotkey)

        Task {
            if models.isInstalled(WhisperModelSpec.spec(for: settings.selectedModelID) ?? .recommended) {
                await transcription.prewarm(modelID: settings.selectedModelID)
            }
        }
        refreshStatus()
    }

    func restartHotkey() {
        hotkey.start(preset: settings.hotkey)
        refreshStatus()
    }

    func beginRecording() {
        guard !finishing else { return }
        guard permissions.allGranted else {
            phase = .error("Grant Microphone and Accessibility in onboarding.")
            hud.show(phase: phase, level: 0)
            return
        }
        guard models.installedIDs.contains(settings.selectedModelID) else {
            phase = .error("Download a Whisper model in Settings first.")
            hud.show(phase: phase, level: 0)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        do {
            try audio.start()
            phase = .recording
            statusMessage = settings.hotkey.hint
            hud.show(phase: phase, level: 0)
            startMetering()
        } catch {
            phase = .error(error.localizedDescription)
            hud.show(phase: phase, level: 0)
        }
    }

    func finishRecording() {
        guard phase == .recording, !finishing else { return }
        finishing = true
        stopMetering()
        let captured = audio.stop()

        Task {
            defer { finishing = false }
            do {
                var timing = TimingSample(audioSeconds: captured.seconds)
                phase = .transcribing
                hud.show(phase: phase, level: 0)

                let transcribeStart = Date()
                let raw = try await transcription.transcribe(
                    samples: captured.samples,
                    modelID: settings.selectedModelID,
                    language: settings.language
                )
                timing.transcribeMs = Date().timeIntervalSince(transcribeStart) * 1000

                phase = .rewriting
                hud.show(phase: phase, level: 0)
                let rewriteStart = Date()
                let polished = await rewrite.rewrite(raw)
                timing.rewriteMs = Date().timeIntervalSince(rewriteStart) * 1000
                timing.engine = polished.engine

                phase = .inserting
                hud.show(phase: phase, level: 0)
                let insertStart = Date()
                try inserter.insert(polished.text)
                timing.insertMs = Date().timeIntervalSince(insertStart) * 1000
                lastTiming = timing

                history.append(
                    HistoryItem(
                        id: UUID(),
                        createdAt: Date(),
                        rawText: raw,
                        polishedText: polished.text,
                        modelID: settings.selectedModelID,
                        rewriteEngine: polished.engine,
                        audioSeconds: timing.audioSeconds,
                        transcribeMs: timing.transcribeMs,
                        rewriteMs: timing.rewriteMs,
                        insertMs: timing.insertMs
                    )
                )

                hud.hide()
                phase = .idle
                refreshStatus()
            } catch {
                phase = .error(error.localizedDescription)
                hud.show(phase: phase, level: 0)
                try? await Task.sleep(for: .seconds(2.2))
                hud.hide()
                phase = .idle
                refreshStatus()
            }
        }
    }

    func cancel() {
        stopMetering()
        _ = audio.stop()
        finishing = false
        hud.hide()
        phase = .idle
        refreshStatus()
    }

    private func startMetering() {
        stopMetering()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == .recording else { return }
                self.audioLevel = self.audio.level
                self.hud.show(phase: .recording, level: self.audio.level)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        levelTimer = timer
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }

    func refreshStatus() {
        if !permissions.allGranted {
            statusMessage = "Finish onboarding to grant Microphone and Accessibility."
        } else if !models.installedIDs.contains(settings.selectedModelID) {
            statusMessage = "Download a Whisper model to start dictating."
        } else {
            statusMessage = settings.hotkey.hint + ". Esc cancels."
        }
    }
}
