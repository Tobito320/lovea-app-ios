import XCTest
@testable import Lovea

/// Review-Fokus 5 (Runde 3): Termin bearbeiten ersetzt den alten, `ausnahme.loeschen` nimmt die
/// Ausnahme zurück, die Treffen-Notiz landet auch ohne Enter im Log.
final class KalenderSpeichernTests: XCTestCase {

    private func op<T: Encodable>(_ art: String, _ d: T, von: Person = .ahmed, seq: Int? = nil, id: String = UUID().uuidString) -> Op {
        let neu = Op.neu(art, d, von: von)
        return Op(id: id, seq: seq, art: art, von: von, zeit: neu.zeit, d: neu.d)
    }

    /// Genau der Weg des Modells: jede Lieferung von `Raum` geht durch `einarbeiten`.
    private func live(_ lieferungen: [[Op]]) -> KalenderModell.Zustand {
        var faltung = SeqFaltung()
        var zustand = KalenderModell.Zustand()
        for batch in lieferungen { zustand = KalenderModell.einarbeiten(batch, faltung: &faltung, zustand: zustand) }
        return zustand
    }

    private func ausnahme(_ person: String, _ datum: String, muster: String? = nil, status: String = "krank") -> Ausnahme {
        Ausnahme(person: person, datum: datum, musterId: muster, status: status, bisDatum: nil, start: nil, ende: nil)
    }

    // MARK: - Termine

    func testTerminBearbeitenErsetztDenAltenOhneDoppel() {
        let alt = Termin(id: "t1", fuer: ["ahmed"], titel: "Arzt", typ: "sonstiges", datum: "2026-10-01", start: "09:00", ende: "10:00")
        var neu = alt
        neu.titel = "Zahnarzt"
        neu.datum = "2026-10-02"
        neu.fuer = ["ahmed", "annika"]

        // Erst optimistisch ohne seq, dann die Echos mit seq.
        let zustand = live([
            [op("termin.setzen", alt, id: "a")],
            [op("termin.setzen", neu, id: "b")],
            [op("termin.setzen", alt, seq: 10, id: "a")],
            [op("termin.setzen", neu, seq: 11, id: "b")],
        ])

        XCTAssertEqual(zustand.daten.termine, [neu])
    }

    func testTerminLoeschenEntferntNurDiesenTermin() {
        let arzt = Termin(id: "t1", fuer: ["ahmed"], titel: "Arzt", typ: "sonstiges", datum: "2026-10-01", start: nil, ende: nil)
        let fahrstunde = Termin(id: "t2", fuer: ["ahmed"], titel: "Fahrstunde", typ: "fahrschule", datum: "2026-10-01", start: "16:00", ende: "17:30")

        let zustand = KalenderModell.anwenden([
            op("termin.setzen", arzt), op("termin.setzen", fahrstunde), op("termin.loeschen", ["id": "t1"]),
        ])

        XCTAssertEqual(zustand.daten.termine, [fahrstunde])
    }

    // MARK: - Ausnahmen

    func testAusnahmeLoeschenEntferntNurDenPassendenSchluessel() {
        let weg = ausnahme("ahmed", "2026-10-01")
        let bleiben = [
            ausnahme("ahmed", "2026-10-01", muster: "m1"), // gleicher Tag, anderes Muster
            ausnahme("annika", "2026-10-01"), // gleicher Tag, andere Person
            ausnahme("ahmed", "2026-10-02"), // gleiche Person, anderer Tag
        ]

        let ops = ([weg] + bleiben).map { op("ausnahme.setzen", $0) } + [op("ausnahme.loeschen", AusnahmeSchluessel(weg))]

        XCTAssertEqual(KalenderModell.anwenden(ops).daten.ausnahmen, bleiben)
    }

    func testAusnahmeLoeschenOhneMusterIdImJsonTrifftDieTagesausnahme() {
        let tag = ausnahme("ahmed", "2026-10-01")
        let block = ausnahme("ahmed", "2026-10-01", muster: "m1")

        let zustand = KalenderModell.anwenden([
            op("ausnahme.setzen", tag), op("ausnahme.setzen", block),
            op("ausnahme.loeschen", ["person": "ahmed", "datum": "2026-10-01"]), // so, wie es übers Netz kommt
        ])

        XCTAssertEqual(zustand.daten.ausnahmen, [block])
    }

    func testAusnahmeAendernErsetztDieAlte() {
        let krank = ausnahme("ahmed", "2026-10-01")
        let urlaub = ausnahme("ahmed", "2026-10-01", status: "urlaub")

        let zustand = KalenderModell.anwenden([op("ausnahme.setzen", krank), op("ausnahme.setzen", urlaub)])

        XCTAssertEqual(zustand.daten.ausnahmen, [urlaub])
    }

    func testZuruecknehmenGewinntGegenSpaeterAnkommendeAeltereAusnahme() {
        let krank = ausnahme("ahmed", "2026-10-01")

        let zustand = live([
            [op("ausnahme.loeschen", AusnahmeSchluessel(krank), seq: 12)],
            [op("ausnahme.setzen", krank, seq: 11)],
        ])

        XCTAssertTrue(zustand.daten.ausnahmen.isEmpty)
    }

    // MARK: - Notizen

    func testNotizLetzteGewinnt() {
        let kurz = ["datum": "2026-10-03", "text": "Kuchen"]
        let lang = ["datum": "2026-10-03", "text": "Kuchen und Blumen"]

        // Autosave: zwei Fassungen hintereinander, erst optimistisch, dann bestätigt.
        let zustand = live([
            [op("notiz.setzen", kurz, id: "n1")],
            [op("notiz.setzen", lang, id: "n2")],
            [op("notiz.setzen", kurz, seq: 20, id: "n1")],
            [op("notiz.setzen", lang, seq: 21, id: "n2")],
        ])
        XCTAssertEqual(zustand.notizen["2026-10-03"]?[.ahmed], "Kuchen und Blumen")

        // Kommt die ältere Fassung zuletzt an, gewinnt trotzdem die höhere seq.
        let spaet = live([[op("notiz.setzen", lang, seq: 21)], [op("notiz.setzen", kurz, seq: 20)]])
        XCTAssertEqual(spaet.notizen["2026-10-03"]?[.ahmed], "Kuchen und Blumen")
    }

    // MARK: - Treffen-Tag speichert ohne Enter

    func testNotizLandetOhneEnterImLog() throws {
        let basis = TreffenEntwurf(text: "Kino", uhrzeit: "18:00", notiz: "")
        var jetzt = basis
        jetzt.notiz = "Popcorn mitbringen"

        XCTAssertNil(jetzt.treffen("2026-10-04", seit: basis)) // Text und Uhrzeit unverändert
        let notiz = try XCTUnwrap(jetzt.neueNotiz(seit: basis))
        let zustand = KalenderModell.anwenden([op("notiz.setzen", ["datum": "2026-10-04", "text": notiz])])

        XCTAssertEqual(zustand.notizen["2026-10-04"]?[.ahmed], "Popcorn mitbringen")
    }

    func testUnveraenderterTreffenTagSendetNichts() {
        // Sonst würde Verlassen die Änderung des Partners mit altem Text überschreiben.
        let stand = TreffenEntwurf(text: "Kino", uhrzeit: nil, notiz: "Tickets holen")

        XCTAssertNil(stand.treffen("2026-10-04", seit: stand))
        XCTAssertNil(stand.neueNotiz(seit: stand))
    }

    func testLeererTextLegtKeinTreffenAn() {
        XCTAssertNil(TreffenEntwurf(text: "", uhrzeit: "18:00").treffen("2026-10-04", seit: TreffenEntwurf()))
    }

    func testUhrzeitZuruecknehmenSendetLeerUndDieFaltungLoeschtSie() throws {
        let ohne = try XCTUnwrap(TreffenEntwurf(text: "Kino").treffen("2026-10-05", seit: TreffenEntwurf(text: "Kino", uhrzeit: "18:00")))
        XCTAssertEqual(ohne.uhrzeit, "")

        let zustand = KalenderModell.anwenden([
            op("treffen.setzen", TreffenD(datum: "2026-10-05", uhrzeit: "18:00", wasMachenWir: "Kino")),
            op("treffen.setzen", ohne),
        ])

        XCTAssertNil(zustand.treffenText["2026-10-05"]?.uhrzeit)
        XCTAssertEqual(zustand.daten.treffen.count, 1)
        XCTAssertNil(zustand.daten.treffen.first?.uhrzeit)
    }

    func testOhneUhrzeitVorherBleibtUhrzeitNil() throws {
        let neu = try XCTUnwrap(TreffenEntwurf(text: "Kino").treffen("2026-10-05", seit: TreffenEntwurf(text: "Kin")))

        XCTAssertNil(neu.uhrzeit) // kein "", ältere Builds sehen so nichts Neues
    }

    func testMachenWirOhneUhrzeitBehaeltDieAlte() {
        let zustand = KalenderModell.anwenden([
            op("treffen.setzen", TreffenD(datum: "2026-10-06", uhrzeit: "18:00", wasMachenWir: "Kino")),
            op("treffen.setzen", TreffenD(datum: "2026-10-06", uhrzeit: nil, wasMachenWir: "Picknick"), von: .annika),
        ])

        XCTAssertEqual(zustand.treffenText["2026-10-06"]?.uhrzeit, "18:00")
    }

    func testAutosaveVerdraengtNichtDieFassungDesPartners() {
        let zustand = KalenderModell.anwenden([
            op("treffen.setzen", TreffenD(datum: "2026-10-07", uhrzeit: nil, wasMachenWir: "Kino"), von: .annika),
            op("treffen.setzen", TreffenD(datum: "2026-10-07", uhrzeit: nil, wasMachenWir: "Ess"), von: .ahmed),
            op("treffen.setzen", TreffenD(datum: "2026-10-07", uhrzeit: nil, wasMachenWir: "Essen gehen"), von: .ahmed),
        ])

        XCTAssertEqual(zustand.treffenText["2026-10-07"]?.text, "Essen gehen")
        XCTAssertEqual(zustand.treffenText["2026-10-07"]?.vorherige?.text, "Kino")
        XCTAssertEqual(zustand.treffenText["2026-10-07"]?.vorherige?.von, .annika)
    }

    func testTreffenAbsagenNimmtDasHerzRaus() {
        let zustand = KalenderModell.anwenden([
            op("treffen.setzen", TreffenD(datum: "2026-10-08", uhrzeit: "19:00", wasMachenWir: "Kochen")),
            op("treffen.loeschen", ["datum": "2026-10-08"]),
        ])

        XCTAssertTrue(zustand.daten.treffen.isEmpty)
        XCTAssertNil(zustand.treffenText["2026-10-08"])
    }
}
