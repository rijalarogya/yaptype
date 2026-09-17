import XCTest
@testable import Cadence

final class RuleBasedRewriterTests: XCTestCase {
    func testRemovesFillersAndCapitalizes() {
        let result = RuleBasedRewriter.rewrite("um hello there uh")
        XCTAssertTrue(result.hasPrefix("Hello there"))
        XCTAssertFalse(result.lowercased().contains("um"))
        XCTAssertFalse(result.lowercased().contains("uh"))
    }

    func testAddsEndingPunctuation() {
        let result = RuleBasedRewriter.rewrite("hello world")
        XCTAssertEqual(result, "Hello world.")
    }

    func testSpokenPunctuation() {
        let result = RuleBasedRewriter.rewrite("hello comma world period")
        XCTAssertTrue(result.contains(","))
        XCTAssertTrue(result.hasSuffix("."))
    }

    func testEmptyInput() {
        XCTAssertEqual(RuleBasedRewriter.rewrite("   "), "")
    }
}
