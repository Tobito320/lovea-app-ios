import XCTest
@testable import Lovea

/// Tap-to-place math of the new snap editor (p43): where a tap puts the text, and what counts as a tap.
final class SnapTextPlatzTests: XCTestCase {
    func testTippInDerMitteGibtMitteAlsBruchteil() {
        let ort = SnapTextPlatz.bruchteil(punkt: CGPoint(x: 150, y: 300), groesse: CGSize(width: 300, height: 600))
        XCTAssertEqual(ort.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(ort.y, 0.5, accuracy: 0.0001)
    }

    func testTippAmRandWirdAufDasBildBegrenzt() {
        let links = SnapTextPlatz.bruchteil(punkt: CGPoint(x: 0, y: 0), groesse: CGSize(width: 300, height: 600))
        XCTAssertEqual(links.x, SnapTextPlatz.xBereich.lowerBound, accuracy: 0.0001)
        XCTAssertEqual(links.y, SnapTextPlatz.yBereich.lowerBound, accuracy: 0.0001)
        let rechts = SnapTextPlatz.bruchteil(punkt: CGPoint(x: 300, y: 600), groesse: CGSize(width: 300, height: 600))
        XCTAssertEqual(rechts.x, SnapTextPlatz.xBereich.upperBound, accuracy: 0.0001)
        XCTAssertEqual(rechts.y, SnapTextPlatz.yBereich.upperBound, accuracy: 0.0001)
    }

    func testNullGroesseGibtMitteStattNaN() {
        let ort = SnapTextPlatz.bruchteil(punkt: CGPoint(x: 10, y: 10), groesse: .zero)
        XCTAssertEqual(ort, CGPoint(x: 0.5, y: 0.5))
    }

    func testKleineBewegungIstTippen() {
        XCTAssertTrue(SnapTextPlatz.istTippen(CGSize(width: 3, height: -4)))
        XCTAssertTrue(SnapTextPlatz.istTippen(.zero))
    }

    func testWischUndZugSindKeinTippen() {
        XCTAssertFalse(SnapTextPlatz.istTippen(CGSize(width: 40, height: 2)))
        XCTAssertFalse(SnapTextPlatz.istTippen(CGSize(width: 1, height: -12)))
    }

    func testNeuerTextStartetInDerMitte() {
        let text = SnapEditor.SnapText()
        XCTAssertEqual(text.x, 0.5)
        XCTAssertEqual(text.y, 0.5)
        XCTAssertEqual(text.skala, 1)
    }

    func testZiehenBegrenztBeideAchsen() {
        let ort = SnapTextPlatz.begrenzt(x: -2, y: 5)
        XCTAssertEqual(ort.x, SnapTextPlatz.xBereich.lowerBound)
        XCTAssertEqual(ort.y, SnapTextPlatz.yBereich.upperBound)
    }
}
