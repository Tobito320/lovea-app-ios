import XCTest
@testable import Lovea

final class ZyklusLogikTests: XCTestCase {
    private func plus(_ tag: String, _ n: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: n, to: Datum.datum(tag))!)
    }

    /// Periode (mittel) über `dauer` Tage ab `start`.
    private func periode(_ start: String, dauer: Int = 5) -> [ZyklusTag] {
        (0..<dauer).map { ZyklusTag(id: plus(start, $0), blutung: .mittel) }
    }

    /// Perioden-Starts mit den gegebenen Zykluslängen ab 2026-01-01.
    private func verlauf(_ laengen: [Int], dauer: Int = 5) -> (tage: [ZyklusTag], letzterStart: String) {
        var start = "2026-01-01"
        var tage = periode(start, dauer: dauer)
        for l in laengen {
            start = plus(start, l)
            tage += periode(start, dauer: dauer)
        }
        return (tage, start)
    }

    private func logik(_ laengen: [Int], heuteNach tage: Int, dauer: Int = 5) -> (ZyklusLogik, String) {
        let v = verlauf(laengen, dauer: dauer)
        return (ZyklusLogik(tage: v.tage, heute: plus(v.letzterStart, tage)), v.letzterStart)
    }

    func testLeerLiefertStandardUndNichts() {
        let l = ZyklusLogik(tage: [], heute: "2026-03-10")
        XCTAssertEqual(l.mittlereZyklusLaenge, 28)
        XCTAssertEqual(l.mittlerePeriodenLaenge, 5)
        XCTAssertEqual(l.streuung, 0)
        XCTAssertNil(l.naechstePeriode)
        XCTAssertNil(l.eisprungTag)
        XCTAssertNil(l.fruchtbaresFenster)
        XCTAssertNil(l.phase(am: "2026-03-10"))
        XCTAssertNil(l.zyklusTagNummer(am: "2026-03-10"))
        XCTAssertNil(l.verspaetung)
        XCTAssertFalse(l.vorhersageSicher)
    }

    func testEinstellungGiltOhneZyklen() {
        let e = ZyklusEinstellung(zyklusLaenge: 31, periodenLaenge: 4, modus: .zyklus)
        let l = ZyklusLogik(tage: periode("2026-03-01"), einstellung: e, heute: "2026-03-03")
        XCTAssertEqual(l.naechstePeriode, "2026-04-01")
    }

    func testEinZyklusNurEinePeriodeNutztStandard28() {
        let l = ZyklusLogik(tage: periode("2026-03-01"), heute: "2026-03-05")
        XCTAssertEqual(l.zyklusLaengen, [])
        XCTAssertEqual(l.naechstePeriode, "2026-03-29")
        XCTAssertEqual(l.eisprungTag, "2026-03-15")
        XCTAssertEqual(l.streuung, 0)
    }

    func testZweiPeriodenGebenEinenZyklus() {
        let (l, _) = logik([30], heuteNach: 2)
        XCTAssertEqual(l.zyklusLaengen, [30])
        XCTAssertEqual(l.mittlereZyklusLaenge, 30)
        XCTAssertEqual(l.streuung, 0)
    }

    func testMittelUndStreuungAusMehrerenZyklen() {
        let (l, start) = logik([26, 28, 30, 28], heuteNach: 3)
        XCTAssertEqual(l.zyklusLaengen, [26, 28, 30, 28])
        XCTAssertEqual(l.mittlereZyklusLaenge, 28)
        XCTAssertEqual(l.streuung, 4)
        XCTAssertEqual(l.naechstePeriode, plus(start, 28))
        XCTAssertTrue(l.vorhersageSicher)
    }

    func testNurDieLetzten6ZyklenZaehlen() {
        let (l, _) = logik([40, 40, 28, 28, 28, 28, 28, 28], heuteNach: 3)
        XCTAssertEqual(l.mittlereZyklusLaenge, 28)
        XCTAssertEqual(l.streuung, 0)
    }

    func testMittelWirdGerundet() {
        let (l, _) = logik([28, 29], heuteNach: 1)
        XCTAssertEqual(l.mittlereZyklusLaenge, 29) // 28.5 rundet auf
    }

    func testMedianIgnoriertEinenAusreisser() {
        let (l, start) = logik([28, 28, 42, 28, 29], heuteNach: 3)
        XCTAssertEqual(l.mittlereZyklusLaenge, 28)
        XCTAssertEqual(l.naechstePeriode, plus(start, 28))
    }

    func testZeitraumFestOderAutomatisch() {
        let (l, start) = logik([26, 28, 30, 28], heuteNach: 3)
        let n = plus(start, 28)
        XCTAssertEqual(l.periodeZeitraum(breite: 0), n...n)
        XCTAssertEqual(l.periodeZeitraum(breite: 1), plus(start, 27)...plus(start, 29))
        XCTAssertEqual(l.periodeZeitraum(breite: nil), plus(start, 26)...plus(start, 30)) // Streuung 4, halbe 2
        XCTAssertEqual(l.periodeZeitraum(breite: 1, spaeter: 2), plus(start, 27)...plus(start, 31))
        let (wenig, s2) = logik([30], heuteNach: 2)
        XCTAssertEqual(wenig.periodeZeitraum(breite: nil), plus(s2, 28)...plus(s2, 32))
        XCTAssertNil(ZyklusLogik(tage: [], heute: "2026-03-10").periodeZeitraum(breite: nil))
    }

    func testZeitraumText() {
        XCTAssertEqual(ZyklusZeitraum.text("2026-11-03"..."2026-11-03"), "am 3. November")
        XCTAssertEqual(ZyklusZeitraum.text("2026-11-03"..."2026-11-06"), "3. bis 6. November")
        XCTAssertEqual(ZyklusZeitraum.text("2026-10-30"..."2026-11-02"), "30. Oktober bis 2. November")
    }

    func testAlltagHinweis() {
        let gut = Array(repeating: 450, count: 14)
        XCTAssertNil(ZyklusAlltag.hinweis(schlaf14: gut, schlaf60: gut + gut, kcal14: Array(repeating: 1900, count: 10), kcalZiel: 2000))
        let wenigSchlaf = ZyklusAlltag.hinweis(schlaf14: Array(repeating: 330, count: 10), schlaf60: [], kcal14: [], kcalZiel: 2000)
        XCTAssertEqual(wenigSchlaf?.texte.count, 1)
        XCTAssertEqual(wenigSchlaf?.spaeter, 2)
        XCTAssertNotNil(ZyklusAlltag.hinweis(schlaf14: Array(repeating: 400, count: 10), schlaf60: Array(repeating: 480, count: 40), kcal14: [], kcalZiel: 2000))
        XCTAssertNotNil(ZyklusAlltag.hinweis(schlaf14: [], schlaf60: [], kcal14: Array(repeating: 1200, count: 8), kcalZiel: 2000))
        XCTAssertNotNil(ZyklusAlltag.hinweis(schlaf14: [], schlaf60: [], kcal14: [800, 3200, 900, 3000, 1000, 3100, 2000], kcalZiel: 2000))
        XCTAssertNil(ZyklusAlltag.hinweis(schlaf14: Array(repeating: 300, count: 5), schlaf60: [], kcal14: [1000, 1000], kcalZiel: 2000), "zu wenig Tage")
    }

    func testGrosseStreuungMachtVorhersageUnsicher() {
        let (l, _) = logik([21, 35, 28], heuteNach: 1)
        XCTAssertEqual(l.streuung, 14)
        XCTAssertFalse(l.vorhersageSicher)
    }

    func testPeriodenlaengeAusDaten() {
        let (l, _) = logik([28, 28], heuteNach: 10, dauer: 4)
        XCTAssertEqual(l.periodenLaengen, [4, 4, 4])
        XCTAssertEqual(l.mittlerePeriodenLaenge, 4)
    }

    func testSchmierblutungStartetKeinePeriode() {
        var tage = periode("2026-03-01")
        tage.append(ZyklusTag(id: "2026-03-15", blutung: .schmierblutung))
        let l = ZyklusLogik(tage: tage, heute: "2026-03-20")
        XCTAssertEqual(l.periodenStarts, ["2026-03-01"])
    }

    func testLueckeVonEinemTagBleibtEinePeriode() {
        let tage = [ZyklusTag(id: "2026-03-01", blutung: .stark),
                    ZyklusTag(id: "2026-03-03", blutung: .mittel),
                    ZyklusTag(id: "2026-03-04", blutung: .leicht)]
        let l = ZyklusLogik(tage: tage, heute: "2026-03-10")
        XCTAssertEqual(l.periodenStarts, ["2026-03-01"])
        XCTAssertEqual(l.periodenLaengen, [4])
    }

    func testPhasenImLaufendenZyklus28() {
        // Start 2026-03-01, Zyklus 28 (Standard): Periode 1-5, Eisprung Tag 15 (03-15), fruchtbar 03-10..03-16.
        let l = ZyklusLogik(tage: periode("2026-03-01"), heute: "2026-03-20")
        XCTAssertEqual(l.phase(am: "2026-03-01"), .periode)
        XCTAssertEqual(l.phase(am: "2026-03-05"), .periode)
        XCTAssertEqual(l.phase(am: "2026-03-06"), .follikel)
        XCTAssertEqual(l.phase(am: "2026-03-09"), .follikel)
        XCTAssertEqual(l.phase(am: "2026-03-10"), .fruchtbar)
        XCTAssertEqual(l.phase(am: "2026-03-14"), .fruchtbar)
        XCTAssertEqual(l.phase(am: "2026-03-15"), .eisprung)
        XCTAssertEqual(l.phase(am: "2026-03-16"), .fruchtbar)
        XCTAssertEqual(l.phase(am: "2026-03-17"), .luteal)
        XCTAssertEqual(l.phase(am: "2026-03-28"), .luteal)
        XCTAssertEqual(l.phase(am: "2026-03-29"), .periode)
    }

    func testZyklusTagNummer() {
        let l = ZyklusLogik(tage: periode("2026-03-01"), heute: "2026-03-20")
        XCTAssertEqual(l.zyklusTagNummer(am: "2026-03-01"), 1)
        XCTAssertEqual(l.zyklusTagNummer(am: "2026-03-20"), 20)
        XCTAssertEqual(l.zyklusTagNummer(am: "2026-03-28"), 28)
        XCTAssertEqual(l.zyklusTagNummer(am: "2026-03-29"), 1)
        XCTAssertNil(l.zyklusTagNummer(am: "2026-02-28"))
    }

    func testFruchtbaresFensterUndEisprung() {
        let l = ZyklusLogik(tage: periode("2026-03-01"), heute: "2026-03-02")
        XCTAssertEqual(l.eisprungTag, "2026-03-15")
        XCTAssertEqual(l.fruchtbaresFenster, "2026-03-10"..."2026-03-16")
        XCTAssertTrue(l.fruchtbaresFenster!.contains("2026-03-15"))
        XCTAssertFalse(l.fruchtbaresFenster!.contains("2026-03-17"))
    }

    func testVergangenerZyklusNutztEchteLaenge() {
        // Zyklus 1: 03-01 bis 03-30 (30 Tage), Eisprung Tag 17 = 03-17.
        let tage = periode("2026-03-01") + periode("2026-03-31")
        let l = ZyklusLogik(tage: tage, heute: "2026-04-05")
        XCTAssertEqual(l.phase(am: "2026-03-17"), .eisprung)
        XCTAssertEqual(l.phase(am: "2026-03-30"), .luteal)
        XCTAssertEqual(l.phase(am: "2026-03-31"), .periode)
    }

    func testPeriodeDauerAusEchtenTagen() {
        let tage = periode("2026-03-01", dauer: 3) + periode("2026-03-29", dauer: 3)
        let l = ZyklusLogik(tage: tage, heute: "2026-04-10")
        XCTAssertEqual(l.phase(am: "2026-03-03"), .periode)
        XCTAssertEqual(l.phase(am: "2026-03-04"), .follikel)
    }

    func testZukunftWirdProjiziert() {
        let l = ZyklusLogik(tage: periode("2026-03-01"), heute: "2026-03-10")
        XCTAssertEqual(l.phase(am: "2026-03-29"), .periode)
        XCTAssertEqual(l.phase(am: "2026-04-11"), .fruchtbar)
        XCTAssertEqual(l.phase(am: "2026-04-12"), .eisprung)
        XCTAssertEqual(l.zyklusTagNummer(am: "2026-04-26"), 1)
        XCTAssertEqual(l.phase(am: "2026-05-27"), .periode) // 03-01 + 84 = 05-24, Tag 4
    }

    func testZyklusLaenge21() {
        let (l, start) = logik([21, 21, 21], heuteNach: 2)
        XCTAssertEqual(l.mittlereZyklusLaenge, 21)
        XCTAssertEqual(l.eisprungTag, plus(start, 7))
        XCTAssertEqual(l.fruchtbaresFenster, plus(start, 2)...plus(start, 8))
        XCTAssertEqual(l.phase(am: plus(start, 7)), .eisprung)
        XCTAssertEqual(l.phase(am: plus(start, 5)), .fruchtbar)
        XCTAssertEqual(l.phase(am: plus(start, 20)), .luteal)
        XCTAssertEqual(l.phase(am: plus(start, 21)), .periode)
    }

    func testZyklusLaenge40() {
        let (l, start) = logik([40, 40], heuteNach: 2)
        XCTAssertEqual(l.eisprungTag, plus(start, 26))
        XCTAssertEqual(l.phase(am: plus(start, 26)), .eisprung)
        XCTAssertEqual(l.phase(am: plus(start, 15)), .follikel)
        XCTAssertEqual(l.phase(am: plus(start, 21)), .fruchtbar)
        XCTAssertEqual(l.phase(am: plus(start, 39)), .luteal)
        XCTAssertEqual(l.naechstePeriode, plus(start, 40))
    }

    func testPeriodeUeberlagertFruchtbaresFensterBeiKurzemZyklus() {
        let (l, start) = logik([15, 15], heuteNach: 1)
        XCTAssertEqual(l.phase(am: plus(start, 1)), .periode)
    }

    func testKeineVerspaetungAmErwartetenTagOderDavor() {
        let (l, start) = logik([28, 28], heuteNach: 28)
        XCTAssertEqual(l.naechstePeriode, plus(start, 28))
        XCTAssertNil(l.verspaetung)
        XCTAssertNil(l.verspaetungHinweis)
        XCTAssertNil(logik([28, 28], heuteNach: 20).0.verspaetung)
    }

    func testVerspaetung() {
        let (l, start) = logik([28, 28], heuteNach: 31)
        XCTAssertEqual(l.verspaetung, 3)
        XCTAssertEqual(l.verspaetungHinweis, "Deine Periode ist 3 Tage später als erwartet.")
        XCTAssertEqual(l.phase(am: plus(start, 30)), .luteal)
        XCTAssertNil(l.phase(am: plus(start, 32)), "Zukunft bei überfälliger Periode unbekannt")
        XCTAssertEqual(logik([28, 28], heuteNach: 29).0.verspaetungHinweis, "Deine Periode ist 1 Tag später als erwartet.")
    }

    func testVerspaetungOhneNeuePeriodeEineWocheMitArztHinweis() {
        let (l, _) = logik([28, 28], heuteNach: 36)
        XCTAssertEqual(l.verspaetung, 8)
        XCTAssertTrue(l.verspaetungHinweis!.contains("Ärztin"))
    }

    func testNeuePeriodeBeendetVerspaetung() {
        let v = verlauf([28, 28])
        let neu = periode(plus(v.letzterStart, 33))
        let l = ZyklusLogik(tage: v.tage + neu, heute: plus(v.letzterStart, 34))
        XCTAssertNil(l.verspaetung)
        XCTAssertEqual(l.periodenStarts.last, plus(v.letzterStart, 33))
    }

    func testLaufendePeriodeBisHeuteGeloggtGiltAlsPeriode() {
        // Erst Tag 1 und 2 eingetragen, Standardlänge 5: Tag 3 (heute) noch Periode.
        let tage = [ZyklusTag(id: "2026-03-01", blutung: .mittel), ZyklusTag(id: "2026-03-02", blutung: .stark)]
        let l = ZyklusLogik(tage: tage, heute: "2026-03-03")
        XCTAssertEqual(l.phase(am: "2026-03-03"), .periode)
    }

    func testTageOhneBlutungAendernNichts() {
        var tage = periode("2026-03-01")
        tage.append(ZyklusTag(id: "2026-03-08", symptome: [.akne], stimmung: [.ruhig], notiz: "x"))
        let l = ZyklusLogik(tage: tage, heute: "2026-03-10")
        XCTAssertEqual(l.periodenStarts, ["2026-03-01"])
    }

    func testIstLeer() {
        XCTAssertTrue(ZyklusTag(id: "2026-03-01").istLeer)
        XCTAssertTrue(ZyklusTag(id: "2026-03-01", notiz: "").istLeer)
        XCTAssertFalse(ZyklusTag(id: "2026-03-01", wasserMl: 0).istLeer)
        XCTAssertFalse(ZyklusTag(id: "2026-03-01", symptome: [.akne]).istLeer)
    }

    func testStandardEinstellungUndCodable() throws {
        let e = ZyklusEinstellung()
        XCTAssertEqual(e.zyklusLaenge, 28)
        XCTAssertEqual(e.periodenLaenge, 5)
        XCTAssertEqual(e.modus, .zyklus)
        let t = ZyklusTag(id: "2026-03-01", blutung: .stark, symptome: [.kraempfe, .akne], temperatur: 36.5, pille: true, notiz: "n")
        let daten = try JSONEncoder().encode(t)
        XCTAssertEqual(try JSONDecoder().decode(ZyklusTag.self, from: daten), t)
    }

    func testMonatsUndJahreswechsel() {
        let tage = periode("2025-12-29") + periode("2026-01-26")
        let l = ZyklusLogik(tage: tage, heute: "2026-02-01")
        XCTAssertEqual(l.zyklusLaengen, [28])
        XCTAssertEqual(l.naechstePeriode, "2026-02-23")
        XCTAssertEqual(l.eisprungTag, "2026-02-09")
    }

    // MARK: Demo-Daten

    func testDemoIstDeterministisch() {
        XCTAssertEqual(ZyklusDemoDaten.tage(heute: "2026-10-03"), ZyklusDemoDaten.tage(heute: "2026-10-03"))
    }

    func testDemoUmfangUndKeineZukunft() {
        let t = ZyklusDemoDaten.tage(heute: "2026-10-03")
        let ids = t.keys.sorted()
        XCTAssertLessThanOrEqual(ids.last!, "2026-10-03")
        XCTAssertGreaterThan(t.count, 200)
        XCTAssertLessThan(ids.first!, "2026-02-15")
        XCTAssertEqual(t.filter { $0.key != $0.value.id }.count, 0)
    }

    func testDemoZyklenStimmen() {
        let heute = "2026-10-03"
        let l = ZyklusLogik(tage: Array(ZyklusDemoDaten.tage(heute: heute).values), einstellung: ZyklusDemoDaten.einstellung, heute: heute)
        XCTAssertEqual(l.periodenStarts.count, 9)
        XCTAssertEqual(l.zyklusLaengen, ZyklusDemoDaten.zyklusLaengen)
        XCTAssertEqual(l.mittlereZyklusLaenge, 28)
        XCTAssertEqual(l.streuung, 4)
        XCTAssertTrue(l.vorhersageSicher)
        XCTAssertEqual(l.letzterPeriodenStart, "2026-09-24")
        XCTAssertEqual(l.zyklusTagNummer(am: heute), 10)
        XCTAssertEqual(l.phase(am: heute), .fruchtbar)
        XCTAssertEqual(l.naechstePeriode, "2026-10-22")
        XCTAssertNil(l.verspaetung)
    }

    func testDemoEnthaeltTemperaturTestsUndSymptome() {
        let t = ZyklusDemoDaten.tage(heute: "2026-10-03").values
        XCTAssertTrue(t.contains { $0.temperatur != nil })
        XCTAssertTrue(t.contains { $0.eisprungTest == .positiv })
        XCTAssertTrue(t.contains { $0.symptome.contains(.kraempfe) })
        XCTAssertTrue(t.contains { $0.notiz != nil })
        XCTAssertTrue(t.compactMap(\.temperatur).allSatisfy { $0 > 36 && $0 < 37.2 })
    }

    func testDemoPeriodenLaengen() {
        let heute = "2026-10-03"
        let l = ZyklusLogik(tage: Array(ZyklusDemoDaten.tage(heute: heute).values), heute: heute)
        XCTAssertEqual(l.periodenLaengen, [5, 4, 5, 5, 4, 5, 5, 4, 5])
    }
}
