import Foundation
import WhisperKit

@MainActor
final class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var isBusy = false
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
        let output = try await transcribeDetailed(
            samples: samples,
            modelID: modelID,
            language: language,
            includeTimestamps: false,
            allowShort: false,
            progress: nil
        )
        return output.text
    }

    func transcribeDetailed(
        samples: [Float],
        modelID: String,
        language: TranscriptionLanguage,
        includeTimestamps: Bool,
        allowShort: Bool = false,
        progress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> TranscriptionOutput {
        guard samples.count > Int(AudioCaptureService.sampleRate * (allowShort ? 0.6 : 0.35)) else {
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

        isBusy = true
        defer { isBusy = false }

        do {
            return try await runtime.transcribeDetailed(
                samples: samples,
                language: language,
                includeTimestamps: includeTimestamps,
                progress: { value in
                    Task { @MainActor in
                        progress?(value)
                    }
                }
            )
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
    private var transcribeTask: Task<TranscriptionOutput, Error>?

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
        let output = try await transcribeDetailed(
            samples: samples,
            language: language,
            includeTimestamps: false,
            progress: nil
        )
        return output.text
    }

    func transcribeDetailed(
        samples: [Float],
        language: TranscriptionLanguage,
        includeTimestamps: Bool,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> TranscriptionOutput {
        guard let pipe else {
            throw TranscriptionError.stillCompiling
        }

        transcribeTask?.cancel()
        let kit = pipe
        let task = Task.detached(priority: .userInitiated) {
            try await Self.runTranscribeDetailed(
                kit: kit,
                samples: samples,
                language: language,
                includeTimestamps: includeTimestamps,
                progress: progress
            )
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
        let output = try await runTranscribeDetailed(
            kit: kit,
            samples: samples,
            language: language,
            includeTimestamps: false,
            progress: nil
        )
        return output.text
    }

    private static func runTranscribeDetailed(
        kit: WhisperKit,
        samples: [Float],
        language: TranscriptionLanguage,
        includeTimestamps: Bool,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> TranscriptionOutput {
        try Task.checkCancellation()
        let resolvedLanguage: String?
        let shouldDetect = language == .auto
        if shouldDetect {
            resolvedLanguage = try await Self.detectSpokenLanguage(kit: kit, samples: samples)
        } else {
            resolvedLanguage = language.rawValue
        }

        let sampleRate = Int(AudioCaptureService.sampleRate)
        let window = 30 * sampleRate
        var offset = 0
        var segments: [TranscriptSegment] = []
        var texts: [String] = []

        if samples.count <= window {
            let chunk = try await Self.decodeWindow(
                kit: kit,
                samples: samples,
                language: resolvedLanguage,
                includeTimestamps: includeTimestamps,
                timeOffset: 0
            )
            progress?(1)
            return chunk
        }

        while offset < samples.count {
            try Task.checkCancellation()
            let end = min(offset + window, samples.count)
            let slice = Array(samples[offset..<end])
            let timeOffset = Double(offset) / AudioCaptureService.sampleRate
            do {
                let chunk = try await Self.decodeWindow(
                    kit: kit,
                    samples: slice,
                    language: resolvedLanguage,
                    includeTimestamps: includeTimestamps,
                    timeOffset: timeOffset
                )
                segments.append(contentsOf: chunk.segments)
                if !chunk.text.isEmpty {
                    texts.append(chunk.text)
                }
            } catch TranscriptionError.noSpeech {
                // Skip silent windows in long files.
            }
            offset = end
            progress?(min(1, Double(end) / Double(samples.count)))
        }

        let text = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.noSpeech
        }
        return TranscriptionOutput(text: text, segments: segments)
    }

    private static func decodeWindow(
        kit: WhisperKit,
        samples: [Float],
        language: String?,
        includeTimestamps: Bool,
        timeOffset: TimeInterval
    ) async throws -> TranscriptionOutput {
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperatureFallbackCount: 2,
            usePrefillPrompt: language != nil,
            usePrefillCache: false,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: !includeTimestamps,
            noSpeechThreshold: 0.9,
            concurrentWorkerCount: 1,
            chunkingStrategy: ChunkingStrategy.none
        )

        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        try Task.checkCancellation()
        let output = TranscriptionOutput.from(results: results, timeOffset: timeOffset)
        if output.text.isEmpty {
            throw TranscriptionError.noSpeech
        }
        return output
    }

    private static func detectSpokenLanguage(kit: WhisperKit, samples: [Float]) async throws -> String? {
        do {
            let detected = try await kit.detectLangauge(audioArray: samples)
            return detected.language
        } catch {
            return nil
        }
    }
}

struct TranscriptionOutput: Sendable {
    var text: String
    var segments: [TranscriptSegment]

    static func from(results: [TranscriptionResult], timeOffset: TimeInterval) -> TranscriptionOutput {
        var segments: [TranscriptSegment] = []
        var texts: [String] = []
        for result in results {
            let cleaned = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                texts.append(cleaned)
            }
            for segment in result.segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                segments.append(
                    TranscriptSegment(
                        start: timeOffset + TimeInterval(segment.start),
                        end: timeOffset + TimeInterval(max(segment.end, segment.start)),
                        text: text
                    )
                )
            }
        }

        let text = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if segments.isEmpty, !text.isEmpty {
            segments = [
                TranscriptSegment(start: timeOffset, end: timeOffset, text: text)
            ]
        }
        return TranscriptionOutput(text: text, segments: segments)
    }
}
