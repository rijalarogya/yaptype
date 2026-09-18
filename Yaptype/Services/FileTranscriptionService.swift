import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum FileJobState: Equatable {
    case idle
    case decoding
    case transcribing
    case failed(String)
    case completed
}

struct FileJob: Identifiable, Equatable {
    var id: UUID
    var url: URL
    var fileName: String
    var progress: Double
    var state: FileJobState
    var modelTitle: String
    var startedAt: Date
}

@MainActor
final class FileTranscriptionService: ObservableObject {
    static let shared = FileTranscriptionService()

    @Published var includeTimestamps = true
    @Published var languageRaw = TranscriptionLanguage.auto.rawValue {
        didSet { UserDefaults.standard.set(languageRaw, forKey: "fileTranscriptionLanguage") }
    }
    @Published var activeJob: FileJob?
    @Published var lastError: String?
    @Published var lastItem: HistoryItem?

    private let transcription = TranscriptionService.shared
    private let history = HistoryStore.shared
    private let models = ModelManager.shared
    private let settings = AppSettings.shared
    private var workTask: Task<Void, Never>?

    private init() {
        if let stored = UserDefaults.standard.string(forKey: "fileTranscriptionLanguage") {
            languageRaw = stored
        }
    }

    var language: TranscriptionLanguage {
        get { TranscriptionLanguage(rawValue: languageRaw) ?? .auto }
        set { languageRaw = newValue.rawValue }
    }

    var isWorking: Bool {
        if case .decoding = activeJob?.state { return true }
        if case .transcribing = activeJob?.state { return true }
        return false
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = AudioFileDecoder.contentTypes
        panel.message = "Choose an audio or video file to transcribe on this Mac."
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            self.transcribe(url: url)
        }
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.identifier?.rawValue == "main" })
            ?? NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    func transcribe(url: URL) {
        guard AudioFileDecoder.supports(url) else {
            lastError = AudioFileDecoderError.unsupported.localizedDescription
            return
        }
        guard models.installedIDs.contains(resolvedModelID) else {
            lastError = "Download a Whisper model in Models first."
            return
        }
        guard DictationPipeline.shared.phase == .idle, !NoteTakerService.shared.isActive else {
            lastError = "Finish the current recording first."
            return
        }

        workTask?.cancel()
        lastError = nil
        lastItem = nil
        let job = FileJob(
            id: UUID(),
            url: url,
            fileName: url.lastPathComponent,
            progress: 0.05,
            state: .decoding,
            modelTitle: WhisperModelSpec.spec(for: resolvedModelID)?.title ?? resolvedModelID,
            startedAt: Date()
        )
        activeJob = job
        let modelID = resolvedModelID
        let language = language

        workTask = Task { [weak self] in
            await self?.run(job: job, modelID: modelID, language: language)
        }
    }

    func cancel() {
        workTask?.cancel()
        workTask = nil
        transcription.cancelTranscription()
        activeJob = nil
    }

    private var resolvedModelID: String {
        settings.selectedModelID
    }

    private func run(
        job: FileJob,
        modelID: String,
        language: TranscriptionLanguage
    ) async {
        var job = job
        do {
            job.state = .decoding
            job.progress = 0.08
            activeJob = job
            let decoded = try await AudioFileDecoder.decode(job.url)
            try Task.checkCancellation()

            job.state = .transcribing
            job.progress = 0.12
            activeJob = job

            if !transcription.isReady || transcription.loadedModelID != modelID {
                await transcription.prewarm(modelID: modelID)
            }

            let transcribeStart = Date()
            let output = try await transcription.transcribeDetailed(
                samples: decoded.samples,
                modelID: modelID,
                language: language,
                includeTimestamps: true,
                allowShort: true
            ) { [weak self] value in
                guard var current = self?.activeJob, current.id == job.id else { return }
                current.state = .transcribing
                current.progress = 0.12 + (0.88 * value)
                self?.activeJob = current
            }
            try Task.checkCancellation()

            let item = HistoryItem(
                id: job.id,
                createdAt: Date(),
                rawText: output.text,
                polishedText: output.text,
                modelID: modelID,
                rewriteEngine: "Off",
                audioSeconds: decoded.seconds,
                transcribeMs: Date().timeIntervalSince(transcribeStart) * 1000,
                rewriteMs: 0,
                insertMs: 0,
                kind: .file,
                title: job.fileName,
                fileName: job.fileName,
                segments: output.segments
            )
            history.append(item)
            lastItem = item
            job.state = .completed
            job.progress = 1
            activeJob = job
        } catch is CancellationError {
            activeJob = nil
        } catch {
            job.state = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            activeJob = job
        }
    }
}
