import XCTest
@testable import Lovea

/// Teil 6: automatische Schlaferkennung (Vorrang, Im-Bett-Lücken, Bewegungs-Schätzung) und Schlafziel.
final class SchlafAutomatikTests: XCTestCase {
    private func intervall(_ tag: Int, _ stunde: Int, _ minute: Int = 0, _ tagBis: Int, _ stundeBis: Int, _ minuteBis: Int = 0) -> HealthLogik.SchlafIntervall {
        HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde, minute: minute))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tagBis, hour: stundeBis, minute: minuteBis))!
        )
    }

    // MARK: - a) Eigener Eintrag gewinnt immer

    func testMinutenEintragVorAutomatik() {
        XCTAssertEqual(SchlafLogik.minuten(eintrag: 500, automatik: 300), 500)
    }

    func testMinutenGeloeschtSperrtAutomatik() {
        // 0 min = gelöscht: darf nicht auf die Automatik durchfallen, sonst täte "Löschen" nichts.
        XCTAssertNil(SchlafLogik.minuten(eintrag: 0, automatik: 300))
    }

    func testMinutenOhneEintragFaelltDurch() {
        XCTAssertEqual(SchlafLogik.minuten(eintrag: nil, automatik: 300), 300)
        XCTAssertNil(SchlafLogik.minuten(eintrag: nil, automatik: nil))
    }

    func testQuelleEintragVorAutomatik() {
        XCTAssertEqual(SchlafLogik.quelle(eintrag: 500, automatikQuelle: "Apple Watch"), "eingetragen")
        XCTAssertEqual(SchlafLogik.quelle(eintrag: nil, automatikQuelle: "Apple Watch"), "Apple Watch")
        XCTAssertNil(SchlafLogik.quelle(eintrag: 0, automatikQuelle: "Apple Watch"))
    }

    // MARK: - Watch vor Punktesystem

    func testWatchGewinntVorPunkten() {
        let watch = (minuten: 400, von: Date(), bis: Date())
        let punkte = SchlafLogik.PunkteErgebnis(nacht: (300, Date(), Date()), konfidenz: .hoch, nickerchen: [], wachLuecken: [])
        let ergebnis = SchlafLogik.automatikVorrang(watch: watch, punkte: punkte)
        XCTAssertEqual(ergebnis?.minuten, 400)
        XCTAssertEqual(ergebnis?.quelle, "Apple Watch")
    }

    func testPunktesystemOhneWatchMitQuelleUndKonfidenz() {
        let punkte = SchlafLogik.PunkteErgebnis(nacht: (300, Date(), Date()), konfidenz: .mittel, nickerchen: [], wachLuecken: [])
        let ergebnis = SchlafLogik.automatikVorrang(watch: nil, punkte: punkte)
        XCTAssertEqual(ergebnis?.minuten, 300)
        XCTAssertEqual(ergebnis?.quelle, "Punktesystem, wahrscheinlich")
        XCTAssertNil(SchlafLogik.automatikVorrang(watch: nil, punkte: nil))
        XCTAssertNil(SchlafLogik.automatikVorrang(watch: nil, punkte: SchlafLogik.PunkteErgebnis(nacht: nil, konfidenz: .niedrig, nickerchen: [], wachLuecken: [])))
    }

    // MARK: - Punktesystem

    private func aktiv(_ tag: Int, _ stunde: Int, _ minute: Int = 0, stationaer: Bool, konfidenz: SchlafLogik.Konfidenz = .hoch) -> SchlafLogik.Aktivitaet {
        SchlafLogik.Aktivitaet(zeit: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde, minute: minute))!,
                              stationaer: stationaer, konfidenz: konfidenz)
    }

    private func ende(_ tag: Int, _ stunde: Int) -> Date {
        Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde))!
    }

    private func rechne(_ aktivitaeten: [SchlafLogik.Aktivitaet], tag: Int, bis stunde: Int, _ aendern: (inout SchlafLogik.PunkteEingabe) -> Void = { _ in }) -> SchlafLogik.PunkteErgebnis {
        var e = SchlafLogik.PunkteEingabe(tag: String(format: "2026-09-%02d", tag), fensterEnde: ende(tag, stunde))
        e.aktivitaeten = aktivitaeten
        aendern(&e)
        return SchlafLogik.punkte(e)
    }

    func testToilettengangBleibtEineNacht() {
        let a = [aktiv(24, 23, stationaer: true), aktiv(25, 3, 58, stationaer: false), aktiv(25, 4, 1, stationaer: true)]
        // 8 h minus die 3 Minuten am Handy.
        XCTAssertEqual(rechne(a, tag: 25, bis: 7).nacht?.minuten, 8 * 60 - 3)
    }

    func test20MinWachTeiltDieNachtZaehltAberNichtMit() {
        let a = [aktiv(24, 23, stationaer: true), aktiv(25, 3, 50, stationaer: false), aktiv(25, 4, 10, stationaer: true)]
        let r = rechne(a, tag: 25, bis: 7)
        XCTAssertEqual(r.nacht?.minuten, 290 + 170)
        XCTAssertEqual(r.wachLuecken.count, 1)
    }

    func testSchreibtischIstKeineNacht() {
        // 2 h Schlaf, dann wach bis 09:00, dann ruhig am Schreibtisch 09:00 bis 14:00.
        let a = [aktiv(24, 23, stationaer: true), aktiv(25, 1, stationaer: false), aktiv(25, 9, stationaer: true)]
        let r = rechne(a, tag: 25, bis: 14)
        XCTAssertNil(r.nacht, "unter 3 h ist keine Nacht")
        XCTAssertEqual(r.nickerchen.count, 1, "kurzer Schlaf wird Nickerchen, nicht verworfen")
    }

    func testHandyKurzAusIstKeineNacht() {
        // Ahmed, 05.10.: Handy 22:00 bis 22:40 aus (letzter Stand "still"), danach in der Hand.
        let a = [aktiv(4, 22, stationaer: true), aktiv(4, 22, 40, stationaer: false)]
        XCTAssertNil(rechne(a, tag: 5, bis: 14).nacht)
    }

    func testHandyAusMinusPunkteStreichtSchlaf() {
        // Gleiche Lage, aber ohne Handy-Nutzung: der Kurzbefehl meldet "aus" 22:00 bis 02:00.
        let a = [aktiv(4, 22, stationaer: true)]
        let r = rechne(a, tag: 5, bis: 7) { e in
            e.aus = [HealthLogik.SchlafIntervall(von: self.ende(4, 22), bis: self.ende(5, 2))]
        }
        XCTAssertEqual(r.nacht?.minuten, 5 * 60, "02:00 bis 07:00, die Ausphase zählt nicht")
    }

    func testHandyNachtsInDerHandGiltNichtAlsSchlaf() {
        let a = [
            aktiv(24, 23, stationaer: true),
            aktiv(25, 3, 30, stationaer: false),
            aktiv(25, 3, 36, stationaer: false, konfidenz: .niedrig),
            aktiv(25, 3, 43, stationaer: false),
            aktiv(25, 3, 50, stationaer: true),
        ]
        XCTAssertEqual(rechne(a, tag: 25, bis: 7).nacht?.minuten, 270 + 190)
    }

    func testWeckerAusUndHandyImBettBeendetDieNacht() {
        // Ahmed, 27.09.: Wecker 07:00 aus, danach im Bett am Handy, 08:20 aufgestanden. Aufgewacht um 07:00.
        let a = [
            aktiv(27, 0, 30, stationaer: true), aktiv(27, 7, 0, stationaer: false), aktiv(27, 7, 3, stationaer: true),
            aktiv(27, 7, 40, stationaer: false, konfidenz: .niedrig), aktiv(27, 7, 44, stationaer: true), aktiv(27, 8, 20, stationaer: false),
        ]
        let r = rechne(a, tag: 27, bis: 9)
        XCTAssertEqual(r.nacht?.bis, ende(27, 7))
        XCTAssertEqual(r.nacht?.minuten, 6 * 60 + 30)
    }

    func testPcAktivBeiStillemHandyIstKeinSchlaf() {
        // Handy liegt 22:00 bis 07:00 still, aber der PC war bis 01:00 mit echter Maus aktiv.
        let a = [aktiv(4, 22, stationaer: true)]
        let r = rechne(a, tag: 5, bis: 7) { e in
            e.pc = [HealthLogik.SchlafIntervall(von: self.ende(4, 22), bis: self.ende(5, 1))]
        }
        XCTAssertEqual(r.nacht?.von, ende(5, 1))
        XCTAssertEqual(r.nacht?.minuten, 6 * 60)
    }

    func testTonUeberAirPodsIstWach() {
        let a = [aktiv(4, 23, stationaer: true)]
        let r = rechne(a, tag: 5, bis: 7) { e in
            e.ton = [HealthLogik.SchlafIntervall(von: self.ende(4, 23), bis: self.ende(5, 0))]
        }
        XCTAssertEqual(r.nacht?.von, ende(5, 0), "Einschlafen, wenn der Ton endet")
    }

    func testMehrHinweiseMehrKonfidenz() {
        let a = [aktiv(24, 23, stationaer: true)]
        let schwach = rechne(a, tag: 25, bis: 7)
        let stark = rechne(a, tag: 25, bis: 7) { e in
            e.laden = [HealthLogik.SchlafIntervall(von: self.ende(24, 23), bis: self.ende(25, 7))]
            e.fokus = [HealthLogik.SchlafIntervall(von: self.ende(24, 23), bis: self.ende(25, 7))]
        }
        XCTAssertEqual(schwach.konfidenz, .niedrig)
        XCTAssertEqual(stark.konfidenz, .hoch)
    }

    func testOhneDatenKeineNacht() {
        XCTAssertNil(rechne([], tag: 25, bis: 7).nacht)
    }

    // MARK: - Schlafziel mit flexiblen Tagen

    func testSchlafZielAnFlexiblenTagen() {
        let extraTage = (1 << 5) | (1 << 6) // Samstag (Bit 5) + Sonntag (Bit 6)
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: 60, extraTage: extraTage, wochentag: 6), 540, "Samstag")
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: 60, extraTage: extraTage, wochentag: 1), 480, "Montag ohne Extra")
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: -600, extraTage: extraTage, wochentag: 7), 0, "nie unter 0")
    }
}
