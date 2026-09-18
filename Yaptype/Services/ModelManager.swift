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
    private var folderCache: [String: URL] = [:]

    init() {
        let root = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Yaptype", isDirectory: true)
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
        folderCache.removeAll()
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

        let folder: URL
        do {
            folder = try await WhisperKit.download(
                variant: spec.id,
                downloadBase: downloadBase,
                useBackgroundSession: false
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress.fractionCompleted
                }
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }

        if hasModelPayload(folder) {
            folderCache[spec.id] = folder
        }
        let kept = folderCache[spec.id]
        refreshInstalled()
        if let kept, hasModelPayload(kept) {
            folderCache[spec.id] = kept
            installedIDs.insert(spec.id)
        }
        if !installedIDs.contains(spec.id) {
            lastError = "Downloaded \(spec.title), but Yaptype could not find the model files."
            throw TranscriptionError.modelMissing(spec.id)
        }
    }

    func delete(_ spec: WhisperModelSpec) throws {
        guard let folder = folder(forModelID: spec.id) else { return }
        try FileManager.default.removeItem(at: folder)
        refreshInstalled()
    }

    func folder(forModelID id: String) -> URL? {
        if let cached = folderCache[id], hasModelPayload(cached) {
            return cached
        }
        let names = [id, "openai_whisper-\(id)"]
        for candidate in knownFolders(for: names) where hasModelPayload(candidate) {
            folderCache[id] = candidate
            return candidate
        }
        if let found = findModelFolder(named: Set(names)) {
            folderCache[id] = found
            return found
        }
        return nil
    }

    private func knownFolders(for names: [String]) -> [URL] {
        let hubRoot = downloadBase
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
        let slashRepo = downloadBase
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc/whisperkit-coreml", isDirectory: true)
        return names.flatMap { name in
            [
                downloadBase.appendingPathComponent(name, isDirectory: true),
                hubRoot.appendingPathComponent(name, isDirectory: true),
                slashRepo.appendingPathComponent(name, isDirectory: true)
            ]
        }
    }

    private func findModelFolder(named names: Set<String>) -> URL? {
        let fm = FileManager.default
        var queue: [(url: URL, depth: Int)] = [(downloadBase, 0)]
        var seen = Set<String>()

        while let item = queue.first {
            queue.removeFirst()
            guard seen.insert(item.url.path).inserted else { continue }
            if names.contains(item.url.lastPathComponent), hasModelPayload(item.url) {
                return item.url
            }
            guard item.depth < 6 else { continue }
            guard let children = try? fm.contentsOfDirectory(
                at: item.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                let name = child.lastPathComponent
                if name.hasSuffix(".mlmodelc") || name.hasSuffix(".mlpackage") { continue }
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: child.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                queue.append((child, item.depth + 1))
            }
        }
        return nil
    }

    private func hasModelPayload(_ url: URL) -> Bool {
        let fm = FileManager.default
        let encoder = url.appendingPathComponent("AudioEncoder.mlmodelc")
        let mel = url.appendingPathComponent("MelSpectrogram.mlmodelc")
        return fm.fileExists(atPath: encoder.path) && fm.fileExists(atPath: mel.path)
    }

    func installedStorageBytes() -> Int64 {
        var total = WhisperModelSpec.all.reduce(Int64(0)) { sum, spec in
            installedIDs.contains(spec.id) ? sum + spec.approxBytes : sum
        }
        if isMLXInstalled(.recommended) {
            total += MLXModelSpec.recommended.approxBytes
        }
        return total
    }

    func mlxFolder(for spec: MLXModelSpec) -> URL {
        mlxDownloadBase
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(spec.huggingFaceID, isDirectory: true)
    }

    func isMLXInstalled(_ spec: MLXModelSpec) -> Bool {
        let fm = FileManager.default
        let direct = mlxFolder(for: spec).appendingPathComponent("config.json")
        if fm.fileExists(atPath: direct.path) {
            return true
        }
        let hub = mlxDownloadBase
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(spec.huggingFaceID, isDirectory: true)
            .appendingPathComponent("config.json")
        return fm.fileExists(atPath: hub.path)
    }
}
