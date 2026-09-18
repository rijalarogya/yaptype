import XCTest
@testable import Yaptype

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

    func testLeavesNonLatinUnchanged() {
        let hindi = "नमस्ते दुनिया"
        XCTAssertEqual(RuleBasedRewriter.rewrite(hindi), hindi)
        let chinese = "你好世界"
        XCTAssertEqual(RuleBasedRewriter.rewrite(chinese), chinese)
    }

    func testFixesDoYouGoYesterday() {
        XCTAssertEqual(
            RuleBasedRewriter.rewrite("Hi, do you go to college yesterday?"),
            "Hi, did you go to college yesterday?"
        )
    }

    func testFixesDoYouGoLastNight() {
        XCTAssertEqual(
            RuleBasedRewriter.rewrite("do you go last night"),
            "Did you go last night."
        )
    }

    func testDoesNotChangePresentTenseWithoutPastTime() {
        XCTAssertEqual(
            RuleBasedRewriter.rewrite("do you go to college"),
            "Do you go to college."
        )
    }
}
