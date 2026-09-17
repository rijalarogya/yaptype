import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var items: [HistoryItem] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(fileURL: URL? = nil) {
        let defaultURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Yaptype", isDirectory: true)
            .appendingPathComponent("history.json")
        self.fileURL = fileURL ?? defaultURL
        load()
    }

    func append(_ item: HistoryItem) {
        items.insert(item, at: 0)
        if items.count > 200 {
            items = Array(items.prefix(200))
        }
        save()
    }

    func clear() {
        items = []
        save()
    }

    func delete(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try decoder.decode([HistoryItem].self, from: data)
        } catch {
            NSLog("Yaptype: failed to load history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Yaptype: failed to save history: \(error.localizedDescription)")
        }
    }
}
