import XCTest
@testable import Yaptype

final class RewriteGuardTests: XCTestCase {
    func testKeepsCleanedDictation() {
        XCTAssertTrue(
            RewriteGuard.isFaithfulRewrite(
                original: "um hello world this is a test",
                candidate: "Hello world, this is a test."
            )
        )
    }

    func testRejectsChatReply() {
        XCTAssertFalse(
            RewriteGuard.isFaithfulRewrite(
                original: "how are you",
                candidate: "Hello! I'm doing well, thank you for asking. How about you?"
            )
        )
    }

    func testRejectsAdviceReply() {
        XCTAssertFalse(
            RewriteGuard.isFaithfulRewrite(
                original: "should I reinstall it",
                candidate: "Yes, I recommend reinstalling the tool. It's essential to ensure that you have the latest version."
            )
        )
    }
}
