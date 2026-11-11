import XCTest
@testable import FlashPasteCore

final class CardStateTests: XCTestCase {
    var config = Config()

    override func setUp() {
        config = Config()
        config.tabsAfterTerm = 1
        config.tabsAfterDef = 2
    }

    func testAlternatesAcrossSeveralCards() {
        var state = CardState()
        XCTAssertEqual(state.nextField, .term)
        for _ in 0..<3 {
            XCTAssertEqual(state.didPaste(config: config), PasteRecord(field: .term, tabs: 1))
            XCTAssertEqual(state.nextField, .def)
            XCTAssertEqual(state.didPaste(config: config), PasteRecord(field: .def, tabs: 2))
            XCTAssertEqual(state.nextField, .term)
        }
    }

    func testResetReturnsToTerm() {
        var state = CardState()
        state.didPaste(config: config)
        XCTAssertEqual(state.nextField, .def)
        state.reset()
        XCTAssertEqual(state.nextField, .term)
        XCTAssertNil(state.undo())
    }

    func testUndoStepsBackOnce() {
        var state = CardState()
        state.didPaste(config: config)
        state.didPaste(config: config)
        XCTAssertEqual(state.nextField, .term)
        XCTAssertEqual(state.undo(), PasteRecord(field: .def, tabs: 2))
        XCTAssertEqual(state.nextField, .def)
        XCTAssertNil(state.undo(), "only one level of undo")
    }
}
