import Foundation
import WhisperKit

@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published private(set) var installedIDs: Set<String> = []
    @Published private(set) var downloadingID: String?
    @Published private(set) var downloadProgress: Double = 0
    @Published var lastError: String?

    let downloadBase: URL
    let mlxDownloadBase: URL

    init() {
        let root = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cadence", isDirectory: true)
        downloadBase = root.appendingPathComponent("Models", isDirectory: true)
        mlxDownloadBase = root.appendingPathComponent("MLX", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadBase, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: mlxDownloadBase, withIntermediateDirectories: true)
        refreshInstalled()
    }

    func isInstalled(_ spec: WhisperModelSpec) -> Bool {
        installedIDs.contains(spec.id)
    }

    func folder(for spec: WhisperModelSpec) -> URL? {
        folder(forModelID: spec.id)
    }

    func refreshInstalled() {
        installedIDs = Set(
            WhisperModelSpec.all.compactMap { spec in
                folder(forModelID: spec.id) == nil ? nil : spec.id
            }
        )
    }

    func download(_ spec: WhisperModelSpec) async throws {
        lastError = nil
        downloadingID = spec.id
        downloadProgress = 0
        defer {
            downloadingID = nil
            downloadProgress = 0
        }

        _ = try await WhisperKit.download(
            variant: spec.id,
            downloadBase: downloadBase,
            useBackgroundSession: false
        ) { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        refreshInstalled()
        if !installedIDs.contains(spec.id) {
            throw TranscriptionError.modelMissing(spec.id)
        }
    }

    func delete(_ spec: WhisperModelSpec) throws {
        guard let folder = folder(forModelID: spec.id) else { return }
        try FileManager.default.removeItem(at: folder)
        refreshInstalled()
    }

    func folder(forModelID id: String) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: downloadBase,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let needle = "openai_whisper-\(id)"
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name == id || name == needle {
                if hasModelPayload(url) {
                    return url
                }
            }
        }
        return nil
    }

    private func hasModelPayload(_ url: URL) -> Bool {
        let fm = FileManager.default
        let markers = [
            url.appendingPathComponent("config.json"),
            url.appendingPathComponent("AudioEncoder.mlmodelc"),
            url.appendingPathComponent("MelSpectrogram.mlmodelc")
        ]
        return markers.contains { fm.fileExists(atPath: $0.path) }
    }
}

enum TranscriptionError: LocalizedError {
    case modelMissing(String)
    case emptyAudio
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing(let id):
            "Whisper model “\(id)” is not downloaded yet."
        case .emptyAudio:
            "That recording was too short to transcribe."
        case .failed(let message):
            message
        }
    }
}
