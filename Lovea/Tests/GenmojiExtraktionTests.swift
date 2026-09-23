import UIKit
import XCTest
@testable import Lovea

/// Pure logic (Z-26.1): what a composed attributed string turns into on send.
/// `NSAdaptiveImageGlyph(imageContent:)` itself isn't exercised here — its behavior on malformed
/// bytes isn't something this environment (no local compiler/simulator) can verify safely, and
/// `glyphBilder` only ever casts an already-attached value, never constructs one.
@MainActor
final class GenmojiExtraktionTests: XCTestCase {
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
