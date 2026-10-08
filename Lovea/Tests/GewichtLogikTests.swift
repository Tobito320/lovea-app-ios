import XCTest
@testable import Lovea

final class GewichtLogikTests: XCTestCase {
    func testSchnittDerLetztenSiebenTage() {
        // 80,0 am 20., dann 78,0 / 79,0 / 78,5 in der Woche bis 27. -> 20. liegt außerhalb.
        let werte = ["2026-09-20": 800, "2026-09-21": 780, "2026-09-24": 790, "2026-09-27": 785]
        XCTAssertEqual(GewichtLogik.berechnet(werte), 785)
    }

    func testFensterEndetAmNeuestenEintrag() {
        XCTAssertEqual(GewichtLogik.berechnet(["2026-08-01": 770, "2026-08-03": 780]), 775)
    }

    func testOhneEintragIstNil() {
        XCTAssertNil(GewichtLogik.berechnet([:]))
        XCTAssertNil(GewichtLogik.berechnet(["2026-09-27": 0]))
    }

    // MARK: Eingabe

    func testSchrittInZehnteln() {
        XCTAssertEqual(GewichtLogik.schritt("78,4", 1), "78,5")
        XCTAssertEqual(GewichtLogik.schritt("78,0", -1), "77,9")
        XCTAssertEqual(GewichtLogik.schritt("78,9", 1), "79,0")
        XCTAssertEqual(GewichtLogik.schritt("78.4", 1), "78,5")
    }

    func testSchrittBleibtImGueltigenBereich() {
        XCTAssertEqual(GewichtLogik.schritt("0,1", -1), "0,1")
        XCTAssertEqual(GewichtLogik.schritt("999,9", 1), "999,9")
    }

    func testSchrittOhneZahlIstNil() {
        XCTAssertNil(GewichtLogik.schritt("", 1))
        XCTAssertNil(GewichtLogik.schritt("abc", -1))
    }

    func testFeldMitKomma() {
        XCTAssertEqual(GewichtText.feld(784), "78,4")
        XCTAssertEqual(GewichtText.feld(5), "0,5")
    }

    // MARK: Anzeige

    func testAenderungZurMessungDavor() throws {
        let a = try XCTUnwrap(GewichtLogik.aenderung(["2026-09-20": 800, "2026-09-28": 790, "2026-09-30": 786]))
        XCTAssertEqual(a.zehntel, -4)
        XCTAssertEqual(a.seit, "2026-09-28")
    }

    func testAenderungBrauchtZweiMessungen() {
        XCTAssertNil(GewichtLogik.aenderung([:]))
        XCTAssertNil(GewichtLogik.aenderung(["2026-09-30": 786]))
        XCTAssertNil(GewichtLogik.aenderung(["2026-09-28": 0, "2026-09-30": 786]))
    }

    func testAenderungText() {
        XCTAssertEqual(GewichtText.aenderung(-4, seit: "2026-09-28"), "-0,4 kg seit 28.09.")
        XCTAssertEqual(GewichtText.aenderung(13, seit: "2026-09-28"), "+1,3 kg seit 28.09.")
        XCTAssertEqual(GewichtText.aenderung(0, seit: "2026-09-28"), "0,0 kg seit 28.09.")
    }

    // MARK: Kurve

    func testMittelReiheMitLuecken() {
        let reihe = GewichtLogik.mittelReihe(["2026-09-20": 800, "2026-09-24": 780, "2026-09-27": 790])
        XCTAssertEqual(reihe.map(\.tag), ["2026-09-20", "2026-09-24", "2026-09-27"])
        XCTAssertEqual(reihe[0].kg, 80.0, accuracy: 0.001)
        XCTAssertEqual(reihe[1].kg, 79.0, accuracy: 0.001)
        // Fenster 21. bis 27.: der 20. fällt heraus.
        XCTAssertEqual(reihe[2].kg, 78.5, accuracy: 0.001)
    }

    func testMittelReiheOhneWerte() {
        XCTAssertTrue(GewichtLogik.mittelReihe([:]).isEmpty)
        XCTAssertTrue(GewichtLogik.mittelReihe(["2026-09-27": 0]).isEmpty)
    }

    // MARK: Tageslog

    func testLogIstEinEintragJeTagNeuesterZuerst() {
        let log = GewichtLogik.log(["2026-09-20": 800, "2026-09-27": 785, "2026-09-24": 790, "2026-09-25": 0])
        XCTAssertEqual(log.map(\.tag), ["2026-09-27", "2026-09-24", "2026-09-20"])
        XCTAssertEqual(log.map(\.zehntel), [785, 790, 800])
    }

    func testStartFeldNimmtWertDesTages() {
        let werte = ["2026-09-20": 800, "2026-09-24": 790, "2026-09-27": 785]
        XCTAssertEqual(GewichtLogik.startFeld(werte, tag: "2026-09-24"), "79,0")
    }

    func testStartFeldOhneEintragNimmtLetztenDavor() {
        let werte = ["2026-09-20": 800, "2026-09-27": 785]
        XCTAssertEqual(GewichtLogik.startFeld(werte, tag: "2026-09-23"), "80,0")
        // Vor dem ersten Eintrag: der letzte ueberhaupt.
        XCTAssertEqual(GewichtLogik.startFeld(werte, tag: "2026-09-01"), "78,5")
        XCTAssertEqual(GewichtLogik.startFeld([:], tag: "2026-09-01"), "")
    }

    func testEintragNachtragenAendertNurDiesenTag() {
        var werte = ["2026-09-20": 800, "2026-09-27": 785]
        werte["2026-09-23"] = 795
        XCTAssertEqual(GewichtLogik.log(werte).map(\.tag), ["2026-09-27", "2026-09-23", "2026-09-20"])
        werte["2026-09-20"] = 0
        XCTAssertEqual(GewichtLogik.log(werte).map(\.tag), ["2026-09-27", "2026-09-23"])
    }
}
