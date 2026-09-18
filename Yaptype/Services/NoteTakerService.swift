import Foundation
import SwiftUI

enum NoteTakerPhase: Equatable {
    case idle
    case recording
    case paused
    case transcribing
    case cleaning
}

@MainActor
final class NoteTakerService: ObservableObject {
    static let shared = NoteTakerService()

    @Published var phase: NoteTakerPhase = .idle
    @Published var audioLevel: Float = 0
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var segments: [TranscriptSegment] = []
    @Published var transcript = ""
    @Published var notesText = ""
    @Published var currentItem: HistoryItem?
    @Published var lastError: String?
    @Published var isCleaning = false

    private let audio = AudioCaptureService()
    private let transcription = TranscriptionService.shared
    private let rewrite = RewriteService.shared
    private let history = HistoryStore.shared
    private let settings = AppSettings.shared
    private let models = ModelManager.shared
    private let permissions = PermissionService.shared

    private var meterTimer: Timer?
    private var chunkTimer: Timer?
    private var lastSampleIndex = 0
    private var transcribeTask: Task<Void, Never>?
    private var liveItemID: UUID?

    var isActive: Bool {
        phase == .recording || phase == .paused || phase == .transcribing || phase == .cleaning
    }

    var canStart: Bool {
        phase == .idle && DictationPipeline.shared.phase == .idle && !transcription.isBusy
    }

    func start() {
        lastError = nil
        permissions.refresh()
        DictationPipeline.shared.ensureCompatibleModel()
        guard canStart else {
            lastError = "Stop dictation or wait for an in-progress transcription first."
            return
        }
        guard permissions.microphoneGranted else {
            lastError = "Allow Microphone for Yaptype, then try again."
            Task { await permissions.requestMicrophone() }
            return
        }
        guard models.installedIDs.contains(settings.selectedModelID) else {
            lastError = "Download a Whisper model in Models first."
            return
        }

        do {
            try audio.start()
            permissions.noteMicrophoneWorking()
            liveItemID = UUID()
            segments = []
            transcript = ""
            notesText = ""
            currentItem = nil
            lastSampleIndex = 0
            elapsedSeconds = 0
            phase = .recording
            startTimers()
        } catch {
            lastError = "Allow Microphone for Yaptype, then try again."
            Task { await permissions.requestMicrophone() }
        }
    }

    func pause() {
        guard phase == .recording else { return }
        audio.pauseCapture()
        stopTimers()
        phase = .paused
        audioLevel = 0
        transcribeNewAudio()
    }

    func resume() {
        guard phase == .paused else { return }
        do {
            try audio.start(clearing: false)
            phase = .recording
            startTimers()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        guard isActive else { return }
        stopTimers()
        let captured = audio.stop()
        phase = .transcribing
        transcribeTask?.cancel()
        transcribeTask = Task { [weak self] in
            await self?.finish(samples: captured.samples, seconds: captured.seconds)
        }
    }

    func cancel() {
        transcribeTask?.cancel()
        transcribeTask = nil
        transcription.cancelTranscription()
        stopTimers()
        _ = audio.stop()
        reset()
    }

    func cleanNotes() {
        guard !transcript.isEmpty else { return }
        isCleaning = true
        Task {
            notesText = await rewrite.extractNotes(from: transcript)
            if var item = currentItem {
                item.notesText = notesText
                currentItem = item
                history.update(item)
            }
            isCleaning = false
        }
    }

    func copyTranscript() {
        Clipboard.copy(transcript)
    }

    func copyNotes() {
        Clipboard.copy(notesText)
    }

    private func startTimers() {
        stopTimers()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == .recording else { return }
                self.audioLevel = self.audio.level
                self.elapsedSeconds = self.audio.elapsedSeconds()
            }
        }
        if let meterTimer {
            RunLoop.main.add(meterTimer, forMode: .common)
        }
        chunkTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.transcribeNewAudio()
            }
        }
        if let chunkTimer {
            RunLoop.main.add(chunkTimer, forMode: .common)
        }
    }

    private func stopTimers() {
        meterTimer?.invalidate()
        meterTimer = nil
        chunkTimer?.invalidate()
        chunkTimer = nil
        audioLevel = 0
    }

    private func transcribeNewAudio() {
        guard !transcription.isBusy else { return }
        let total = audio.sampleCount()
        let start = lastSampleIndex
        guard total - start > Int(AudioCaptureService.sampleRate * 1.2) else { return }
        let slice = audio.copySamples(from: start, upTo: total)
        lastSampleIndex = total
        let offset = Double(start) / AudioCaptureService.sampleRate
        Task {
            do {
                let output = try await transcription.transcribeDetailed(
                    samples: slice,
                    modelID: settings.selectedModelID,
                    language: settings.language,
                    includeTimestamps: true,
                    allowShort: true
                )
                let shifted = output.segments.map {
                    TranscriptSegment(start: $0.start + offset, end: $0.end + offset, text: $0.text)
                }
                append(segments: shifted, text: output.text)
            } catch TranscriptionError.noSpeech, TranscriptionError.emptyAudio {
                return
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func finish(samples: [Float], seconds: Double) async {
        do {
            if !transcription.isReady {
                await transcription.prewarm(modelID: settings.selectedModelID)
            }
            var output = TranscriptionOutput(text: transcript, segments: segments)
            if samples.count > Int(AudioCaptureService.sampleRate * 0.8) {
                output = try await transcription.transcribeDetailed(
                    samples: samples,
                    modelID: settings.selectedModelID,
                    language: settings.language,
                    includeTimestamps: true,
                    allowShort: true
                ) { [weak self] _ in
                    self?.elapsedSeconds = seconds
                }
            }
            try Task.checkCancellation()
            transcript = output.text
            segments = output.segments
            phase = .cleaning
            notesText = await rewrite.extractNotes(from: transcript)
            let item = HistoryItem(
                id: liveItemID ?? UUID(),
                createdAt: Date(),
                rawText: transcript,
                polishedText: transcript,
                modelID: settings.selectedModelID,
                rewriteEngine: rewrite.lastEngineName,
                audioSeconds: seconds,
                transcribeMs: 0,
                rewriteMs: 0,
                insertMs: 0,
                kind: .note,
                title: HistoryItem.makeTitle(from: transcript, kind: .note),
                notesText: notesText,
                segments: segments
            )
            if history.items.contains(where: { $0.id == item.id }) {
                history.update(item)
            } else {
                history.append(item)
            }
            currentItem = item
            phase = .idle
        } catch is CancellationError {
            reset()
        } catch {
            lastError = error.localizedDescription
            phase = .idle
        }
    }

    private func append(segments newSegments: [TranscriptSegment], text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        segments.append(contentsOf: newSegments)
        if transcript.isEmpty {
            transcript = cleaned
        } else {
            transcript += " " + cleaned
        }
    }

    private func reset() {
        phase = .idle
        audioLevel = 0
        elapsedSeconds = 0
        lastSampleIndex = 0
        liveItemID = nil
    }
}
