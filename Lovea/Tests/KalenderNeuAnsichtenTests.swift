import XCTest
@testable import Lovea

/// Neuer Kalender (Variante C), Teil 2: die reinen Hilfen hinter den Ansichten.
/// 2026-10-08 ist ein Donnerstag, Montag der Woche ist 2026-10-05.
final class KalenderNeuAnsichtenTests: XCTestCase {

    private func termin(_ id: String, fuer: [String] = ["ahmed"], _ start: String?, _ ende: String? = nil, datum: String = "2026-10-08") -> Termin {
        Termin(id: id, fuer: fuer, titel: "T\(id)", typ: "sonstiges", datum: datum, start: start, ende: ende)
    }

    func testWochenTageSindMontagBisSonntag() {
        let tage = AnsichtWerte.wochenTage("2026-10-08")

        XCTAssertEqual(tage.first, "2026-10-05")
        XCTAssertEqual(tage.last, "2026-10-11")
        XCTAssertEqual(tage.count, 7)
        XCTAssertTrue(tage.contains("2026-10-08"))
    }

    func testWochentagKurz() {
        XCTAssertEqual(AnsichtWerte.kurz("2026-10-05"), "Mo")
        XCTAssertEqual(AnsichtWerte.kurz("2026-10-08"), "Do")
        XCTAssertEqual(AnsichtWerte.kurz("2026-10-11"), "So")
    }

    func testTermineEinesTagesNachUhrzeitGanztagsZuerst() {
        let daten = KalenderDaten(termine: [
            termin("b", "17:30"),
            termin("a", "09:00"),
            termin("g", nil),
            termin("x", "08:00", datum: "2026-10-09"),
        ])

        XCTAssertEqual(AnsichtWerte.tagesTermine(daten, tag: "2026-10-08").map(\.id), ["g", "a", "b"])
    }

    func testTerminUnterzeile() {
        XCTAssertEqual(AnsichtWerte.terminUnterzeile(termin("1", "17:30", "19:00")), "Ahmed · bis 19:00")
        XCTAssertEqual(AnsichtWerte.terminUnterzeile(termin("2", fuer: ["annika", "ahmed"], "10:00")), "Ahmed und Annika")
        XCTAssertEqual(AnsichtWerte.terminUnterzeile(termin("3", fuer: [], "10:00", "11:00")), "bis 11:00")
    }

    func testZeitSpalte() {
        XCTAssertEqual(AnsichtWerte.zeitSpalte(termin("1", "17:30")), "17:30")
        XCTAssertEqual(AnsichtWerte.zeitSpalte(termin("2", nil)), "ganztägig")
    }

    func testZellenTextFuerVoiceOver() {
        let marken = TagesMarken(ahmed: true, annika: true, treffen: true)

        XCTAssertEqual(
            AnsichtWerte.zellenText(anzeige: "Donnerstag, 8. Oktober", marken: marken, heute: false, gewaehlt: true),
            "Donnerstag, 8. Oktober, gewählt, Termin Ahmed, Termin Annika, Treffen"
        )
        XCTAssertEqual(
            AnsichtWerte.zellenText(anzeige: "Freitag, 2. Oktober", marken: nil, heute: true, gewaehlt: false),
            "Heute, Freitag, 2. Oktober"
        )
    }

    func testAlltagListetMusterBloeckeBeiderPersonen() {
        // 2026-10-08 ist ein Donnerstag (4), Wechselwoche egal: Muster "alle".
        let daten = KalenderDaten(muster: [
            Muster(id: "m1", person: "ahmed", typ: "arbeit", titel: "Lurse", wochentage: [4], wochen: "alle", start: "08:00", ende: "16:30", ab: "2026-09-01"),
            Muster(id: "m2", person: "annika", typ: "schule", titel: "Schule", wochentage: [4], wochen: "alle", start: "08:00", ende: "15:00", ab: "2026-09-01"),
        ])

        let alltag = AnsichtWerte.alltag(daten, tag: "2026-10-08")

        XCTAssertEqual(alltag.map { $0.person }, [.ahmed, .annika])
        XCTAssertEqual(alltag.map { $0.block.typ }, ["arbeit", "schule"])
        XCTAssertEqual(AnsichtWerte.alltagSymbol(alltag[0].block), "briefcase")
        XCTAssertEqual(AnsichtWerte.alltagSymbol(alltag[1].block), "book")
    }

    func testTerminPersonNurBeiGenauEinerPerson() {
        XCTAssertEqual(AnsichtWerte.terminPerson(termin("1", "10:00")), .ahmed)
        XCTAssertEqual(AnsichtWerte.terminPerson(termin("2", fuer: ["annika"], "10:00")), .annika)
        XCTAssertNil(AnsichtWerte.terminPerson(termin("3", fuer: ["ahmed", "annika"], "10:00")))
        XCTAssertNil(AnsichtWerte.terminPerson(termin("4", fuer: [], "10:00")))
    }

    func testWochenZeilenLassenLeereWocheWeg() {
        // Oktober 2026: 3 leere Plätze vor dem 1., 31 Tage, Rest leer = 5 Wochen.
        let davor: [Int?] = Array(repeating: nil, count: 3)
        let tage: [Int?] = (1...31).map { $0 }
        let danach: [Int?] = Array(repeating: nil, count: 8)
        let plaetze = davor + tage + danach

        let zeilen = AnsichtWerte.wochenZeilen(plaetze)

        XCTAssertEqual(plaetze.count, 42)
        XCTAssertEqual(zeilen.count, 5)
        XCTAssertTrue(zeilen.allSatisfy { $0.count == 7 })
    }

    func testTagNachMonatswechsel() {
        XCTAssertEqual(AnsichtWerte.tagNachMonatswechsel(erster: "2026-10-01", heute: "2026-10-02"), "2026-10-02")
        XCTAssertEqual(AnsichtWerte.tagNachMonatswechsel(erster: "2026-11-01", heute: "2026-10-02"), "2026-11-01")
    }

    func testAnteilKlemmtAufDasFenster() {
        XCTAssertEqual(AnsichtWerte.anteil(480), 0)
        XCTAssertEqual(AnsichtWerte.anteil(900), 0.5)
        XCTAssertEqual(AnsichtWerte.anteil(1320), 1)
        XCTAssertEqual(AnsichtWerte.anteil(60), 0)
        XCTAssertEqual(AnsichtWerte.anteil(1400), 1)
    }
}
