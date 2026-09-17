import Foundation
import WhisperKit

@MainActor
final class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadedModelID: String?
    @Published var lastError: String?

    private let runtime = WhisperRuntime()
    private let manager = ModelManager.shared

    func prewarm(modelID: String) async {
        if loadedModelID == modelID, isReady {
            return
        }
        isLoading = true
        lastError = nil

        do {
            try await loadModel(modelID: modelID)
            loadedModelID = modelID
            isReady = true
            lastError = nil
        } catch is CancellationError {
            if await runtime.hasModel(modelID) {
                loadedModelID = modelID
                isReady = true
            }
        } catch {
            if await runtime.hasModel(modelID) {
                loadedModelID = modelID
                isReady = true
            } else {
                loadedModelID = nil
                isReady = false
                lastError = error.localizedDescription
            }
        }

        let compiling = await runtime.isCompiling()
        isLoading = !(isReady || compiling)
    }

    func transcribe(
        samples: [Float],
        modelID: String,
        language: TranscriptionLanguage
    ) async throws -> String {
        guard samples.count > Int(AudioCaptureService.sampleRate * 0.35) else {
            throw TranscriptionError.emptyAudio
        }
        if peakLevel(samples) < 0.004 {
            throw TranscriptionError.noSpeech
        }

        if loadedModelID != modelID || !isReady {
            await prewarm(modelID: modelID)
        }
        guard isReady else {
            throw TranscriptionError.stillCompiling
        }

        do {
            return try await runtime.transcribe(samples: samples, language: language)
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.failed(error.localizedDescription)
        }
    }

    func cancelTranscription() {
        Task { await runtime.cancelTranscription() }
    }

    func cancel() {
        cancelTranscription()
    }

    private func loadModel(modelID: String) async throws {
        guard let folder = manager.folder(forModelID: modelID) else {
            throw TranscriptionError.modelMissing(modelID)
        }
        try await runtime.load(
            modelID: modelID,
            localFolder: folder,
            downloadBase: manager.downloadBase
        )
    }

    private func peakLevel(_ samples: [Float]) -> Float {
        var peak: Float = 0
        for sample in samples {
            peak = max(peak, abs(sample))
        }
        return peak
    }
}

enum TranscriptionError: LocalizedError {
    case modelMissing(String)
    case emptyAudio
    case noSpeech
    case stillCompiling
    case failed(String)
    case cancelled
    case timedOut

    var errorDescription: String? {
        switch self {
        case .modelMissing(let id):
            "Whisper model “\(id)” is not downloaded yet."
        case .emptyAudio:
            "That recording was too short. Hold the key, speak a sentence, then release."
        case .noSpeech:
            "No speech detected. Check the microphone and try again."
        case .stillCompiling:
            "Whisper is still compiling on this Mac. Wait until the menu says ready, then try again."
        case .failed(let message):
            message
        case .cancelled:
            "Dictation cancelled."
        case .timedOut:
            "Transcription took too long. Try a shorter take."
        }
    }
}

actor WhisperRuntime {
    private var pipe: WhisperKit?
    private var loadedModelID: String?
    private var loadTask: Task<WhisperKit, Error>?
    private var transcribeTask: Task<String, Error>?

    func isCompiling() -> Bool { loadTask != nil && pipe == nil }

    func hasModel(_ modelID: String) -> Bool {
        loadedModelID == modelID && pipe != nil
    }

    func load(modelID: String, localFolder: URL, downloadBase: URL) async throws {
        if loadedModelID == modelID, pipe != nil {
            return
        }
        if let loadTask {
            let loaded = try await loadTask.value
            pipe = loaded
            loadedModelID = modelID
            return
        }

        let task = Task.detached(priority: .userInitiated) {
            try await Self.makePipeline(
                modelID: modelID,
                localFolder: localFolder,
                downloadBase: downloadBase
            )
        }
        loadTask = task
        do {
            let loaded = try await task.value
            pipe = loaded
            loadedModelID = modelID
            loadTask = nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            loadTask = nil
            throw error
        }
    }

    func transcribe(samples: [Float], language: TranscriptionLanguage) async throws -> String {
        guard let pipe else {
            throw TranscriptionError.stillCompiling
        }

        transcribeTask?.cancel()
        let kit = pipe
        let task = Task.detached(priority: .userInitiated) {
            try await Self.runTranscribe(kit: kit, samples: samples, language: language)
        }
        transcribeTask = task
        defer { transcribeTask = nil }
        return try await task.value
    }

    func cancelTranscription() {
        transcribeTask?.cancel()
    }

    private static func makePipeline(
        modelID: String,
        localFolder: URL,
        downloadBase: URL
    ) async throws -> WhisperKit {
        let config = WhisperKitConfig(
            model: modelID,
            downloadBase: downloadBase,
            modelFolder: localFolder.path,
            tokenizerFolder: downloadBase,
            verbose: false,
            logLevel: .error,
            prewarm: false,
            load: true,
            download: false
        )
        return try await WhisperKit(config)
    }

    private static func runTranscribe(
        kit: WhisperKit,
        samples: [Float],
        language: TranscriptionLanguage
    ) async throws -> String {
        try Task.checkCancellation()
        let detect = language == .auto
        let options = DecodingOptions(
            task: .transcribe,
            language: detect ? nil : language.rawValue,
            temperatureFallbackCount: 2,
            usePrefillPrompt: true,
            detectLanguage: detect,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            noSpeechThreshold: 0.9,
            concurrentWorkerCount: 1,
            chunkingStrategy: ChunkingStrategy.none
        )

        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        try Task.checkCancellation()
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.noSpeech
        }
        return text
    }
}
