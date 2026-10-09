import XCTest
@testable import Lovea

/// Treffen mit Ablauf, Teil 2: Texte und Entscheidungen der Lese- und Bearbeiten-Ansicht.
final class TreffenAnsichtTests: XCTestCase {
    private func berlin(_ j: Int, _ m: Int, _ t: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = j; c.month = m; c.day = t; c.hour = h; c.minute = min
        return Datum.kalender.date(from: c)!
    }

    private func punkt(_ id: String, titel: String? = "Essen", von: Person = .ahmed, versteckt: Bool = false, ab: Date? = nil) -> TreffenPunkt {
        TreffenPunkt(id: id, datum: "2026-10-03", von: von, start: "19:30", ende: "22:00", titel: titel, notiz: "Tisch", ort: nil, versteckt: versteckt, sichtbarAb: ab)
    }

    // MARK: - Texte

    func testDauerText() {
        XCTAssertEqual(TreffenAnsichtWerte.dauerText(von: "12:00", bis: "22:00"), "10 Std.")
        XCTAssertEqual(TreffenAnsichtWerte.dauerText(von: "12:00", bis: "14:30"), "2 Std. 30 Min.")
        XCTAssertEqual(TreffenAnsichtWerte.dauerText(von: "12:00", bis: "12:45"), "45 Min.")
        XCTAssertNil(TreffenAnsichtWerte.dauerText(von: "12:00", bis: nil))
        XCTAssertNil(TreffenAnsichtWerte.dauerText(von: nil, bis: "22:00"))
        XCTAssertNil(TreffenAnsichtWerte.dauerText(von: "22:00", bis: "12:00"))
    }

    func testZeitKopfUndSpalte() {
        XCTAssertEqual(TreffenAnsichtWerte.zeitKopf(von: "12:00", bis: "22:00"), "12:00 bis 22:00")
        XCTAssertEqual(TreffenAnsichtWerte.zeitKopf(von: "12:00", bis: nil), "ab 12:00")
        XCTAssertEqual(TreffenAnsichtWerte.zeitKopf(von: nil, bis: "22:00"), "bis 22:00")
        XCTAssertNil(TreffenAnsichtWerte.zeitKopf(von: nil, bis: nil))
        let z = TreffenAnsichtWerte.zeitSpalte(start: "12:00", ende: "14:00")
        XCTAssertEqual(z.oben, "12:00")
        XCTAssertEqual(z.unten, "bis 14:00")
        XCTAssertEqual(TreffenAnsichtWerte.zeitSpalte(start: nil, ende: nil).oben, "–")
        XCTAssertNil(TreffenAnsichtWerte.zeitSpalte(start: "12:00", ende: nil).unten)
    }

    func testKurzDatum() {
        XCTAssertEqual(TreffenAnsichtWerte.kurzDatum("2026-10-03"), "Sa 3. Okt.")
        XCTAssertEqual(TreffenAnsichtWerte.kurzDatum("2026-03-01"), "So 1. März")
    }

    func testVerstecktUndErstellerText() {
        let jetzt = berlin(2026, 10, 2, 10)
        let ab = berlin(2026, 10, 3, 9)
        XCTAssertEqual(TreffenAnsichtWerte.verstecktText(ab: ab, gleich: false, jetzt: jetzt), "Überraschung, sichtbar ab morgen 09:00")
        XCTAssertEqual(TreffenAnsichtWerte.verstecktText(ab: ab, gleich: false, jetzt: berlin(2026, 9, 20)), "Überraschung, sichtbar ab Sa. 3. Okt., 09:00")
        XCTAssertEqual(TreffenAnsichtWerte.verstecktText(ab: ab, gleich: true, jetzt: ab), "Überraschung, gleich sichtbar")
        XCTAssertEqual(TreffenAnsichtWerte.erstellerHinweis(fuer: .annika, ab: ab, jetzt: jetzt), "Für Annika versteckt bis morgen 09:00")
        XCTAssertEqual(TreffenAnsichtWerte.erstellerHinweis(fuer: .annika, ab: ab, jetzt: ab), "Für Annika gleich sichtbar")
    }

    /// Der versteckte Block darf nichts vom Inhalt enthalten, auch nicht im Vorlesetext.
    func testVerstecktTextEnthaeltKeinenInhalt() {
        let p = punkt("a", titel: nil, von: .annika, versteckt: true, ab: berlin(2026, 10, 3, 9))
        guard case .versteckt(let ab, let gleich) = TreffenLogik.ansicht(p, ich: .ahmed, jetzt: berlin(2026, 10, 2)) else { return XCTFail("müsste versteckt sein") }
        let text = TreffenAnsichtWerte.verstecktText(ab: ab, gleich: gleich, jetzt: berlin(2026, 10, 2))
        XCTAssertFalse(text.contains("Essen"))
        XCTAssertFalse(text.contains("Tisch"))
    }

    func testSichtbarZeile() {
        let wahl = FreigabeAuswahl.amTag.wahl(stunden: 3)
        XCTAssertEqual(TreffenAnsichtWerte.sichtbarZeile(wahl, datum: "2026-10-03", start: "19:30", fuer: .annika, jetzt: berlin(2026, 10, 2, 10)), "Annika sieht ihn ab morgen 08:00")
        XCTAssertEqual(TreffenAnsichtWerte.sichtbarZeile(wahl, datum: "2026-10-03", start: "19:30", fuer: .annika, jetzt: berlin(2026, 10, 3, 10)), "Annika sieht ihn sofort")
    }

    func testExportEnde() {
        let start = berlin(2026, 10, 3, 12)
        XCTAssertEqual(TreffenAnsichtWerte.exportEnde(start: start, bis: berlin(2026, 10, 3, 22)), berlin(2026, 10, 3, 22))
        XCTAssertEqual(TreffenAnsichtWerte.exportEnde(start: start, bis: nil), berlin(2026, 10, 3, 14))
        XCTAssertEqual(TreffenAnsichtWerte.exportEnde(start: start, bis: berlin(2026, 10, 3, 11)), berlin(2026, 10, 3, 14))
    }

    // MARK: - Freigabe-Wahl

    func testFreigabeAuswahlHinUndZurueck() {
        for a in FreigabeAuswahl.allCases {
            XCTAssertEqual(FreigabeAuswahl.von(a.wahl(stunden: 3)), a)
        }
        XCTAssertEqual(FreigabeAuswahl.dreiTage.wahl(stunden: 3), FreigabeWahl(art: .tage, n: 3))
        XCTAssertEqual(FreigabeAuswahl.einTag.wahl(stunden: 3), FreigabeWahl(art: .tage, n: 1))
        XCTAssertEqual(FreigabeAuswahl.stunden.wahl(stunden: 6), FreigabeWahl(art: .stunden, n: 6))
        XCTAssertEqual(FreigabeAuswahl.von(FreigabeWahl(art: .stunden, n: 6)), .stunden)
    }

    // MARK: - Bearbeiten

    func testPunktBearbeitungAusOeffentlichemPunkt() {
        let p = punkt("a")
        let b = PunktBearbeitung(p, ansicht: TreffenLogik.ansicht(p, ich: .ahmed, jetzt: Date()), geheim: nil)
        XCTAssertTrue(b.schonSichtbar)
        XCTAssertNil(b.ueberraschung)
        XCTAssertFalse(b.gesperrt)
        XCTAssertEqual(b.titel, "Essen")
    }

    func testPunktBearbeitungAusEigenemVerstecktenPunkt() {
        let ab = berlin(2026, 10, 3, 9)
        let p = punkt("a", versteckt: true, ab: ab)
        let wahl = FreigabeWahl(art: .stunden, n: 6)
        let g = GeheimPunkt(id: "a", datum: "2026-10-03", start: "19:30", ende: "22:00", titel: "Essen", notiz: nil, ort: nil, sichtbarAb: ab, freigabe: wahl, geloescht: false, zeit: Date())
        let b = PunktBearbeitung(p, ansicht: TreffenLogik.ansicht(p, ich: .ahmed, jetzt: berlin(2026, 10, 2)), geheim: g)
        XCTAssertFalse(b.schonSichtbar)
        XCTAssertEqual(b.ueberraschung, wahl)
        XCTAssertFalse(b.gesperrt)
    }

    func testPunktBearbeitungDesPartnersIstGesperrt() {
        let p = punkt("a", titel: nil, von: .annika, versteckt: true, ab: berlin(2026, 10, 3, 9))
        let b = PunktBearbeitung(p, ansicht: TreffenLogik.ansicht(p, ich: .ahmed, jetzt: berlin(2026, 10, 2)), geheim: nil)
        XCTAssertTrue(b.gesperrt)
        XCTAssertEqual(b.titel, "")
    }

    func testEntwurfSchonSichtbarSendetKeineUeberraschung() {
        var b = PunktBearbeitung(neuAm: "19:30")
        b.titel = "  Essen "
        b.notiz = "Tisch\n"
        b.ueberraschung = FreigabeAuswahl.einTag.wahl(stunden: 3)
        let e = b.entwurf(datum: "2026-10-03")
        XCTAssertEqual(e.titel, "Essen")
        XCTAssertEqual(e.notiz, "Tisch")
        XCTAssertEqual(e.ueberraschung, FreigabeWahl(art: .tage, n: 1))
        XCTAssertEqual(e.id, b.id)
        b.schonSichtbar = true
        XCTAssertNil(b.entwurf(datum: "2026-10-03").ueberraschung)
    }

    func testTreffenOp() {
        let basis = TreffenBearbeitung(titel: "Düsseldorf", von: "12:00", bis: nil)
        XCTAssertNil(basis.op(datum: "2026-10-03", seit: basis))

        var leer = basis
        leer.titel = "  "
        XCTAssertNil(leer.op(datum: "2026-10-03", seit: basis))

        var neu = basis
        neu.bis = "22:00"
        let d = neu.op(datum: "2026-10-03", seit: basis)
        XCTAssertEqual(d, TreffenD(datum: "2026-10-03", uhrzeit: "12:00", wasMachenWir: "Düsseldorf", bis: "22:00"))

        var ohneVon = basis
        ohneVon.von = nil
        XCTAssertEqual(ohneVon.op(datum: "2026-10-03", seit: basis)?.uhrzeit, "")
        XCTAssertNil(ohneVon.op(datum: "2026-10-03", seit: basis)?.bis)

        let ohneAlles = TreffenBearbeitung(titel: "Kino", von: nil, bis: nil)
        var nurTitel = ohneAlles
        nurTitel.titel = "Kino 2"
        XCTAssertNil(nurTitel.op(datum: "2026-10-03", seit: ohneAlles)?.uhrzeit)
    }

    func testPunktAenderung() {
        func b(_ id: String, _ titel: String, gesperrt: Bool = false) -> PunktBearbeitung {
            var x = PunktBearbeitung(neuAm: nil)
            x.id = id
            x.titel = titel
            x.neu = false
            x.gesperrt = gesperrt
            return x
        }
        let ursprung = [b("a", "Eins"), b("b", "Zwei"), b("c", "Drei"), b("s", "", gesperrt: true)]
        var jetzt = ursprung
        jetzt[1].titel = "Zwei neu"
        jetzt.remove(at: 2)
        var neu = PunktBearbeitung(neuAm: "10:00")
        neu.titel = "Neu"
        var leer = PunktBearbeitung(neuAm: "11:00")
        leer.titel = " "
        jetzt += [neu, leer]

        let a = PunktAenderung.berechnen(ursprung: ursprung, jetzt: jetzt)
        XCTAssertEqual(a.speichern.map(\.id), ["b", neu.id])
        XCTAssertEqual(a.loeschen, ["c"])
        XCTAssertTrue(PunktAenderung.berechnen(ursprung: ursprung, jetzt: ursprung).speichern.isEmpty)
        XCTAssertTrue(PunktAenderung.berechnen(ursprung: ursprung, jetzt: ursprung).loeschen.isEmpty)
    }
}
