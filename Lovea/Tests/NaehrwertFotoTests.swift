import XCTest
@testable import Lovea

final class NaehrwertFotoTests: XCTestCase {
    func testTypischeTabelle() {
        let z = ["Nährwerte pro 100 g", "Energie 1570 kJ / 375 kcal", "Fett 17 g", "davon gesättigte Fettsäuren 2,1 g",
                 "Kohlenhydrate 45 g", "davon Zucker 22 g", "Ballaststoffe 6,0 g", "Eiweiß 8,5 g", "Salz 0,45 g"]
        let n = NaehrwertLeser.parsen(z)
        XCTAssertEqual(n?.kcal, 375)
        XCTAssertEqual(n?.fett, 17)
        XCTAssertEqual(n?.gesFett, 2.1)
        XCTAssertEqual(n?.kohlenhydrate, 45)
        XCTAssertEqual(n?.zucker, 22)
        XCTAssertEqual(n?.protein, 8.5)
        XCTAssertEqual(n?.salz, 0.45)
    }

    func testNurKJ() {
        XCTAssertEqual(NaehrwertLeser.parsen(["Brennwert 418 kJ", "Eiweiß 3 g"])?.kcal ?? 0, 99.9, accuracy: 0.2)
    }

    func testZahlInNaechsterZeile() {
        let n = NaehrwertLeser.parsen(["Energie", "65 kcal", "Eiweiß", "11 g", "Fett", "0,2 g", "Kohlenhydrate", "4,4 g"])
        XCTAssertEqual(n?.kcal, 65)
        XCTAssertEqual(n?.protein, 11)
    }

    func testProPortionSpalteIgnoriert() {
        let n = NaehrwertLeser.parsen(["Energie 250 kcal 500 kcal", "Fett 10 g 20 g"])
        XCTAssertEqual(n?.kcal, 250)
        XCTAssertEqual(n?.fett, 10)
    }

    func testKeineZahlen() {
        XCTAssertNil(NaehrwertLeser.parsen(["Zutaten: Milch, Salz"]))
    }
}
