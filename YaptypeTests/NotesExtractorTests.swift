import XCTest
@testable import Yaptype

final class NotesExtractorTests: XCTestCase {
    func testExtractsActionItems() {
        let notes = NotesExtractor.extract(
            "We should keep the first version simple. Add summaries later. Let's finalize the Note Taker UI."
        )
        XCTAssertTrue(notes.contains("Key points"))
        XCTAssertTrue(notes.contains("Action items"))
        XCTAssertTrue(notes.contains("finalize"))
    }

    func testEmptyTranscript() {
        let notes = NotesExtractor.extract("   ")
        XCTAssertTrue(notes.contains("None yet"))
    }
}

final class HistoryItemDecodingTests: XCTestCase {
    func testDecodesLegacyDictationJSON() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "createdAt": "2026-09-18T01:00:00Z",
          "rawText": "um hello",
          "polishedText": "Hello.",
          "modelID": "tiny.en",
          "rewriteEngine": "Rules",
          "audioSeconds": 1.2,
          "transcribeMs": 180,
          "rewriteMs": 40,
          "insertMs": 12
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(HistoryItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.kind, .dictation)
        XCTAssertEqual(item.displayText, "Hello.")
        XCTAssertTrue(item.segments.isEmpty)
    }

    func testTimestampedFileText() {
        let segments = [
            TranscriptSegment(start: 8, end: 12, text: "Hello there.")
        ]
        let text = segments.timestampedText(fallback: "Hello there.")
        XCTAssertEqual(text, "[00:08] Hello there.")
    }
}
