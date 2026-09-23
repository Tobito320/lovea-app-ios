import UIKit
import XCTest
@testable import Lovea

/// Pure logic (Z-26.1): what a composed attributed string turns into on send. No live `UITextView`
/// needed — `NSAdaptiveImageGlyph` can be built directly from image bytes.
final class GenmojiExtraktionTests: XCTestCase {
    private static let bild1 = Data([0x01])
    private static let bild2 = Data([0x02])

    func testGlyphBilderExtrahiertJedesAngehaengteBild() {
        let text = NSMutableAttributedString(string: "hi \u{FFFC} da \u{FFFC}")
        text.addAttribute(.adaptiveImageGlyph, value: NSAdaptiveImageGlyph(imageContent: Self.bild1), range: NSRange(location: 3, length: 1))
        text.addAttribute(.adaptiveImageGlyph, value: NSAdaptiveImageGlyph(imageContent: Self.bild2), range: NSRange(location: 8, length: 1))

        XCTAssertEqual(GenmojiExtraktion.glyphBilder(in: text), [Self.bild1, Self.bild2])
    }

    func testGlyphBilderIstLeerOhneAnhang() {
        XCTAssertEqual(GenmojiExtraktion.glyphBilder(in: NSAttributedString(string: "nur text")), [])
    }

    func testTextOhneGlyphenEntferntPlatzhalterUndTrimmt() {
        let text = NSAttributedString(string: "  hi \u{FFFC} da \u{FFFC}  ")
        XCTAssertEqual(GenmojiExtraktion.textOhneGlyphen(text), "hi  da")
    }

    func testTextOhneGlyphenIstLeerFuerNurEinenAnhang() {
        let text = NSAttributedString(string: "\u{FFFC}")
        XCTAssertEqual(GenmojiExtraktion.textOhneGlyphen(text), "")
    }
}
