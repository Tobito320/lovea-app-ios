import XCTest
@testable import Lovea

/// R10 "Dein Tag" bearbeiten: reine Logik des Bearbeiten-Blatts (`ZaehlerBlatt`/`ZaehlerLogik`) und
/// der Koffein-Kachel (Tagebuch-Verknüpfung).
///
/// Review-Fix: das alte Id-Schema `"koffein-<datum>-<n>"` leitete jede Tasse aus ihrer Position ab —
/// löschte man Tasse 1 von 3, verschob sich die Id von Tasse 2 und 3 unter der Haube. Jede Tasse
/// bekommt jetzt ihre eigene, zufällige Op-Id (`HeuteView.koffeinEintragen`, `HealthModell.
/// setzeHabitMitId`), deshalb testet hier nur noch die positionslose Auswahl-Logik
/// (`ZaehlerLogik.zuStreichen`), nicht mehr ein Id-Format.
final class KoffeinLogikTests: XCTestCase {

    // MARK: - Welche bekannten Einträge beim Verringern (Stepper, kein bestimmter Tipp) wegfallen

    func testZuStreichenNimmtDieJuengstenZuerst() {
        // älteste zuerst, wie `HealthModell.habitEintraege`.
        let bekannt = ["09:00", "12:00", "18:00"]
        XCTAssertEqual(ZaehlerLogik.zuStreichen(bekannt, alt: 3, neu: 1), ["18:00", "12:00"])
    }

    func testZuStreichenOhneAenderung() {
        XCTAssertEqual(ZaehlerLogik.zuStreichen(["a", "b"], alt: 2, neu: 2), [])
    }

    func testZuStreichenBeiErhoehungLeer() {
        XCTAssertEqual(ZaehlerLogik.zuStreichen(["a"], alt: 1, neu: 5), [])
    }

    func testZuStreichenAufNullNimmtAlleBekannten() {
        XCTAssertEqual(ZaehlerLogik.zuStreichen(["a", "b", "c"], alt: 3, neu: 0), ["c", "b", "a"])
    }

    func testZuStreichenKapptAnDenBekanntenWennWenigerAlsDieDifferenz() {
        // 5 insgesamt, aber nur 2 mit bekannter Zeit (Rest kam von anderswo/alten Daten) — mehr als
        // die zwei kann die Auswahl nicht liefern, der Aufrufer (`HeuteView.bulkSetzen`) setzt den
        // Rest dann über die reine Zahl.
        XCTAssertEqual(ZaehlerLogik.zuStreichen(["a", "b"], alt: 5, neu: 1), ["b", "a"])
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
