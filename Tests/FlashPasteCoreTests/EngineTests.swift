import XCTest
@testable import FlashPasteCore

final class FakeTap: Invalidatable {
    var invalidated = false
    func invalidate() { invalidated = true }
}

final class EngineTests: XCTestCase {
    func testEnableIsIdempotentAndDisableTearsDown() {
        var created: [FakeTap] = []
        let engine = Engine {
            let tap = FakeTap()
            created.append(tap)
            return [tap]
        }
        XCTAssertFalse(engine.isEnabled)
        XCTAssertTrue(engine.enable())
        XCTAssertTrue(engine.enable())
        XCTAssertEqual(created.count, 1, "second enable must not create a second tap")
        XCTAssertEqual(engine.resourceCount, 1)

        engine.setPending("x")
        engine.state.didPaste(config: Config())
        engine.disable()
        XCTAssertFalse(engine.isEnabled)
        XCTAssertTrue(created[0].invalidated)
        XCTAssertEqual(engine.resourceCount, 0)
        XCTAssertNil(engine.pending)
        XCTAssertEqual(engine.state.nextField, .term)

        engine.disable()
        XCTAssertTrue(engine.enable())
        XCTAssertEqual(created.count, 2)
        XCTAssertEqual(engine.resourceCount, 1, "exactly one live tap after enable/disable/enable")
    }

    func testEnableFailsWhenResourcesCannotBeCreated() {
        let engine = Engine { nil }
        XCTAssertFalse(engine.enable())
        XCTAssertFalse(engine.isEnabled)
    }

    func testPendingAndHistory() {
        let engine = Engine { [] }
        engine.enable()
        for i in 0..<12 { engine.setPending("item \(i)") }
        XCTAssertEqual(engine.pending, "item 11")
        XCTAssertEqual(engine.history.count, Engine.historyLimit)
        XCTAssertEqual(engine.history.first, "item 11")
        engine.setPending("item 11")
        XCTAssertEqual(engine.history.filter { $0 == "item 11" }.count, 1, "no duplicates")
        engine.clearPending()
        XCTAssertNil(engine.pending)
        XCTAssertEqual(engine.history.count, Engine.historyLimit, "skipping keeps history")
    }
}
