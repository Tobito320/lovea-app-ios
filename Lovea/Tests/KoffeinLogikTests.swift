import XCTest
@testable import Lovea

/// R10 "Dein Tag" bearbeiten: reine Logik der Koffein-Kachel (Tagebuch-Verknüpfung) und des
/// generischen Bearbeiten-Blatts (`ZaehlerBlatt`).
final class KoffeinLogikTests: XCTestCase {

    // MARK: - Id-Schema

    func testEintragIdIstDeterministischProTagUndTasse() {
        XCTAssertEqual(KoffeinLogik.eintragId("2026-10-01", 1), "koffein-2026-10-01-1")
        XCTAssertEqual(KoffeinLogik.eintragId("2026-10-01", 2), "koffein-2026-10-01-2")
        XCTAssertNotEqual(KoffeinLogik.eintragId("2026-10-01", 1), KoffeinLogik.eintragId("2026-10-02", 1))
    }

    // MARK: - Differenz beim Bearbeiten-Blatt

    func testIndizesLoeschenBeiVerringerung() {
        XCTAssertEqual(KoffeinLogik.indizesLoeschen(alt: 5, neu: 2), [3, 4, 5])
        XCTAssertEqual(KoffeinLogik.indizesLoeschen(alt: 3, neu: 3), [])
        XCTAssertEqual(KoffeinLogik.indizesLoeschen(alt: 2, neu: 5), [])
    }

    func testIndizesAnlegenBeiErhoehung() {
        XCTAssertEqual(KoffeinLogik.indizesAnlegen(alt: 2, neu: 5), [3, 4, 5])
        XCTAssertEqual(KoffeinLogik.indizesAnlegen(alt: 3, neu: 3), [])
        XCTAssertEqual(KoffeinLogik.indizesAnlegen(alt: 5, neu: 2), [])
    }

    func testZuruecksetzenLoeschtAlleBisherigenTassen() {
        XCTAssertEqual(KoffeinLogik.indizesLoeschen(alt: 4, neu: 0), [1, 2, 3, 4])
    }

    // MARK: - Mahlzeit nach Uhrzeit (brauchts für den Tagebuch-Eintrag beim Tippen)

    func testMahlzeitZurZeit() {
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 8), .fruehstueck)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 12), .mittag)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 19), .abend)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 23), .snack)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 2), .snack)
    }

    // MARK: - Bearbeiten-Blatt: Klemmen auf den Stepper-Bereich

    func testGeklemmtHaeltSichAnDenBereich() {
        XCTAssertEqual(ZaehlerLogik.geklemmt(-3, in: 0...20), 0)
        XCTAssertEqual(ZaehlerLogik.geklemmt(25, in: 0...20), 20)
        XCTAssertEqual(ZaehlerLogik.geklemmt(5, in: 0...20), 5)
    }

    // MARK: - Fallback-Lebensmittel (ohne BLS-Index)

    func testFallbackKaffeeIstFluessigMitTasse() {
        let l = KoffeinLogik.fallbackKaffee
        XCTAssertTrue(l.fluessig)
        XCTAssertEqual(l.portionMenge, 200)
    }
}
