import XCTest
@testable import Lovea

final class KalenderModellTests: XCTestCase {

    // MARK: - Z-10.1 Treffen: vorherige Fassung bleibt abrufbar (Review-Fokus 2)

    func testTreffenVorherigeFassungBleibtAbrufbar() {
        let opA = Op.neu("treffen.setzen", TreffenSendeD(datum: "2026-10-01", uhrzeit: "18:00", wasMachenWir: "Kino"), von: .ahmed)
        let opB = Op.neu("treffen.setzen", TreffenSendeD(datum: "2026-10-01", uhrzeit: nil, wasMachenWir: "Essen gehen"), von: .annika)

        let zustand = KalenderModell.anwenden([opA, opB])

        XCTAssertEqual(zustand.treffenText["2026-10-01"]?.text, "Essen gehen")
        XCTAssertEqual(zustand.treffenText["2026-10-01"]?.von, .annika)
        XCTAssertEqual(zustand.treffenText["2026-10-01"]?.vorherige?.text, "Kino")
        XCTAssertEqual(zustand.treffenText["2026-10-01"]?.vorherige?.von, .ahmed)
    }

    func testTreffenGleicherTextErzeugtKeineVorherigeFassung() {
        let opA = Op.neu("treffen.setzen", TreffenSendeD(datum: "2026-10-02", uhrzeit: "18:00", wasMachenWir: "Kino"), von: .ahmed)
        let opB = Op.neu("treffen.setzen", TreffenSendeD(datum: "2026-10-02", uhrzeit: "19:00", wasMachenWir: "Kino"), von: .annika)

        let zustand = KalenderModell.anwenden([opA, opB])

        XCTAssertEqual(zustand.treffenText["2026-10-02"]?.uhrzeit, "19:00")
        XCTAssertNil(zustand.treffenText["2026-10-02"]?.vorherige)
    }

    func testTreffenFaltungIstIdempotentBeiDoppelterZustellung() {
        let op = Op.neu("treffen.setzen", TreffenSendeD(datum: "2026-10-03", uhrzeit: nil, wasMachenWir: "Spazieren"), von: .ahmed)

        let zustand = KalenderModell.anwenden([op, op])

        XCTAssertNil(zustand.treffenText["2026-10-03"]?.vorherige)
        XCTAssertEqual(zustand.treffenText["2026-10-03"]?.text, "Spazieren")
    }

    // MARK: - Z-9.4 Startmuster passen zu den bestehenden Wochenplan-Tests

    func testStandardMusterVerhaeltSichWieBestehendeWochenplanTests() {
        let daten = KalenderDaten(muster: KalenderModell.standardMuster(fuer: .annika) + KalenderModell.standardMuster(fuer: .ahmed))

        XCTAssertEqual(Wochenplan.tag("2026-09-22", person: "ahmed", daten: daten).map(\.typ), ["schule"]) // Di, Woche A
        XCTAssertEqual(Wochenplan.tag("2026-09-29", person: "ahmed", daten: daten).map(\.typ), ["arbeit"]) // Di, Woche B
        XCTAssertEqual(Wochenplan.tag("2026-09-21", person: "annika", daten: daten).map(\.typ), ["schule"]) // Mo
    }

    // MARK: - Z-10.3 Frage des Tages: Auswahl rotiert stabil durch den Vorrat

    func testFrageDesTagesRotiertDurchDenVorrat() {
        let vorrat = (0..<5).map { Frage(id: "v\($0)", text: "Frage \($0)", kategorie: "lustig") }

        XCTAssertEqual(FrageDesTages.waehlen(vorrat: vorrat, tag: "2026-01-01")?.id, "v0")
        XCTAssertEqual(FrageDesTages.waehlen(vorrat: vorrat, tag: "2026-01-02")?.id, "v1")
        XCTAssertEqual(FrageDesTages.waehlen(vorrat: vorrat, tag: "2026-01-06")?.id, "v0") // ein voller Umlauf (5 Fragen) später
    }

    func testFrageDesTagesLeererVorratErgibtNil() {
        XCTAssertNil(FrageDesTages.waehlen(vorrat: [], tag: "2026-01-01"))
    }

    // MARK: - Z-10.4 Pünktlich: Monats-Krone

    func testMonatsKroneGehtAnDenPuenktlicherenPartner() {
        let ops = [
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-09-05", ueber: .ahmed, wert: "uhrwerk"), von: .annika),
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-09-10", ueber: .annika, wert: "troedel"), von: .ahmed),
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-09-15", ueber: .ahmed, wert: "charmant"), von: .annika),
        ]

        XCTAssertEqual(Puenktlich.monatsKrone(ops: ops, monat: "2026-09"), .ahmed)
    }

    func testMonatsKroneUnentschiedenErgibtNil() {
        let ops = [
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-09-05", ueber: .ahmed, wert: "charmant"), von: .annika),
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-09-10", ueber: .annika, wert: "charmant"), von: .ahmed),
        ]

        XCTAssertNil(Puenktlich.monatsKrone(ops: ops, monat: "2026-09"))
    }

    func testMonatsKroneIgnoriertAndereMonateUndWeg() {
        let ops = [
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-08-05", ueber: .ahmed, wert: "uhrwerk"), von: .annika), // anderer Monat
            Op.neu("puenktlich.setzen", PuenktlichEintrag(datum: "2026-09-05", ueber: .ahmed, wert: "weg"), von: .annika), // weggewischt
        ]

        XCTAssertNil(Puenktlich.monatsKrone(ops: ops, monat: "2026-09"))
    }
}

private struct TreffenSendeD: Encodable { var datum: String; var uhrzeit: String?; var wasMachenWir: String? }
