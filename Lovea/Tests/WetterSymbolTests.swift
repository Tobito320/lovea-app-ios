import XCTest
@testable import Lovea

/// Z-27.5: WMO-Wettercode (Open-Meteo) -> SF Symbol, reine Zuordnung.
final class WetterSymbolTests: XCTestCase {
    func testSonneNebelRegenSchneeGewitter() {
        XCTAssertEqual(WetterSymbol.sfSymbol(fuer: 0), "sun.max.fill")
        XCTAssertEqual(WetterSymbol.sfSymbol(fuer: 45), "cloud.fog.fill")
        XCTAssertEqual(WetterSymbol.sfSymbol(fuer: 63), "cloud.rain.fill")
        XCTAssertEqual(WetterSymbol.sfSymbol(fuer: 73), "cloud.snow.fill")
        XCTAssertEqual(WetterSymbol.sfSymbol(fuer: 95), "cloud.bolt.rain.fill")
    }

    func testUnbekannterCodeFaelltAufWolkeZurueck() {
        XCTAssertEqual(WetterSymbol.sfSymbol(fuer: 1234), "cloud.fill")
    }
}
