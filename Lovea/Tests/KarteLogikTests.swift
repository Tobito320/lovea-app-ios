import XCTest
@testable import Lovea

/// Z-41: pure map logic - weather and charging extras, the map figure state, label texts, the night
/// look and the "Unsere Orte" dedupe.
@MainActor
final class KarteLogikTests: XCTestCase {
    // MARK: - Extras

    func testRainDrizzleShowersAndThunderGiveUmbrella() {
        for code in [51, 56, 61, 65, 80, 82, 95, 99] {
            XCTAssertEqual(KarteLogik.extras(wetterCode: code, temperatur: 12, tag: true, laedt: false), [.schirm], "code \(code)")
        }
    }

    func testClearSkyGivesSunglassesOnlyByDay() {
        XCTAssertEqual(KarteLogik.extras(wetterCode: 0, temperatur: 20, tag: true, laedt: false), [.sonnenbrille])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 1, temperatur: 20, tag: true, laedt: false), [.sonnenbrille])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 0, temperatur: 20, tag: false, laedt: false), [])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 3, temperatur: 20, tag: true, laedt: false), [])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 45, temperatur: 20, tag: true, laedt: false), [])
    }

    func testBelowFiveDegreesGivesHatAndScarf() {
        XCTAssertEqual(KarteLogik.extras(wetterCode: 3, temperatur: 4.9, tag: true, laedt: false), [.muetzeSchal])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 3, temperatur: 5, tag: true, laedt: false), [])
    }

    func testSnowGivesSnowflakes() {
        for code in [71, 73, 75, 77, 85, 86] {
            XCTAssertTrue(KarteLogik.extras(wetterCode: code, temperatur: 6, tag: true, laedt: false).contains(.schneeflocken), "code \(code)")
        }
    }

    func testCombinationsAreAllowed() {
        XCTAssertEqual(KarteLogik.extras(wetterCode: 73, temperatur: -2, tag: true, laedt: false), [.schneeflocken, .muetzeSchal])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 0, temperatur: 2, tag: true, laedt: false), [.sonnenbrille, .muetzeSchal])
        XCTAssertEqual(KarteLogik.extras(wetterCode: 61, temperatur: 3, tag: true, laedt: true), [.schirm, .muetzeSchal, .handyKabel])
    }

    func testChargingWithoutWeatherYet() {
        XCTAssertEqual(KarteLogik.extras(wetterCode: nil, temperatur: nil, tag: false, laedt: true), [.handyKabel])
        XCTAssertEqual(KarteLogik.extras(wetterCode: nil, temperatur: nil, tag: false, laedt: false), [])
    }

    // MARK: - Map figure state

    func testFreshMovementWinsEvenWhileThePartnersAppIsClosed() {
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .offline, bewegung: "laeuft", ortKategorie: nil, sekundenAlt: 60), .laeuft)
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .imChat, bewegung: "rennt", ortKategorie: "zuhause", sekundenAlt: 10), .rennt)
    }

    func testStaleOrUnknownMovementIsIgnored() {
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .offline, bewegung: "laeuft", ortKategorie: nil, sekundenAlt: 301), .ruhig)
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .offline, bewegung: "laeuft", ortKategorie: nil, sekundenAlt: .infinity), .ruhig)
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .ruhig, bewegung: "fliegt", ortKategorie: nil, sekundenAlt: 5), .ruhig)
    }

    func testOfflinePartnerStandsAtTheirSavedPlace() {
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .offline, bewegung: nil, ortKategorie: "gym", sekundenAlt: 7200), .gym)
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .offline, bewegung: nil, ortKategorie: "sonstiges", sekundenAlt: 7200), .ruhig)
    }

    func testGestureAndLiveStateStay() {
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .kuss, bewegung: "laeuft", ortKategorie: nil, sekundenAlt: 5), .kuss)
        XCTAssertEqual(KarteLogik.kartenZustand(anzeige: .laedt, bewegung: nil, ortKategorie: "zuhause", sekundenAlt: 5), .laedt)
    }

    // MARK: - Texts

    func testAgeLabel() {
        XCTAssertNil(KarteLogik.alterText(sekunden: 30))
        XCTAssertNil(KarteLogik.alterText(sekunden: -120)) // fix from the future (clock skew)
        XCTAssertNil(KarteLogik.alterText(sekunden: .infinity))
        XCTAssertEqual(KarteLogik.alterText(sekunden: 5 * 60), "vor 5 min")
        XCTAssertEqual(KarteLogik.alterText(sekunden: 59 * 60 + 59), "vor 59 min")
        XCTAssertEqual(KarteLogik.alterText(sekunden: 2 * 3600 + 10), "vor 2 h")
        XCTAssertEqual(KarteLogik.alterText(sekunden: 30 * 3600), "vor 1 Tag")
        XCTAssertEqual(KarteLogik.alterText(sekunden: 3 * 86_400), "vor 3 Tagen")
    }

    func testBatteryTexts() {
        XCTAssertEqual(KarteLogik.akkuText(0.62), "62 %")
        XCTAssertEqual(KarteLogik.akkuText(1), "100 %")
        XCTAssertEqual(KarteLogik.akkuSymbol(0.05, laedt: false), "battery.0")
        XCTAssertEqual(KarteLogik.akkuSymbol(0.62, laedt: false), "battery.50")
        XCTAssertEqual(KarteLogik.akkuSymbol(0.95, laedt: false), "battery.100")
        XCTAssertEqual(KarteLogik.akkuSymbol(0.05, laedt: true), "battery.100.bolt")
    }

    func testDistanceText() {
        XCTAssertEqual(KarteLogik.entfernungText(20), "bei dir")
        XCTAssertEqual(KarteLogik.entfernungText(347), "350 m entfernt")
        XCTAssertEqual(KarteLogik.entfernungText(3249), "3,2 km entfernt")
        XCTAssertEqual(KarteLogik.entfernungText(12_345), "12 km entfernt")
    }

    // MARK: - Night look

    /// 25.10.2026 is the switch back from summer time - the Berlin hour still decides.
    func testNightIsEightPmToSevenAmBerlin() {
        XCTAssertFalse(KarteLogik.istNacht(berlin(19, 59)))
        XCTAssertTrue(KarteLogik.istNacht(berlin(20, 0)))
        XCTAssertTrue(KarteLogik.istNacht(berlin(2, 30)))
        XCTAssertTrue(KarteLogik.istNacht(berlin(6, 59)))
        XCTAssertFalse(KarteLogik.istNacht(berlin(7, 0)))
    }

    private func berlin(_ stunde: Int, _ minute: Int) -> Date {
        Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: stunde, minute: minute))!
    }

    // MARK: - Unsere Orte

    func testStaysAtTheSamePlaceCollapseToTheNewest() {
        let alt = GemeinsamerOrt(id: "alt", lat: 50.9400, lon: 6.1000, datum: "2026-09-01")
        let neu = GemeinsamerOrt(id: "neu", lat: 50.9405, lon: 6.1003, datum: "2026-09-20") // ~60 m away
        let woanders = GemeinsamerOrt(id: "woanders", lat: 50.9700, lon: 6.1500, datum: "2026-09-10")
        XCTAssertEqual(KarteLogik.unsereOrte([alt, woanders, neu]).map(\.id), ["neu", "woanders"])
        XCTAssertEqual(KarteLogik.unsereOrte([]).count, 0)
    }

    /// Akku: motion flicker asks for at most one extra GPS fix per 45 s; driving starts always get one.
    func testExtraFixThrottle() {
        let t = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(Standort.extraFixErlaubt(letzter: .distantPast, jetzt: t, dringend: false))
        XCTAssertFalse(Standort.extraFixErlaubt(letzter: t.addingTimeInterval(-10), jetzt: t, dringend: false))
        XCTAssertTrue(Standort.extraFixErlaubt(letzter: t.addingTimeInterval(-10), jetzt: t, dringend: true))
        XCTAssertTrue(Standort.extraFixErlaubt(letzter: t.addingTimeInterval(-45), jetzt: t, dringend: false))
    }
}
