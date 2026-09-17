import Foundation
import WhisperKit

@MainActor
final class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadedModelID: String?
    @Published var lastError: String?

    private var pipe: WhisperKit?
    private let manager = ModelManager.shared

    func prewarm(modelID: String) async {
        if loadedModelID == modelID, pipe != nil {
            isReady = true
            return
        }
        isLoading = true
        lastError = nil
        isReady = false
        defer { isLoading = false }

        do {
            pipe = try await makePipeline(modelID: modelID)
            loadedModelID = modelID
            isReady = true
        } catch {
            pipe = nil
            loadedModelID = nil
            isReady = false
            lastError = error.localizedDescription
        }
    }

    func transcribe(
        samples: [Float],
        modelID: String,
        language: TranscriptionLanguage
    ) async throws -> String {
        guard samples.count > Int(AudioCaptureService.sampleRate * 0.25) else {
            throw TranscriptionError.emptyAudio
        }

        if loadedModelID != modelID || pipe == nil {
            await prewarm(modelID: modelID)
        }
        guard let pipe else {
            throw TranscriptionError.modelMissing(modelID)
        }

        let detect = language == .auto
        let options = DecodingOptions(
            task: .transcribe,
            language: detect ? nil : language.rawValue,
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            detectLanguage: detect,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.failed("Whisper returned an empty transcript.")
        }
        return text
    }

    private func makePipeline(modelID: String) async throws -> WhisperKit {
        let localFolder = manager.folder(forModelID: modelID)
        let config = WhisperKitConfig(
            model: modelID,
            downloadBase: manager.downloadBase,
            modelFolder: localFolder?.path,
            tokenizerFolder: manager.downloadBase,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: localFolder == nil
        )
        return try await WhisperKit(config)
    }
}
