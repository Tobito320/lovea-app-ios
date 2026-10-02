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
}
