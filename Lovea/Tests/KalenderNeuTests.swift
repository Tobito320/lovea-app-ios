import XCTest
@testable import Lovea

/// Neuer Kalender (Variante C), Teil 1: reine Werte und Schalter. Zahlen sind Minuten seit
/// Mitternacht: 8:00 = 480, 16:30 = 990, 17:30 = 1050, 19:00 = 1140, 22:00 = 1320.
final class KalenderNeuTests: XCTestCase {

    private func block(_ titel: String = "x", typ: String = "sonstiges", _ start: String?, _ ende: String?,
                       status: String = "normal", quelle: String = "muster") -> Block {
        Block(titel: titel, typ: typ, start: start, ende: ende, status: status, quelle: quelle)
    }

    // MARK: - Schalter

    func testSchalterStandardAn() {
        let defaults = UserDefaults(suiteName: "lovea.test.kalenderNeu")!
        defaults.removePersistentDomain(forName: "lovea.test.kalenderNeu")

        XCTAssertEqual(KalenderNeu.schluessel, "lovea.kalenderNeu")
        XCTAssertTrue(KalenderNeu.an(defaults))
        defaults.set(false, forKey: KalenderNeu.schluessel)
        XCTAssertFalse(KalenderNeu.an(defaults))
        defaults.set(true, forKey: KalenderNeu.schluessel)
        XCTAssertTrue(KalenderNeu.an(defaults))
        defaults.removePersistentDomain(forName: "lovea.test.kalenderNeu")
    }

    // MARK: - Gemeinsam frei

    func testLeererTagIstGanzFrei() {
        XCTAssertEqual(TagesWerte.freieZeiten([]), [TagesFenster(von: 480, bis: 1320)])
    }

    func testArbeitUndTerminLassenZweiFensterFrei() {
        let bloecke = [
            block("Lurse", typ: "arbeit", "08:00", "16:30"),
            block("Zahnarzt", typ: "arzt", "17:30", "19:00", quelle: "termin"),
        ]

        XCTAssertEqual(TagesWerte.freieZeiten(bloecke), [
            TagesFenster(von: 990, bis: 1050),
            TagesFenster(von: 1140, bis: 1320),
        ])
    }

    func testFreiUndUrlaubBlockierenNicht() {
        let bloecke = [
            block(typ: "arbeit", "08:00", "16:30", status: "frei"),
            block(typ: "schule", "08:00", "13:30", status: "urlaub"),
        ]

        XCTAssertEqual(TagesWerte.freieZeiten(bloecke), [TagesFenster(von: 480, bis: 1320)])
    }

    func testBlockOhneZeitBlockiertDasGanzeFenster() {
        XCTAssertEqual(TagesWerte.freieZeiten([block("Ausflug", nil, nil)]), [])
    }

    func testFehltNurDasEndeGiltBisZweiundzwanzigUhr() {
        XCTAssertEqual(TagesWerte.freieZeiten([block("Kino", "20:00", nil)]), [TagesFenster(von: 480, bis: 1200)])
    }

    func testFensterUnterDreissigMinutenFallenWeg() {
        XCTAssertEqual(TagesWerte.freieZeiten([block("Lang", "08:00", "21:45")]), [])
        XCTAssertEqual(TagesWerte.freieZeiten([block("Lang", "08:00", "21:30")]), [TagesFenster(von: 1290, bis: 1320)])
    }

    func testTreffenMitUhrzeitBelegtZweiStundenOhneUhrzeitNichts() {
        let mit = block("Treffen", typ: "treffen", "18:00", nil, quelle: "treffen")
        let ohne = block("Treffen", typ: "treffen", nil, nil, quelle: "treffen")

        XCTAssertEqual(TagesWerte.freieZeiten([mit]), [TagesFenster(von: 480, bis: 1080), TagesFenster(von: 1200, bis: 1320)])
        XCTAssertEqual(TagesWerte.freieZeiten([ohne]), [TagesFenster(von: 480, bis: 1320)])
    }

    func testFreiText() {
        let fenster = [TagesFenster(von: 990, bis: 1050), TagesFenster(von: 1140, bis: 1200)]

        XCTAssertEqual(TagesWerte.freiText(fenster), "Gemeinsam frei 16:30–17:30, 19:00–20:00")
        XCTAssertEqual(TagesWerte.freiText([]), "Keine gemeinsame freie Zeit")
    }

    // MARK: - Punkte je Person

    func testMarkenJeTagUndPerson() {
        let daten = KalenderDaten(
            termine: [
                Termin(id: "1", fuer: ["ahmed"], titel: "A", typ: "sonstiges", datum: "2026-10-08"),
                Termin(id: "2", fuer: ["ahmed", "annika"], titel: "B", typ: "sonstiges", datum: "2026-10-09"),
                Termin(id: "3", fuer: ["annika"], titel: "C", typ: "sonstiges", datum: "2026-11-01"),
            ],
            treffen: [Treffen(datum: "2026-10-10")]
        )

        let marken = TagesWerte.marken(daten, monat: "2026-10-01")

        XCTAssertEqual(marken.count, 3)
        XCTAssertEqual(marken["2026-10-08"], TagesMarken(ahmed: true, annika: false, treffen: false))
        XCTAssertEqual(marken["2026-10-09"], TagesMarken(ahmed: true, annika: true, treffen: false))
        XCTAssertEqual(marken["2026-10-10"], TagesMarken(ahmed: false, annika: false, treffen: true))
        XCTAssertNil(marken["2026-11-01"])
    }

    // MARK: - Ferienzeile

    func testFerienZeileGanzImMonat() {
        XCTAssertEqual(TagesWerte.ferienZeile(monat: "2026-10-01"), "Herbstferien 17. bis 31. Oktober · Schule entfällt")
        XCTAssertEqual(TagesWerte.ferienZeile(monat: "2026-05-01"), "Pfingsten 26. Mai · Schule entfällt")
    }

    func testFerienZeileBisUndAb() {
        XCTAssertEqual(TagesWerte.ferienZeile(monat: "2026-09-01"), "Sommerferien bis 1. September · Schule entfällt")
        XCTAssertEqual(TagesWerte.ferienZeile(monat: "2026-12-01"), "Weihnachtsferien ab 23. Dezember · Schule entfällt")
        XCTAssertEqual(TagesWerte.ferienZeile(monat: "2027-01-01"), "Weihnachtsferien bis 6. Januar · Schule entfällt")
    }

    func testFerienZeileMonatMittendrin() {
        XCTAssertEqual(TagesWerte.ferienZeile(monat: "2026-08-01"), "Sommerferien · Schule entfällt")
    }

    func testFerienZeileOhneFerien() {
        XCTAssertNil(TagesWerte.ferienZeile(monat: "2026-11-01"))
    }

    // MARK: - Dauer und Alltag

    func testDauerText() {
        XCTAssertEqual(TagesWerte.dauerText(480), "8 Std")
        XCTAssertEqual(TagesWerte.dauerText(450), "7 Std 30 min")
        XCTAssertEqual(TagesWerte.dauerText(45), "45 min")
        XCTAssertEqual(TagesWerte.dauerText(0), "0 min")
    }

    func testAlltagZeileArbeitMitNetto() {
        let arbeit = block("Lurse", typ: "arbeit", "08:00", "16:30")

        XCTAssertEqual(TagesWerte.alltagZeile(name: "Ahmed", block: arbeit), "Ahmed · Arbeit 08:00–16:30 · netto 8 Std")
    }

    func testAlltagZeileKrankOhneNetto() {
        let arbeit = block("Lurse", typ: "arbeit", "08:00", "16:30", status: "krank")

        XCTAssertEqual(TagesWerte.alltagZeile(name: "Ahmed", block: arbeit), "Ahmed · Arbeit 08:00–16:30 · krank")
    }

    func testAlltagZeileSchuleUndOhneZeit() {
        let schule = block("Schule", typ: "schule", "08:00", "13:30")
        let ohneZeit = block("Fahrschule", typ: "fahrschule", nil, nil)

        XCTAssertEqual(TagesWerte.alltagZeile(name: "Annika", block: schule), "Annika · Schule 08:00–13:30")
        XCTAssertEqual(TagesWerte.alltagZeile(name: "Ahmed", block: ohneZeit), "Ahmed · Fahrschule")
    }

    // MARK: - Balken

    func testPersonenBalkenGeklemmtOhneTreffenOhneFrei() {
        let bloecke = [
            block("Termin", typ: "arzt", "17:00", "18:00", quelle: "termin"),
            block("Frueh", typ: "arbeit", "06:00", "10:00"),
            block("Treffen", typ: "treffen", "19:00", nil, quelle: "treffen"),
            block("Urlaub", typ: "schule", "08:00", "13:00", status: "urlaub"),
        ]

        XCTAssertEqual(TagesWerte.personenBalken(bloecke), [
            BalkenSegment(von: 480, bis: 600, art: .alltag),
            BalkenSegment(von: 1020, bis: 1080, art: .termin),
        ])
    }

    func testZusammenBalkenFreiUndTreffenEinmal() {
        let treffen = block("Treffen", typ: "treffen", "19:00", nil, quelle: "treffen")
        let bloecke = [
            block("Lurse", typ: "arbeit", "08:00", "16:30"),
            block("Zahnarzt", typ: "arzt", "17:30", "19:00", quelle: "termin"),
            treffen,
            treffen,
        ]

        XCTAssertEqual(TagesWerte.zusammenBalken(bloecke), [
            BalkenSegment(von: 990, bis: 1050, art: .frei),
            BalkenSegment(von: 1140, bis: 1260, art: .treffen),
            BalkenSegment(von: 1260, bis: 1320, art: .frei),
        ])
    }
}
