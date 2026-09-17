import XCTest
@testable import Yaptype

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testAppendAndClear() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yaptype-history-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: url)
        XCTAssertTrue(store.items.isEmpty)

        store.append(
            HistoryItem(
                id: UUID(),
                createdAt: Date(),
                rawText: "um hello",
                polishedText: "Hello.",
                modelID: "tiny.en",
                rewriteEngine: "Rules",
                audioSeconds: 1.2,
                transcribeMs: 180,
                rewriteMs: 40,
                insertMs: 12
            )
        )
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.displayText, "Hello.")

        store.clear()
        XCTAssertTrue(store.items.isEmpty)
        try? FileManager.default.removeItem(at: url)
    }
}
