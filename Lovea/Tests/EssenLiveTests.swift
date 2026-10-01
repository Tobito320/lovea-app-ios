import XCTest
@testable import Lovea

/// Reine Live-Activity-Berechnung: Summe der Einträge gegen die Ziele, ohne ActivityKit.
final class EssenLiveTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-1", name: "Skyr", pro100: Naehrwerte(kcal: 62, protein: 11, kohlenhydrate: 4, fett: 0.2),
                                    portionMenge: 150, packungMenge: 450)

    private func eintrag(_ menge: Double) -> EssenEintrag {
        EssenEintrag(id: UUID().uuidString, datum: "2026-10-01", mahlzeit: .fruehstueck, menge: menge, einheit: .g,
                    lebensmittel: skyr, geloescht: nil)
    }

    func testStandAusEintraegenUndZielen() {
        let z = ErnaehrungsZiele(kcal: 2000, protein: 120, kohlenhydrate: 220, fett: 70)
        let stand = EssenLiveLogik.stand([eintrag(200), eintrag(100)], ziele: z, tag: "2026-10-01")
        // 300 g Skyr: 186 kcal, 33 g Protein, 12 g Kohlenhydrate, 0,6 g Fett
        XCTAssertEqual(stand.kcal, 186)
        XCTAssertEqual(stand.proteinG, 33)
        XCTAssertEqual(stand.kohlenhydrateG, 12)
        XCTAssertEqual(stand.fettG, 1)
        XCTAssertEqual(stand.kcalZiel, 2000)
        XCTAssertEqual(stand.proteinZiel, 120)
        XCTAssertEqual(stand.tag, "2026-10-01")
    }

    func testStandOhneEintraege() {
        let z = ErnaehrungsZiele(kcal: 1800, protein: 100, kohlenhydrate: 180, fett: 60)
        let stand = EssenLiveLogik.stand([], ziele: z, tag: "2026-10-01")
        XCTAssertEqual(stand.kcal, 0)
        XCTAssertEqual(stand.proteinG, 0)
        XCTAssertEqual(stand.kcalZiel, 1800)
    }

    // MARK: - Aktion (Mitternacht-Entscheidung, ohne ActivityKit)

    func testAktionGleicherTagAktualisiert() {
        XCTAssertEqual(EssenLive.aktion(laufendTag: "2026-10-01", heute: "2026-10-01", an: true), .aktualisieren)
    }

    func testAktionAndererTagStartetNeu() {
        XCTAssertEqual(EssenLive.aktion(laufendTag: "2026-09-30", heute: "2026-10-01", an: true), .neuStarten)
    }

    func testAktionKeineLaufendeStartetNeu() {
        XCTAssertEqual(EssenLive.aktion(laufendTag: nil, heute: "2026-10-01", an: true), .neuStarten)
    }

    func testAktionSchalterAusBeendet() {
        XCTAssertEqual(EssenLive.aktion(laufendTag: "2026-10-01", heute: "2026-10-01", an: false), .beenden)
        XCTAssertEqual(EssenLive.aktion(laufendTag: nil, heute: "2026-10-01", an: false), .beenden)
    }
}
