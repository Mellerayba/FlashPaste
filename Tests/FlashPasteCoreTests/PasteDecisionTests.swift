import XCTest
@testable import FlashPasteCore

final class PasteDecisionTests: XCTestCase {
    let config = Config()

    func ctx(pending: String? = "hello", app: String? = "com.apple.Safari", title: String? = "Create a set | Quizlet",
             source: Bool = false, enabled: Bool = true) -> PasteContext {
        PasteContext(pending: pending, appBundleID: app, windowTitle: title, isSourceWindow: source, enabled: enabled)
    }

    func testPastesInQuizletWindow() {
        XCTAssertTrue(PasteDecision.shouldPaste(ctx(), config: config))
        XCTAssertTrue(PasteDecision.shouldPaste(ctx(title: "quizlet.com"), config: config), "case-insensitive")
    }

    func testRefusals() {
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(pending: nil), config: config))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(pending: ""), config: config))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(app: "com.apple.Preview"), config: config))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(app: nil), config: config))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(title: "Apple"), config: config))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(title: nil), config: config))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(source: true), config: config), "same window as the selection")
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(enabled: false), config: config))
    }

    func testCustomPattern() {
        var c = Config()
        c.quizletTitlePattern = "Create a set"
        XCTAssertTrue(PasteDecision.shouldPaste(ctx(), config: c))
        XCTAssertFalse(PasteDecision.shouldPaste(ctx(title: "Quizlet home"), config: c))
    }
}
