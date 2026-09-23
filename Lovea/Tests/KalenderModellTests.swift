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

    // MARK: - I-1 Live-Reihenfolge: die höhere `seq` gewinnt auf beiden Handys

    private func treffen(_ id: String, _ text: String, von: Person, seq: Int?) -> Op {
        let neu = Op.neu("treffen.setzen", TreffenSendeD(datum: "2026-10-10", uhrzeit: nil, wasMachenWir: text), von: von)
        return Op(id: id, seq: seq, art: neu.art, von: von, zeit: neu.zeit, d: neu.d)
    }

    /// Genau der Weg des Modells: jede Lieferung von `Raum` geht durch `einarbeiten`.
    private func live(_ lieferungen: [[Op]]) -> KalenderModell.Zustand {
        var faltung = SeqFaltung()
        var zustand = KalenderModell.Zustand()
        for batch in lieferungen { zustand = KalenderModell.einarbeiten(batch, faltung: &faltung, zustand: zustand) }
        return zustand
    }

    func testGleichzeitigeTreffenAenderungKonvergiertZurHoeherenSeq() {
        // Ahmed offline: A lokal (ohne seq), dann B von Annika (seq 10), dann das Echo von A (seq 11).
        let ahmed = live([
            [treffen("a", "Kino", von: .ahmed, seq: nil)],
            [treffen("b", "Essen", von: .annika, seq: 10)],
            [treffen("a", "Kino", von: .ahmed, seq: 11)],
        ])
        // Annika: B lokal, dann ihr Echo, dann A.
        let annika = live([
            [treffen("b", "Essen", von: .annika, seq: nil)],
            [treffen("b", "Essen", von: .annika, seq: 10)],
            [treffen("a", "Kino", von: .ahmed, seq: 11)],
        ])
        for zustand in [ahmed, annika] {
            XCTAssertEqual(zustand.treffenText["2026-10-10"]?.text, "Kino")
            XCTAssertEqual(zustand.treffenText["2026-10-10"]?.vorherige?.text, "Essen")
        }
    }

    func testAeltereSeqNachNeuererAendertNichts() {
        let zustand = live([
            [treffen("a", "Kino", von: .ahmed, seq: 11)],
            [treffen("b", "Essen", von: .annika, seq: 10)],
        ])
        XCTAssertEqual(zustand.treffenText["2026-10-10"]?.text, "Kino")
        XCTAssertEqual(zustand.treffenText["2026-10-10"]?.vorherige?.text, "Essen")
    }

    func testWirListeKonvergiertInBeidenReihenfolgen() {
        func liste(_ id: String, _ text: String, von: Person, seq: Int?) -> Op {
            let neu = Op.neu("liste.setzen", ListeSendeD(id: "eintrag", text: text, geschafft: false), von: von)
            return Op(id: id, seq: seq, art: neu.art, von: von, zeit: neu.zeit, d: neu.d)
        }
        func wir(_ lieferungen: [[Op]]) -> WirModell.Zustand {
            var faltung = SeqFaltung()
            var zustand = WirModell.Zustand()
            for batch in lieferungen { zustand = WirModell.einarbeiten(batch, faltung: &faltung, zustand: zustand) }
            return zustand
        }
        let erst10 = wir([[liste("b", "Picknick", von: .annika, seq: 10)], [liste("a", "Zoo", von: .ahmed, seq: 11)]])
        let erst11 = wir([[liste("a", "Zoo", von: .ahmed, seq: 11)], [liste("b", "Picknick", von: .annika, seq: 10)]])
        let offline = wir([
            [liste("a", "Zoo", von: .ahmed, seq: nil)],
            [liste("b", "Picknick", von: .annika, seq: 10)],
            [liste("a", "Zoo", von: .ahmed, seq: 11)],
        ])
        for zustand in [erst10, erst11, offline] {
            XCTAssertEqual(zustand.liste.map(\.text), ["Zoo"])
        }
    }

    // MARK: - I-2 Startmuster nur einmal

    func testStartmusterNurEinmalUndNieUeberEigeneMuster() {
        let geloescht = Op.neu("muster.loeschen", MitIdD(id: "start-ahmed-schule-a"), von: .ahmed)
        let partnerMuster = Op.neu("muster.setzen", KalenderModell.standardMuster(fuer: .annika)[0], von: .annika)

        XCTAssertTrue(KalenderModell.startmusterNoetig(ich: .ahmed, ops: [], muster: [], schonGesendet: false))
        XCTAssertFalse(KalenderModell.startmusterNoetig(ich: .ahmed, ops: [], muster: [], schonGesendet: true))
        // Alle eigenen Muster gelöscht: das ist eine Entscheidung, kein leerer Kalender.
        XCTAssertFalse(KalenderModell.startmusterNoetig(ich: .ahmed, ops: [geloescht], muster: [], schonGesendet: false))
        XCTAssertTrue(KalenderModell.startmusterNoetig(
            ich: .ahmed, ops: [partnerMuster], muster: KalenderModell.standardMuster(fuer: .annika), schonGesendet: false
        ))
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
private struct ListeSendeD: Encodable { var id: String; var text: String; var geschafft: Bool }
private struct MitIdD: Encodable { var id: String }
