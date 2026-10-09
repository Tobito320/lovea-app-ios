import XCTest
@testable import Lovea

/// p37: Termine nur mit „Ab" und „Bis" (je Datum und Uhrzeit). Alte Termine laden und speichern
/// unverändert, „Bis" liegt nie vor „Ab", mehrtägige Termine erscheinen an jedem Tag.
final class TerminAbBisTests: XCTestCase {

    private func termin(_ datum: String, start: String? = nil, ende: String? = nil, bis: String? = nil, fuer: [String] = ["ahmed"]) -> Termin {
        Termin(id: "t", fuer: fuer, titel: "Reise", typ: "sonstiges", datum: datum, start: start, ende: ende, bisDatum: bis)
    }

    /// Editor laden, nichts ändern, speichern.
    private func ladenUndSpeichern(_ alt: Termin) -> Termin {
        TerminZeitraum(datum: alt.datum, termin: alt).angewandt(auf: alt)
    }

    // MARK: - Alte Termine

    func testAlterTerminOhneBisDatumDecodiertUndEncodiertOhneNeuesFeld() throws {
        let json = #"{"id":"t1","fuer":["ahmed"],"titel":"Arzt","typ":"sonstiges","datum":"2026-10-01","start":"09:00","ende":"10:00"}"#
        let termin = try JSONDecoder().decode(Termin.self, from: Data(json.utf8))
        XCTAssertNil(termin.bisDatum)
        XCTAssertEqual(termin.letzterTag, "2026-10-01")
        let neu = String(decoding: try JSONEncoder().encode(termin), as: UTF8.self)
        XCTAssertFalse(neu.contains("bisDatum"))
    }

    func testAlteTermineBleibenBeimLadenUndSpeichernUnveraendert() {
        for alt in [
            termin("2026-10-01", start: "09:00", ende: "10:30"),
            termin("2026-10-01", start: "14:00"),          // Beginn ohne Ende
            termin("2026-10-01"),                          // ganztägig
            termin("2026-10-01", start: "23:30", ende: "23:59"),
        ] {
            XCTAssertEqual(ladenUndSpeichern(alt), alt)
        }
    }

    func testMehrtaegigerTerminBleibtBeimLadenUndSpeichernUnveraendert() {
        let a = termin("2026-10-08", start: "18:00", ende: "11:00", bis: "2026-10-10")
        let b = termin("2026-10-08", bis: "2026-10-12")
        XCTAssertEqual(ladenUndSpeichern(a), a)
        XCTAssertEqual(ladenUndSpeichern(b), b)
    }

    func testTerminMitBisDatumLaeuftDurchDieFaltung() {
        let neu = termin("2026-10-08", start: "18:00", ende: "11:00", bis: "2026-10-10")
        var faltung = SeqFaltung()
        let op = Op.neu("termin.setzen", neu, von: .ahmed)
        let zustand = KalenderModell.einarbeiten([op], faltung: &faltung, zustand: KalenderModell.Zustand())
        XCTAssertEqual(zustand.daten.termine, [neu])
    }

    // MARK: - Bis nie vor Ab

    func testBisKannNichtVorAbRutschen() {
        var z = TerminZeitraum(datum: "2026-10-08", termin: termin("2026-10-08", start: "10:00", ende: "12:00"))
        z.setzeBis(Datum.datum("2026-10-07"))
        XCTAssertEqual(z.bis, z.ab)
        let t = z.angewandt(auf: termin("2026-10-08"))
        XCTAssertEqual(t.datum, "2026-10-08")
        XCTAssertNil(t.bisDatum)
        XCTAssertEqual(t.start, "10:00")
        XCTAssertEqual(t.ende, "10:00")
    }

    func testAbSpaeterSchiebtBisMitUndHaeltDieLaenge() {
        var z = TerminZeitraum(datum: "2026-10-08", termin: termin("2026-10-08", start: "10:00", ende: "12:00"))
        z.setzeAb(Datum.datum("2026-10-09").addingTimeInterval(14 * 3600))
        let t = z.angewandt(auf: termin("2026-10-08"))
        XCTAssertEqual(t.datum, "2026-10-09")
        XCTAssertEqual(t.start, "14:00")
        XCTAssertEqual(t.ende, "16:00")
        XCTAssertNil(t.bisDatum)
    }

    func testBisAmNaechstenTagMachtDenTerminMehrtaegig() {
        var z = TerminZeitraum(datum: "2026-10-08", termin: termin("2026-10-08", start: "18:00", ende: "20:00"))
        z.setzeBis(Datum.datum("2026-10-09").addingTimeInterval(11 * 3600))
        let t = z.angewandt(auf: termin("2026-10-08"))
        XCTAssertEqual(t.bisDatum, "2026-10-09")
        XCTAssertEqual(t.start, "18:00")
        XCTAssertEqual(t.ende, "11:00")
    }

    func testGanztaegigNurMitDatum() {
        var z = TerminZeitraum(datum: "2026-10-08", termin: nil)
        XCTAssertTrue(z.ganztaegig)
        z.setzeBis(Datum.datum("2026-10-10").addingTimeInterval(15 * 3600)) // Uhrzeit zählt nicht
        let t = z.angewandt(auf: termin("2026-10-08"))
        XCTAssertNil(t.start)
        XCTAssertNil(t.ende)
        XCTAssertEqual(t.bisDatum, "2026-10-10")
    }

    func testGanztaegigAusSchaltetStandardzeitenEin() {
        var z = TerminZeitraum(datum: "2026-10-08", termin: nil)
        z.setzeGanztaegig(false)
        let t = z.angewandt(auf: termin("2026-10-08"))
        XCTAssertEqual(t.start, "10:00")
        XCTAssertEqual(t.ende, "11:00")
        XCTAssertNil(t.bisDatum)
    }

    // MARK: - Anzeige mehrtägiger Termine

    func testMehrtaegigerTerminStehtInWochenplanAnJedemTag() {
        var daten = KalenderDaten()
        daten.termine = [termin("2026-10-08", start: "18:00", ende: "11:00", bis: "2026-10-10")]
        func block(_ tag: String) -> Block? { Wochenplan.tag(tag, person: "ahmed", daten: daten).first }

        XCTAssertNil(block("2026-10-07"))
        XCTAssertEqual(block("2026-10-08")?.start, "18:00")
        XCTAssertNil(block("2026-10-08")?.ende)
        XCTAssertNil(block("2026-10-09")?.start)
        XCTAssertNil(block("2026-10-09")?.ende)
        XCTAssertNil(block("2026-10-10")?.start)
        XCTAssertEqual(block("2026-10-10")?.ende, "11:00")
        XCTAssertNil(block("2026-10-11"))
        XCTAssertTrue(Wochenplan.tag("2026-10-09", person: "annika", daten: daten).isEmpty)
    }

    func testMehrtaegigerTerminMarkiertImMonatsrasterJedenTag() {
        var daten = KalenderDaten()
        daten.termine = [termin("2026-09-30", bis: "2026-10-02")]
        let september = MonatsRaster(erster: "2026-09-01", daten: daten).zellen.compactMap { $0 }
        let oktober = MonatsRaster(erster: "2026-10-01", daten: daten).zellen.compactMap { $0 }
        XCTAssertEqual(september.filter(\.termin).map(\.tag), ["2026-09-30"])
        XCTAssertEqual(oktober.filter(\.termin).map(\.tag), ["2026-10-01", "2026-10-02"])
    }

    func testMarkenUndTagesListeKennenMehrtaegigeTermine() {
        var daten = KalenderDaten()
        daten.termine = [termin("2026-10-08", bis: "2026-10-10", fuer: ["ahmed", "annika"])]
        let marken = TagesWerte.marken(daten, monat: "2026-10")
        XCTAssertEqual(marken.keys.sorted(), ["2026-10-08", "2026-10-09", "2026-10-10"])
        XCTAssertEqual(marken["2026-10-09"]?.ahmed, true)
        XCTAssertEqual(marken["2026-10-09"]?.annika, true)
        XCTAssertEqual(AnsichtWerte.tagesTermine(daten, tag: "2026-10-09").count, 1)
        XCTAssertTrue(AnsichtWerte.tagesTermine(daten, tag: "2026-10-11").isEmpty)
    }

    func testZeitSpalteMehrtaegig() {
        let t = termin("2026-10-08", start: "18:00", ende: "11:00", bis: "2026-10-10")
        XCTAssertEqual(AnsichtWerte.zeitSpalte(t, tag: "2026-10-08"), "18:00")
        XCTAssertEqual(AnsichtWerte.zeitSpalte(t, tag: "2026-10-09"), "ganztägig")
        XCTAssertEqual(AnsichtWerte.zeitSpalte(t, tag: "2026-10-10"), "bis 11:00")
        XCTAssertEqual(AnsichtWerte.zeitSpalte(termin("2026-10-08", start: "09:00"), tag: "2026-10-08"), "09:00")
        XCTAssertTrue(AnsichtWerte.terminUnterzeile(t).hasSuffix("11:00"))
    }
}
