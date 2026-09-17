import AppKit
import Combine
import Foundation
import SwiftUI

enum DictationPhase: Equatable {
    case idle
    case recording
    case preparing
    case transcribing
    case rewriting
    case inserting
    case error(String)

    var hudTitle: String {
        switch self {
        case .idle: "Ready"
        case .recording: "Listening"
        case .preparing: "Preparing model"
        case .transcribing: "Transcribing"
        case .rewriting: "Polishing"
        case .inserting: "Inserting"
        case .error: "Something went wrong"
        }
    }

    var isBusy: Bool {
        switch self {
        case .idle: false
        default: true
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
    private var preparingTimer: Timer?
    private var preparingStartedAt: Date?
    private var finishing = false
    private var workTask: Task<Void, Never>?

    func start() {
        permissions.refresh()
        rewrite.refreshAvailability()
        hotkey.onPress = { [weak self] in self?.beginRecording() }
        hotkey.onRelease = { [weak self] in self?.finishRecording() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        permissions.onChange = { [weak self] in
            self?.refreshStatus()
        }
        hotkey.start(preset: settings.hotkey)

        Task {
            self.useInstalledModelIfNeeded()
            if models.installedIDs.contains(settings.selectedModelID) {
                await transcription.prewarm(modelID: settings.selectedModelID)
            }
            refreshStatus()
        }
        refreshStatus()
    }

    func useInstalledModelIfNeeded() {
        models.refreshInstalled()
        if models.installedIDs.contains(settings.selectedModelID) { return }
        if let installed = WhisperModelSpec.all.first(where: { models.installedIDs.contains($0.id) }) {
            settings.selectedModelID = installed.id
        }
    }

    func restartHotkey() {
        hotkey.start(preset: settings.hotkey)
        refreshStatus()
    }

    func beginRecording() {
        inserter.rememberTarget()
        permissions.refresh()
        useInstalledModelIfNeeded()
        guard !finishing, phase == .idle || isRecoverableError else { return }
        if AppInstaller.isRunningFromInstaller {
            showError("Yaptype is still on the installer disk. Quit, then open it from Applications.")
            return
        }
        guard permissions.accessibilityGranted else {
            showError("macOS is still blocking this Yaptype copy. In Accessibility, select Yaptype, click −, add /Applications/Yaptype.app, then Quit & Reopen.")
            return
        }
        guard models.installedIDs.contains(settings.selectedModelID) else {
            showError("Download a Whisper model in Settings first.")
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        do {
            try audio.start()
            permissions.noteMicrophoneWorking()
            applyPhase(.recording)
            statusMessage = settings.hotkey.hint
            startMetering()
        } catch {
            Task { await permissions.requestMicrophone() }
            showError("Allow Microphone for Yaptype, then try again.")
        }
    }

    func finishRecording() {
        guard phase == .recording, !finishing else { return }
        finishing = true
        stopMetering()
        let captured = audio.stop()

        workTask?.cancel()
        workTask = Task { [weak self] in
            guard let self else { return }
            defer { self.finishing = false }
            do {
                var timing = TimingSample(audioSeconds: captured.seconds)
                if !self.transcription.isReady {
                    self.applyPhase(.preparing)
                    self.startPreparingClock()
                    await self.transcription.prewarm(modelID: self.settings.selectedModelID)
                    self.stopPreparingClock()
                    try Task.checkCancellation()
                    guard self.transcription.isReady else {
                        throw TranscriptionError.stillCompiling
                    }
                }

                self.applyPhase(.transcribing)
                let transcribeStart = Date()
                let raw = try await self.transcribeWithTimeout(
                    samples: captured.samples,
                    modelID: self.settings.selectedModelID,
                    language: self.settings.language
                )
                try Task.checkCancellation()
                timing.transcribeMs = Date().timeIntervalSince(transcribeStart) * 1000

                self.applyPhase(.rewriting)
                let rewriteStart = Date()
                let polished = await self.rewrite.rewrite(raw)
                try Task.checkCancellation()
                timing.rewriteMs = Date().timeIntervalSince(rewriteStart) * 1000
                timing.engine = polished.engine

                self.applyPhase(.inserting)
                let insertStart = Date()
                try await self.inserter.insert(polished.text)
                timing.insertMs = Date().timeIntervalSince(insertStart) * 1000
                self.lastTiming = timing

                self.history.append(
                    HistoryItem(
                        id: UUID(),
                        createdAt: Date(),
                        rawText: raw,
                        polishedText: polished.text,
                        modelID: self.settings.selectedModelID,
                        rewriteEngine: polished.engine,
                        audioSeconds: timing.audioSeconds,
                        transcribeMs: timing.transcribeMs,
                        rewriteMs: timing.rewriteMs,
                        insertMs: timing.insertMs
                    )
                )

                self.resetToIdle()
            } catch is CancellationError {
                self.resetToIdle()
            } catch let error as TranscriptionError {
                if case .cancelled = error {
                    self.resetToIdle()
                } else {
                    self.applyPhase(.error(error.localizedDescription))
                    try? await Task.sleep(for: .seconds(2.2))
                    if !Task.isCancelled {
                        self.resetToIdle()
                    }
                }
            } catch {
                self.applyPhase(.error(error.localizedDescription))
                try? await Task.sleep(for: .seconds(2.2))
                if !Task.isCancelled {
                    self.resetToIdle()
                }
            }
        }
    }

    func cancel() {
        workTask?.cancel()
        workTask = nil
        transcription.cancelTranscription()
        stopMetering()
        stopPreparingClock()
        _ = audio.stop()
        finishing = false
        resetToIdle()
    }

    private func transcribeWithTimeout(
        samples: [Float],
        modelID: String,
        language: TranscriptionLanguage
    ) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await TranscriptionService.shared.transcribe(
                    samples: samples,
                    modelID: modelID,
                    language: language
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(60))
                throw TranscriptionError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private var isRecoverableError: Bool {
        if case .error = phase { return true }
        return false
    }

    private func showError(_ message: String) {
        applyPhase(.error(message))
    }

    private func applyPhase(_ newPhase: DictationPhase) {
        phase = newPhase
        hotkey.setEscapeEnabled(newPhase.isBusy)
        if newPhase != .preparing {
            stopPreparingClock()
        }
        if newPhase == .idle {
            hud.hide()
        } else {
            hud.show(phase: newPhase, level: newPhase == .recording ? audioLevel : 0)
        }
    }

    private func startPreparingClock() {
        stopPreparingClock()
        preparingStartedAt = Date()
        hud.show(phase: .preparing, level: 0, elapsedSeconds: 0)
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == .preparing, let started = self.preparingStartedAt else { return }
                self.hud.show(
                    phase: .preparing,
                    level: 0,
                    elapsedSeconds: Int(Date().timeIntervalSince(started))
                )
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        preparingTimer = timer
    }

    private func stopPreparingClock() {
        preparingTimer?.invalidate()
        preparingTimer = nil
        preparingStartedAt = nil
    }

    private func resetToIdle() {
        applyPhase(.idle)
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
        if AppInstaller.isRunningFromInstaller {
            statusMessage = "Open Yaptype from Applications, not the DMG."
        } else if !permissions.microphoneGranted {
            statusMessage = "Turn on Microphone for Yaptype in System Settings."
        } else if !permissions.accessibilityGranted {
            statusMessage = "Remove Yaptype from Accessibility, add /Applications/Yaptype.app, then Quit & Reopen."
        } else if !models.installedIDs.contains(settings.selectedModelID) {
            statusMessage = "Download a Whisper model in Settings."
        } else if transcription.isLoading {
            statusMessage = "Compiling Whisper on this Mac. First time can take a few minutes."
        } else {
            statusMessage = settings.hotkey.hint + ". Esc cancels."
        }
    }
}
