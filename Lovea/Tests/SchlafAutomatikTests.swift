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

    // MARK: - b/c) Watch vor iPhone-Schlafenszeit vor Bewegung

    func testAutomatikVorrangWatchVorIphone() {
        let watch = (minuten: 400, von: Date(), bis: Date())
        let iphone = (minuten: 300, von: Date(), bis: Date())
        let ergebnis = SchlafLogik.automatikVorrang(watch: watch, iphone: iphone, geschaetzt: nil)
        XCTAssertEqual(ergebnis?.minuten, 400)
        XCTAssertEqual(ergebnis?.quelle, .appleWatch)
    }

    func testAutomatikVorrangIphoneOhneWatch() {
        let iphone = (minuten: 300, von: Date(), bis: Date())
        let ergebnis = SchlafLogik.automatikVorrang(watch: nil, iphone: iphone, geschaetzt: nil)
        XCTAssertEqual(ergebnis?.quelle, .iphoneSchlafenszeit)
    }

    func testAutomatikVorrangGeschaetztNurAlsLetztes() {
        let geschaetzt = (minuten: 200, von: Date(), bis: Date())
        XCTAssertNil(SchlafLogik.automatikVorrang(watch: nil, iphone: nil, geschaetzt: nil))
        XCTAssertEqual(SchlafLogik.automatikVorrang(watch: nil, iphone: nil, geschaetzt: geschaetzt)?.quelle, .geschaetzt)
    }

    // MARK: - c) Im Bett: Lücken (Handy nachts benutzt) fallen raus

    func testImBettMitHandynutzungAusgeschlossen() {
        // 23:00–07:00, dazwischen 04:00–04:15 am Handy: 8 h minus 15 min = 7 h 45.
        let intervalle = [intervall(23, 23, 0, 24, 4, 0), intervall(24, 4, 15, 24, 7, 0)]
        let ergebnis = SchlafLogik.imBettSchaetzung(intervalle, tag: "2026-09-24")
        XCTAssertEqual(ergebnis?.minuten, 7 * 60 + 45)
    }

    // MARK: - d) Bewegungs-Schätzung

    private func aktiv(_ tag: Int, _ stunde: Int, _ minute: Int = 0, stationaer: Bool, konfidenz: SchlafLogik.Konfidenz = .hoch) -> SchlafLogik.Aktivitaet {
        SchlafLogik.Aktivitaet(zeit: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde, minute: minute))!,
                              stationaer: stationaer, konfidenz: konfidenz)
    }

    func testBewegungToilettengangBleibtEinBlock() {
        // 23:00 schlafen, 03:58–04:01 kurz auf (mit Schritten: Toilettengang), dann weiter bis 07:00.
        let aktivitaeten = [
            aktiv(24, 23, stationaer: true),
            aktiv(25, 3, 58, stationaer: false),
            aktiv(25, 4, 1, stationaer: true),
        ]
        let fensterEnde = Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 7))!
        let ergebnis = SchlafLogik.bewegungsSchaetzung(aktivitaeten, fensterEnde: fensterEnde, tag: "2026-09-25")
        // Bleibt EIN Block (Lücke unter 10 min): volle Nacht minus die 3 Minuten mit Schritten.
        XCTAssertEqual(ergebnis?.minuten, 8 * 60 - 3)
    }

    func test20MinWachTeiltDieNacht() {
        // 23:00 schlafen, 20 min richtig wach (03:50–04:10), dann weiter bis 07:00.
        let aktivitaeten = [
            aktiv(24, 23, stationaer: true),
            aktiv(25, 3, 50, stationaer: false),
            aktiv(25, 4, 10, stationaer: true),
        ]
        let fensterEnde = Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 7))!
        let ergebnis = SchlafLogik.bewegungsSchaetzung(aktivitaeten, fensterEnde: fensterEnde, tag: "2026-09-25")
        // 20 min reißen die 10-Minuten-Schwelle: zwei Abschnitte derselben Nacht, zusammengezählt ohne die
        // Wachzeit: 23:00–03:50 (290 min) + 04:10–07:00 (170 min) = 460 min.
        XCTAssertEqual(ergebnis?.minuten, 460)
    }

    func testBewegungSchreibtischZaehltNichtAlsNacht() {
        // Kurze Nacht 23:00–01:00 (120 min), dann 8 h Lücke, dann ruhig am Schreibtisch 09:00–14:00
        // (300 min) — ohne die 6-Uhr-Grenze würde der Schreibtisch als (größerer) Nacht-Teil gewinnen.
        let aktivitaeten = [
            aktiv(24, 23, stationaer: true),
            aktiv(25, 1, stationaer: false),
            aktiv(25, 9, stationaer: true),
        ]
        let fensterEnde = Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 14))!
        let ergebnis = SchlafLogik.bewegungsSchaetzung(aktivitaeten, fensterEnde: fensterEnde, tag: "2026-09-25")
        XCTAssertEqual(ergebnis?.minuten, 120)
    }

    func testHandyNachtsInDerHandGiltNichtAlsSchlaf() {
        // 23:00 schlafen, 03:30 Handy in die Hand, alle paar Minuten neue Bewegung ohne Schritte
        // (kurze Stücke unter 10 min), 03:50 wieder hingelegt, schlafen bis 07:00 (Fensterende).
        let aktivitaeten = [
            aktiv(24, 23, stationaer: true),
            aktiv(25, 3, 30, stationaer: false),
            aktiv(25, 3, 36, stationaer: false, konfidenz: .niedrig),
            aktiv(25, 3, 43, stationaer: false),
            aktiv(25, 3, 50, stationaer: true),
        ]
        let fensterEnde = Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 7))!
        let ergebnis = SchlafLogik.bewegungsSchaetzung(aktivitaeten, fensterEnde: fensterEnde, tag: "2026-09-25")
        // 23:00–03:30 (270) + 03:50–07:00 (190), die 20 min am Handy zählen nicht.
        XCTAssertEqual(ergebnis?.minuten, 460)
    }

    func testWeckerAusUndHandyImBettBeendetDieNacht() {
        // Ahmed, 27.09.: Wecker um 07:00 aus, danach im Bett am Handy (liegt meist still), um 08:20
        // aufgestanden. Aufgewacht ist er um 07:00, nicht 08:20.
        let aktivitaeten = [
            aktiv(27, 0, 30, stationaer: true),
            aktiv(27, 7, 0, stationaer: false),
            aktiv(27, 7, 3, stationaer: true),
            aktiv(27, 7, 40, stationaer: false, konfidenz: .niedrig),
            aktiv(27, 7, 44, stationaer: true),
            aktiv(27, 8, 20, stationaer: false),
        ]
        let fensterEnde = Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 9))!
        let ergebnis = SchlafLogik.bewegungsSchaetzung(aktivitaeten, fensterEnde: fensterEnde, tag: "2026-09-27")
        XCTAssertEqual(ergebnis?.bis, Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 7)))
        XCTAssertEqual(ergebnis?.minuten, 6 * 60 + 30)
    }

    func testBewegungsSchaetzungOhneDatenIstNil() {
        XCTAssertNil(SchlafLogik.bewegungsSchaetzung([], fensterEnde: Date(), tag: "2026-09-25"))
    }

    // MARK: - Schlafziel mit flexiblen Tagen

    func testSchlafZielAnFlexiblenTagen() {
        let extraTage = (1 << 5) | (1 << 6) // Samstag (Bit 5) + Sonntag (Bit 6)
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: 60, extraTage: extraTage, wochentag: 6), 540, "Samstag")
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: 60, extraTage: extraTage, wochentag: 1), 480, "Montag ohne Extra")
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: -600, extraTage: extraTage, wochentag: 7), 0, "nie unter 0")
    }
}
