import XCTest
@testable import Lovea

@MainActor
final class PunkteAufschluesselungTests: XCTestCase {
    private func e(_ datum: String, _ grund: String, _ punkte: Int) -> PunkteLogik.Eintrag {
        PunkteLogik.Eintrag(datum: datum, von: .ahmed, grund: grund, punkte: punkte)
    }

    func testKategorieNachGrund() {
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Tag"), .tag)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Gym-Wochenziel"), .gym)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Serie 7 Tage"), .serie)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Gemeinsam Monat"), .gemeinsam)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Duell der Woche"), .duell)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Kauf: Cap"), .shop)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Geschenk: Kette"), .shop)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("Schrittziel"), .schritte)
        XCTAssertEqual(PunkteAufschluesselung.kategorie("etwas Neues"), .sonstiges)
    }

    func testGruppenSummierenUndSortieren() {
        let gruppen = PunkteAufschluesselung.gruppen([
            e("2026-09-21", "Tag", 50), e("2026-09-22", "Tag", 70),
            e("2026-09-22", "Gym-Wochenziel", 80), e("2026-09-23", "Kauf: Cap", -200),
        ])
        XCTAssertEqual(gruppen.map(\.kategorie), [.tag, .gym, .shop])
        XCTAssertEqual(gruppen.map(\.summe), [120, 80, -200])
        XCTAssertEqual(gruppen[0].eintraege.first?.datum, "2026-09-22") // neueste zuerst
    }

    func testWocheZaehltNurVerdientesJeTag() {
        let woche = PunkteAufschluesselung.woche([
            e("2026-09-21", "Tag", 50), e("2026-09-21", "Gym-Wochenziel", 80),
            e("2026-09-23", "Kauf: Cap", -200), e("2026-09-28", "Tag", 10),
        ], montag: "2026-09-21")
        XCTAssertEqual(woche.count, 7)
        XCTAssertEqual(woche.first?.tag, "2026-09-21")
        XCTAssertEqual(woche.last?.tag, "2026-09-27")
        XCTAssertEqual(woche.map { $0.punkte }, [130, 0, 0, 0, 0, 0, 0])
    }

    /// Die angezeigten Regeln müssen zu `PunkteLogik.tagesPunkte` passen.
    func testRegelnPassenZuTagesPunkten() {
        let r = PunkteRegeln.self
        let voll = PunkteLogik.tagesPunkte(schritte: 40_000, zielSchritte: 10_000, gymAbgehakt: true, wasser: 8, zielWasser: 8, chatStreakTag: false, spieleGewonnen: 1)
        XCTAssertEqual(voll, r.schritteMaxProTag + r.schrittziel + r.fuenfzehnTausend + r.gymTag + r.wasserziel + r.spielSieg)
        let wenig = PunkteLogik.tagesPunkte(schritte: 500, zielSchritte: 10_000, gymAbgehakt: false, wasser: 0, zielWasser: 8, chatStreakTag: false, spieleGewonnen: 0)
        XCTAssertEqual(wenig, 5 * r.schrittProHundert)
    }
}
