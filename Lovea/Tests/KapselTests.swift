import XCTest
@testable import Lovea

/// Z-27.2: "ist die Zeitkapsel schon offen" — Kalendertag-Vergleich in Europe/Berlin, pure logic.
/// `@MainActor`: constructs `ChatModell.Nachricht`/`KapselInfo`, nested in the `@MainActor` `ChatModell`.
@MainActor
final class KapselTests: XCTestCase {
    func testOffenGenauAmTag() {
        let heute23UhrBerlin = Datum.datum("2026-12-24").addingTimeInterval(23 * 3600) // 23:00 desselben Tages
        XCTAssertFalse(ChatModell.verschlossen(oeffnetAm: "2026-12-24", jetzt: heute23UhrBerlin))
    }

    func testVerschlossenAmVortag() {
        let vortag = Datum.datum("2026-12-23").addingTimeInterval(23 * 3600 + 59 * 60) // 23:59 des Vortags
        XCTAssertTrue(ChatModell.verschlossen(oeffnetAm: "2026-12-24", jetzt: vortag))
    }

    func testOffenNachDemTag() {
        let einWocheSpaeter = Datum.datum("2026-12-31")
        XCTAssertFalse(ChatModell.verschlossen(oeffnetAm: "2026-12-24", jetzt: einWocheSpaeter))
    }

    func testNachrichtOhneKapselIstNieVerschlossen() {
        let n = ChatModell.Nachricht(id: "m1", von: .ahmed, zeit: Date(), text: "hallo")
        XCTAssertFalse(ChatModell.verschlossen(n))
    }

    func testNachrichtMitKapselFolgtDemDatum() {
        var n = ChatModell.Nachricht(id: "m2", von: .ahmed, zeit: Date(), text: "geheim")
        n.kapsel = ChatModell.KapselInfo(oeffnetAm: "2026-12-24")
        XCTAssertTrue(ChatModell.verschlossen(n, jetzt: Datum.datum("2026-12-01")))
        XCTAssertFalse(ChatModell.verschlossen(n, jetzt: Datum.datum("2026-12-24")))
    }

    // Review-Fokus 1 (Europe/Berlin, auch über die Zeitumstellung 25.10.2026): der Tagesvergleich
    // hängt nur am Kalendertag, die Zeitumstellung selbst darf ihn nicht verschieben.
    func testUeberDieZeitumstellungHinweg() {
        let morgensAmTag = Datum.datum("2026-10-26").addingTimeInterval(1 * 3600) // 01:00 CET
        XCTAssertFalse(ChatModell.verschlossen(oeffnetAm: "2026-10-26", jetzt: morgensAmTag))
        let abendsDavor = Datum.datum("2026-10-25").addingTimeInterval(23 * 3600)
        XCTAssertTrue(ChatModell.verschlossen(oeffnetAm: "2026-10-26", jetzt: abendsDavor))
    }
}
