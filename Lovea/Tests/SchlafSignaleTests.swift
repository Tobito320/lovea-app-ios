import XCTest
@testable import Lovea

/// Schlaf-Signale: Ereignisse (Laden, Fokus, Boot, App geöffnet) werden zu Spannen für das Punktesystem.
final class SchlafSignaleTests: XCTestCase {
    private func zeit(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde, minute: minute))!
    }

    private func s(_ art: String, _ an: Bool, _ z: Date) -> SchlafSignal { SchlafSignal(art: art, zeit: z, an: an) }

    func testSpannenPaarUndOffenesEnde() {
        let liste = [s("laden", true, zeit(4, 23)), s("laden", false, zeit(5, 7)), s("laden", true, zeit(5, 22))]
        let r = SchlafSignale.spannen(liste, art: "laden", bis: zeit(5, 23))
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[0].von, zeit(4, 23)); XCTAssertEqual(r[0].bis, zeit(5, 7))
        XCTAssertEqual(r[1].bis, zeit(5, 23), "offen bis jetzt")
    }

    func testUnterwegsIstDieLueckeImHeimWlan() {
        let liste = [s("daheim", true, zeit(4, 18)), s("daheim", false, zeit(4, 20)), s("daheim", true, zeit(4, 23))]
        let r = SchlafSignale.spannen(liste, art: "daheim", wennAn: false, bis: zeit(5, 7))
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].von, zeit(4, 20)); XCTAssertEqual(r[0].bis, zeit(4, 23))
    }

    func testGleicherZustandWirdNichtDoppeltGespeichert() {
        var l = SchlafSignale.hinzufuegen([], s("laden", true, zeit(4, 23)), jetzt: zeit(4, 23))
        l = SchlafSignale.hinzufuegen(l, s("laden", true, zeit(4, 23, 5)), jetzt: zeit(4, 23, 5))
        XCTAssertEqual(l.count, 1)
        l = SchlafSignale.hinzufuegen(l, s("aktiv", true, zeit(4, 23, 6)), jetzt: zeit(4, 23, 6))
        l = SchlafSignale.hinzufuegen(l, s("aktiv", true, zeit(4, 23, 8)), jetzt: zeit(4, 23, 8))
        XCTAssertEqual(l.count, 3, "Punkt-Ereignisse zählen jedes Mal")
    }

    func testAlteEintraegeFallenNachZweiWochenWeg() {
        let alt = s("laden", true, zeit(1, 23))
        let l = SchlafSignale.hinzufuegen([alt], s("laden", false, zeit(20, 7)), jetzt: zeit(20, 7))
        XCTAssertEqual(l.count, 1)
        XCTAssertFalse(l.contains(alt))
    }

    func testWeckerAusNurAmMorgenDesTages() {
        let tagStart = Calendar.berlin.startOfDay(for: zeit(5, 12))
        let liste = [s("wecker", true, zeit(4, 7)), s("wecker", true, zeit(5, 7)), s("wecker", true, zeit(5, 7, 30))]
        XCTAssertEqual(SchlafSignale.weckerAus(liste, tagStart: tagStart), zeit(5, 7))
        XCTAssertNil(SchlafSignale.weckerAus([s("wecker", true, zeit(5, 1))], tagStart: tagStart), "01 Uhr ist zu früh")
    }

    // MARK: - Boot

    func testBootNachKurzemAusIstEinAusUndEinWach() {
        let e = SchlafSignale.bootEreignisse(boot: zeit(4, 22, 40), letzterBoot: zeit(1, 9), lebt: zeit(4, 22))
        XCTAssertEqual(e.filter { $0.art == "aus" }.count, 2)
        XCTAssertEqual(e.filter { $0.art == "aktiv" }.first?.zeit, zeit(4, 22, 40))
        let aus = SchlafSignale.spannen(e, art: "aus", bis: zeit(5, 7))
        XCTAssertEqual(aus.first?.von, zeit(4, 22)); XCTAssertEqual(aus.first?.bis, zeit(4, 22, 40))
    }

    func testBootNachLangerLueckeIstNurWach() {
        let e = SchlafSignale.bootEreignisse(boot: zeit(5, 7), letzterBoot: zeit(1, 9), lebt: zeit(4, 22))
        XCTAssertTrue(e.filter { $0.art == "aus" }.isEmpty, "9 h ist keine Ausschalt-Pause")
        XCTAssertEqual(e.count, 1)
    }

    func testKeinNeuerBootKeineEreignisse() {
        XCTAssertTrue(SchlafSignale.bootEreignisse(boot: zeit(1, 9), letzterBoot: zeit(1, 9), lebt: zeit(4, 22)).isEmpty)
        XCTAssertTrue(SchlafSignale.bootEreignisse(boot: zeit(1, 9), letzterBoot: nil, lebt: nil).isEmpty, "erster Start nach der Installation")
    }

    // MARK: - Mit dem Punktesystem

    private func ende(_ tag: Int, _ stunde: Int) -> Date { zeit(tag, stunde) }

    func testGriffZumHandyTeiltDieNachtNichtAuf() {
        var e = SchlafLogik.PunkteEingabe(tag: "2026-09-25", fensterEnde: ende(25, 7))
        e.aktivitaeten = [SchlafLogik.Aktivitaet(zeit: zeit(24, 23), stationaer: true, konfidenz: .hoch)]
        e.wach = SchlafSignale.kurzWach([zeit(25, 3)])
        XCTAssertEqual(SchlafLogik.punkte(e).nacht?.minuten, 8 * 60 - 3)
    }

    func testLadenFokusUndWeckerGebenKonfidenzUndEnde() {
        var e = SchlafLogik.PunkteEingabe(tag: "2026-09-25", fensterEnde: ende(25, 9))
        e.aktivitaeten = [SchlafLogik.Aktivitaet(zeit: zeit(24, 23), stationaer: true, konfidenz: .hoch)]
        e.laden = [HealthLogik.SchlafIntervall(von: zeit(24, 23), bis: zeit(25, 9))]
        e.fokus = [HealthLogik.SchlafIntervall(von: zeit(24, 23), bis: zeit(25, 9))]
        e.wecker = zeit(25, 7)
        let r = SchlafLogik.punkte(e)
        XCTAssertEqual(r.nacht?.bis, zeit(25, 7), "Wecker aus beendet die Nacht")
        XCTAssertEqual(r.konfidenz, .hoch)
    }

    // MARK: - Gewohnheit

    private func nacht(_ tag: Int, vonStunde: Int = 23, vonMinute: Int = 0) -> SchlafLogik.BekannteNacht {
        SchlafLogik.BekannteNacht(tag: String(format: "2026-09-%02d", tag), von: zeit(tag - 1, vonStunde, vonMinute), bis: zeit(tag, 7))
    }

    func testGewohnheitMedianUnterWoche() {
        // 21.09. bis 23.09.2026 sind Montag bis Mittwoch.
        let g = SchlafLogik.gewohnheit([nacht(21), nacht(22), nacht(23)], wochenende: false)
        XCTAssertEqual(g?.bett, 23 * 60)
        XCTAssertEqual(g?.auf, 7 * 60)
        XCTAssertNil(SchlafLogik.gewohnheit([nacht(21), nacht(22), nacht(23)], wochenende: true), "keine Wochenend-Nächte bekannt")
    }

    func testGewohnheitUnterDreiNaechtenNichts() {
        XCTAssertNil(SchlafLogik.gewohnheit([nacht(21), nacht(22)], wochenende: false))
    }

    func testGewohnheitBettzeitNachMitternachtLiegtHinter23Uhr() {
        // 23:00, 00:30, 23:30: der Median ist 23:30, nicht 00:30.
        let n = [nacht(21), SchlafLogik.BekannteNacht(tag: "2026-09-22", von: zeit(22, 0, 30), bis: zeit(22, 8)), nacht(23, vonStunde: 23, vonMinute: 30)]
        XCTAssertEqual(SchlafLogik.gewohnheit(n, wochenende: false)?.bett, 23 * 60 + 30)
    }
}
