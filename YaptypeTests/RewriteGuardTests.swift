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

    func testRejectsTranslationToEnglish() {
        XCTAssertFalse(
            RewriteGuard.isFaithfulRewrite(
                original: "你好世界 今天天气很好",
                candidate: "Hello world. The weather is nice today."
            )
        )
    }

    func testKeepsSameLanguageCleanup() {
        XCTAssertTrue(
            RewriteGuard.isFaithfulRewrite(
                original: "hola mundo esto es una prueba",
                candidate: "Hola mundo, esto es una prueba."
            )
        )
    }

    func testAllowsDoToDidTenseFix() {
        XCTAssertTrue(
            RewriteGuard.isFaithfulRewrite(
                original: "Hi, do you go to college yesterday?",
                candidate: "Hi, did you go to college yesterday?"
            )
        )
    }

    func testRejectsChattyCollegeRewrite() {
        XCTAssertFalse(
            RewriteGuard.isFaithfulRewrite(
                original: "Hi, do you go to college yesterday?",
                candidate: "Hi, did you attend university yesterday? How was it?"
            )
        )
    }
}
