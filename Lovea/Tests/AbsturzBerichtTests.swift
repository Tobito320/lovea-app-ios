import XCTest
@testable import Lovea

/// Build 78: `erfassen` zeigt nur dann einen Bericht, wenn tatsächlich etwas auf einen Absturz
/// hindeutet (vorherCrash-Flag ODER eine Absturz-Datei) — ein sauberer Start zeigt nichts.
final class AbsturzBerichtTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "start.vorher")
        AbsturzFaenger.vorherigenBerichtLoeschen()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "start.vorher")
        AbsturzFaenger.vorherigenBerichtLoeschen()
        super.tearDown()
    }

    func testOhneHinweisKeinBericht() {
        XCTAssertNil(AbsturzBericht.erfassen(vorherCrash: false, altesStufenFeld: nil))
    }

    func testVorherCrashErzeugtBerichtMitBreadcrumbs() {
        UserDefaults.standard.set(["123 test.stufe [main] mem=500MB"], forKey: "start.vorher")
        let bericht = AbsturzBericht.erfassen(vorherCrash: true, altesStufenFeld: "gym.abgleichen.start")
        XCTAssertNotNil(bericht)
        XCTAssertTrue(bericht?.text.contains("test.stufe") ?? false)
        XCTAssertTrue(bericht?.text.contains("gym.abgleichen.start") ?? false)
    }
}
