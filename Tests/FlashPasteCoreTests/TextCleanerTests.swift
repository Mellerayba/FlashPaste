import XCTest
@testable import FlashPasteCore

final class TextCleanerTests: XCTestCase {
    let clean = CleanOptions(joinLines: true, stripBullets: false)

    func testJoinsHardLineBreaksAndCollapsesWhitespace() {
        let input = "  The mitochondria is\nthe   powerhouse\tof\n the cell.  "
        XCTAssertEqual(TextCleaner.clean(input, options: clean), "The mitochondria is the powerhouse of the cell.")
    }

    func testFixesHyphenationAcrossLines() {
        XCTAssertEqual(TextCleaner.clean("infor-\nmation theory", options: clean), "information theory")
        // A hyphen before an uppercase continuation is a real compound, keep it.
        XCTAssertEqual(TextCleaner.clean("Jean-\nPaul", options: clean), "Jean- Paul")
    }

    func testKeepsParagraphBreaks() {
        XCTAssertEqual(TextCleaner.clean("one\ntwo\n\n  three\nfour", options: clean), "one two\nthree four")
    }

    func testWindowsLineEndings() {
        XCTAssertEqual(TextCleaner.clean("a\r\nb", options: clean), "a b")
    }

    func testCleanOffLeavesTextUntouched() {
        let raw = "  keep\nthis   as-is \n"
        XCTAssertEqual(TextCleaner.clean(raw, options: CleanOptions(joinLines: false, stripBullets: false)), raw)
    }

    func testStripsBulletsAndNumbering() {
        let opts = CleanOptions(joinLines: false, stripBullets: true)
        XCTAssertEqual(TextCleaner.clean("• apple\n- pear\n1. plum\n(2) fig\na) kiwi\n12) lime", options: opts),
                       "apple\npear\nplum\nfig\nkiwi\nlime")
        XCTAssertEqual(TextCleaner.clean("3.14 is pi", options: opts), "3.14 is pi")
        XCTAssertEqual(TextCleaner.clean("A dog", options: opts), "A dog")
    }

    func testBulletsAndJoinTogether() {
        let opts = CleanOptions(joinLines: true, stripBullets: true)
        XCTAssertEqual(TextCleaner.clean("• first\n  line\n\n• second", options: opts), "first line\nsecond")
    }
}
