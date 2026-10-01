import XCTest
@testable import Lovea

/// Build 78: `erfassen` zeigt nur dann einen Bericht, wenn tatsächlich etwas auf einen Absturz
/// hindeutet (vorherCrash-Flag ODER eine Absturz-Datei) — ein sauberer Start zeigt nichts.
final class AbsturzBerichtTests: XCTestCase {
    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: StartProtokoll.datei("start-vorher.txt"))
        AbsturzFaenger.vorherigenBerichtLoeschen()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: StartProtokoll.datei("start-vorher.txt"))
        AbsturzFaenger.vorherigenBerichtLoeschen()
        super.tearDown()
    }

    func testOhneHinweisKeinBericht() {
        XCTAssertNil(AbsturzBericht.erfassen(vorherCrash: false, altesStufenFeld: nil))
    }

    func testVorherCrashErzeugtBerichtMitBreadcrumbs() {
        try? Data("123 test.stufe [main] mem=500MB".utf8).write(to: StartProtokoll.datei("start-vorher.txt"))
        let bericht = AbsturzBericht.erfassen(vorherCrash: true, altesStufenFeld: "gym.abgleichen.start")
        XCTAssertNotNil(bericht)
        XCTAssertTrue(bericht?.text.contains("test.stufe") ?? false)
        XCTAssertTrue(bericht?.text.contains("gym.abgleichen.start") ?? false)
    }
}
