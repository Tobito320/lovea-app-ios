import XCTest
@testable import Lovea

final class ZimmerAnlassLogikTests: XCTestCase {
    private func tag(_ m: Int, _ d: Int, _ j: Int = 2026) -> Date {
        Calendar.berlin.date(from: DateComponents(year: j, month: m, day: d, hour: 12))!
    }

    func testJahreszeiten() {
        XCTAssertEqual(ZimmerJahreszeitLogik.zeit(am: tag(3, 1)), .fruehling)
        XCTAssertEqual(ZimmerJahreszeitLogik.zeit(am: tag(7, 15)), .sommer)
        XCTAssertEqual(ZimmerJahreszeitLogik.zeit(am: tag(11, 30)), .herbst)
        XCTAssertEqual(ZimmerJahreszeitLogik.zeit(am: tag(12, 1)), .winter)
        XCTAssertEqual(ZimmerJahreszeitLogik.zeit(am: tag(2, 28)), .winter)
        XCTAssertEqual(ZimmerJahreszeitLogik.name(.herbst), "Herbst")
    }

    func testGeburtstagskindNurAmTagSelbst() {
        XCTAssertEqual(ZimmerGeburtstagLogik.geburtstagskind(am: tag(2, 27)), .ahmed)
        XCTAssertEqual(ZimmerGeburtstagLogik.geburtstagskind(am: tag(6, 6)), .annika)
        XCTAssertNil(ZimmerGeburtstagLogik.geburtstagskind(am: tag(2, 26)))
        XCTAssertNil(ZimmerGeburtstagLogik.geburtstagskind(am: tag(10, 9)))
    }

    func testDreiWuensche() {
        let w = ZimmerGeburtstagLogik.wuensche(fuer: .annika)
        XCTAssertEqual(w.count, 3)
        XCTAssertTrue(w[0].contains(Person.annika.name))
    }

    func testTraumTextVorrangStimmungDannWunsch() {
        XCTAssertEqual(ZimmerTraumLogik.text(stimmung: .verliebt, wunsch: "Strand"), Gefuehl.verliebt.name)
        XCTAssertEqual(ZimmerTraumLogik.text(stimmung: nil, wunsch: "  Strand  "), "Strand")
        XCTAssertNil(ZimmerTraumLogik.text(stimmung: nil, wunsch: "  "))
        XCTAssertNil(ZimmerTraumLogik.text(stimmung: nil, wunsch: nil))
        XCTAssertEqual(ZimmerTraumLogik.text(stimmung: nil, wunsch: String(repeating: "a", count: 90))?.count, 40)
        XCTAssertEqual(ZimmerTraumLogik.schluessel(.ahmed), "zimmer.wunsch.ahmed")
    }

    func testOutfitFarbeVergleich() {
        var a = FigurAussehen(), b = FigurAussehen()
        XCTAssertTrue(ZimmerOutfitLogik.gleich(a, b))
        a.oberteilfarbeHex = "ff00aa"
        XCTAssertFalse(ZimmerOutfitLogik.gleich(a, b))
        b.oberteilfarbeHex = "FF00AA"
        XCTAssertTrue(ZimmerOutfitLogik.gleich(a, b))
        XCTAssertEqual(ZimmerOutfitLogik.tagesSchluessel("2026-10-09"), "lovea.zimmer.outfit.2026-10-09")
    }

    func testRadioLink() {
        let id = "4uLU6hMCjMI75M1A2tKUQC"
        let erwartet = "https://open.spotify.com/track/" + id
        XCTAssertEqual(ZimmerRadioLogik.link(aus: "https://open.spotify.com/track/\(id)?si=abc"), erwartet)
        XCTAssertEqual(ZimmerRadioLogik.link(aus: "spotify:track:\(id)"), erwartet)
        XCTAssertNil(ZimmerRadioLogik.link(aus: "  "))
        XCTAssertNil(ZimmerRadioLogik.link(aus: "https://example.com/x"))
    }

    func testRegen() {
        XCTAssertTrue(ZimmerRegenLogik.regnet(code: 63))
        XCTAssertFalse(ZimmerRegenLogik.regnet(code: 0))
        XCTAssertFalse(ZimmerRegenLogik.regnet(code: nil))
    }
}
