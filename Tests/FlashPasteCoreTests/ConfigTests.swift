import XCTest
@testable import FlashPasteCore

final class ConfigTests: XCTestCase {
    func testDefaults() {
        let c = Config()
        XCTAssertEqual(c.sourceApps, ["com.apple.Safari", "com.apple.Preview"])
        XCTAssertEqual(c.quizletApps, ["com.apple.Safari"])
        XCTAssertEqual(c.quizletTitlePattern, "Quizlet")
        XCTAssertEqual(c.focusDelay, 0.15)
        XCTAssertEqual(c.tabsAfterTerm, 1)
        XCTAssertEqual(c.tabsAfterDef, 1)
        XCTAssertTrue(c[.cleanPDFText])
        for t in Toggle.allCases where t != .cleanPDFText { XCTAssertFalse(c[t], t.rawValue) }
    }

    func testParsesValues() {
        let json = """
        {"sourceApps":["a"],"quizletApps":["b"],"quizletTitlePattern":"Flash","focusDelay":0.5,
         "tabsAfterTerm":3,"tabsAfterDef":4,"cleanPDFText":false,"autoPause":true}
        """
        let r = Config.parse(Data(json.utf8))
        XCTAssertTrue(r.warnings.isEmpty)
        XCTAssertEqual(r.config.sourceApps, ["a"])
        XCTAssertEqual(r.config.quizletApps, ["b"])
        XCTAssertEqual(r.config.quizletTitlePattern, "Flash")
        XCTAssertEqual(r.config.focusDelay, 0.5)
        XCTAssertEqual(r.config.tabsAfterTerm, 3)
        XCTAssertEqual(r.config.tabsAfterDef, 4)
        XCTAssertFalse(r.config[.cleanPDFText])
        XCTAssertTrue(r.config[.autoPause])
    }

    func testBadJSONFallsBackToDefaults() {
        let r = Config.parse(Data("{not json".utf8))
        XCTAssertEqual(r.config, Config())
        XCTAssertEqual(r.warnings.count, 1)
        let array = Config.parse(Data("[1,2]".utf8))
        XCTAssertEqual(array.config, Config())
    }

    func testBadValuesFallBackPerKey() {
        let r = Config.parse(Data(#"{"tabsAfterTerm":"two","focusDelay":-1,"quizletApps":[],"tabsAfterDef":5}"#.utf8))
        XCTAssertEqual(r.config.tabsAfterTerm, 1)
        XCTAssertEqual(r.config.focusDelay, 0.15)
        XCTAssertEqual(r.config.quizletApps, ["com.apple.Safari"])
        XCTAssertEqual(r.config.tabsAfterDef, 5)
        XCTAssertEqual(r.warnings.count, 3)
    }

    func testUnknownKeysSurviveRoundTrip() throws {
        let r = Config.parse(Data(#"{"futureKey":{"x":1},"tabsAfterDef":7}"#.utf8))
        var c = r.config
        c[.stripBullets] = true
        let again = Config.parse(try c.jsonData())
        XCTAssertEqual(again.config, c)
        XCTAssertEqual(again.config.unknown["futureKey"] as? [String: Int], ["x": 1])
        XCTAssertEqual(again.config.tabsAfterDef, 7)
        XCTAssertTrue(again.config[.stripBullets])
    }
}
