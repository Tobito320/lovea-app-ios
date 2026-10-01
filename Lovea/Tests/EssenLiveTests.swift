import XCTest
@testable import Lovea

/// Reine Live-Activity-Berechnung: Summe der Einträge gegen die Ziele, ohne ActivityKit.
final class EssenLiveTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-1", name: "Skyr", pro100: Naehrwerte(kcal: 62, protein: 11, kohlenhydrate: 4, fett: 0.2),
                                    portionMenge: 150, packungMenge: 450)

    private func eintrag(_ menge: Double, _ mahlzeit: Mahlzeit = .fruehstueck) -> EssenEintrag {
        EssenEintrag(id: UUID().uuidString, datum: "2026-10-01", mahlzeit: mahlzeit, menge: menge, einheit: .g,
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
        XCTAssertEqual(stand.mahlzeitenKcal, [0, 0, 0, 0])
    }

    func testStandMahlzeitenKcalProMahlzeit() {
        let z = ErnaehrungsZiele(kcal: 2000, protein: 120, kohlenhydrate: 220, fett: 70)
        let eintraege = [eintrag(200, .fruehstueck), eintrag(100, .mittag), eintrag(100, .mittag), eintrag(50, .snack)]
        let stand = EssenLiveLogik.stand(eintraege, ziele: z, tag: "2026-10-01")
        // Reihenfolge: fruehstueck, mittag, abend, snack. 100 g Skyr = 62 kcal.
        XCTAssertEqual(stand.mahlzeitenKcal, [124, 124, 0, 31])
        XCTAssertEqual(stand.kcal, 124 + 124 + 31)
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

    // MARK: - R8 Review (Critical): alte Aktivität ohne Mahlzeitendaten

    func testAktionVeralteteAktivitaetStartetNeuTrotzGleichemTag() {
        XCTAssertEqual(
            EssenLive.aktion(laufendTag: "2026-10-01", heute: "2026-10-01", an: true, laufendVeraltet: true),
            .neuStarten)
    }

    func testIstVeraltetErkenntFehlendeMahlzeitenDaten() {
        let alt = EssenAktivitaet.ContentState(
            kcal: 930, kcalZiel: 2630, proteinG: 16, proteinZiel: 138, kohlenhydrateG: 90, kohlenhydrateZiel: 300,
            fettG: 30, fettZiel: 80, mahlzeitenKcal: [0, 0, 0, 0], tag: "2026-10-01")
        XCTAssertTrue(EssenLive.istVeraltet(alt))
    }

    func testIstVeraltetFalseWennLeereMahlzeitenEchtSind() {
        // Frisch gestartete Aktivität an einem Tag ganz ohne Einträge: kcal 0, Mahlzeiten auch 0 —
        // das ist kein altes Format, sondern ein echter leerer Tag.
        let leer = EssenAktivitaet.ContentState(
            kcal: 0, kcalZiel: 2000, proteinG: 0, proteinZiel: 120, kohlenhydrateG: 0, kohlenhydrateZiel: 220,
            fettG: 0, fettZiel: 70, mahlzeitenKcal: [0, 0, 0, 0], tag: "2026-10-01")
        XCTAssertFalse(EssenLive.istVeraltet(leer))
    }

    // MARK: - R8 Review (Critical): Decodieren eines ContentState im alten Format

    func testDecodeAltesFormatOhneMahlzeitenKcalUndOhneTag() throws {
        // Format von d8ef816 (R7, erster TestFlight-Stand): weder `mahlzeitenKcal` noch `tag`.
        let json = """
        {"kcal":930,"kcalZiel":2630,"proteinG":16,"proteinZiel":138,"kohlenhydrateG":90,
         "kohlenhydrateZiel":300,"fettG":30,"fettZiel":80}
        """.data(using: .utf8)!
        let stand = try JSONDecoder().decode(EssenAktivitaet.ContentState.self, from: json)
        XCTAssertEqual(stand.kcal, 930)
        XCTAssertEqual(stand.kcalZiel, 2630)
        XCTAssertEqual(stand.mahlzeitenKcal, [0, 0, 0, 0])
        XCTAssertEqual(stand.tag, "")
        XCTAssertTrue(EssenLive.istVeraltet(stand))
    }

    func testDecodeAltesFormatMitTagOhneMahlzeitenKcal() throws {
        // Format von edf2f2d (R7-Fix, der TestFlight-Stand mit Tageswechsel-Erkennung): hat `tag`,
        // aber noch kein `mahlzeitenKcal`.
        let json = """
        {"kcal":930,"kcalZiel":2630,"proteinG":16,"proteinZiel":138,"kohlenhydrateG":90,
         "kohlenhydrateZiel":300,"fettG":30,"fettZiel":80,"tag":"2026-10-01"}
        """.data(using: .utf8)!
        let stand = try JSONDecoder().decode(EssenAktivitaet.ContentState.self, from: json)
        XCTAssertEqual(stand.tag, "2026-10-01")
        XCTAssertEqual(stand.mahlzeitenKcal, [0, 0, 0, 0])
        XCTAssertTrue(EssenLive.istVeraltet(stand))
    }

    func testDecodeNeuesFormatRoundtrip() throws {
        let original = EssenAktivitaet.ContentState(
            kcal: 930, kcalZiel: 2630, proteinG: 16, proteinZiel: 138, kohlenhydrateG: 90, kohlenhydrateZiel: 300,
            fettG: 30, fettZiel: 80, mahlzeitenKcal: [200, 400, 300, 30], tag: "2026-10-01")
        let daten = try JSONEncoder().encode(original)
        let zurueck = try JSONDecoder().decode(EssenAktivitaet.ContentState.self, from: daten)
        XCTAssertEqual(zurueck, original)
        XCTAssertFalse(EssenLive.istVeraltet(zurueck))
    }
}
