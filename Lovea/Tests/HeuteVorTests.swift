import XCTest
@testable import Lovea

/// Z-27.3 "Heute vor …": pure selection over candidate messages, Europe/Berlin calendar day.
/// `@MainActor`: constructs `ChatModell.Nachricht` and friends, nested in the `@MainActor` `ChatModell`.
@MainActor
final class HeuteVorTests: XCTestCase {
    private let jetzt = Datum.datum("2026-09-23").addingTimeInterval(15 * 3600) // 23.09.2026, 15:00 Berlin

    func testFindetEinenMonatVorher() {
        let treffer = Calendar.berlin.date(byAdding: .month, value: -1, to: jetzt)!
        let n = ChatModell.Nachricht(id: "m1", von: .ahmed, zeit: treffer, text: "vor einem Monat")
        let ergebnis = HeuteVorLogik.auswahl([n], jetzt: jetzt)
        XCTAssertEqual(ergebnis?.nachricht.id, "m1")
        XCTAssertEqual(ergebnis?.zeitraum, .einMonat)
    }

    func testEinMonatSchlaegtDreiMonateUndEinJahr() {
        let monat = Calendar.berlin.date(byAdding: .month, value: -1, to: jetzt)!
        let dreiMonate = Calendar.berlin.date(byAdding: .month, value: -3, to: jetzt)!
        let n1 = ChatModell.Nachricht(id: "m1", von: .ahmed, zeit: monat, text: "1 Monat")
        let n2 = ChatModell.Nachricht(id: "m2", von: .ahmed, zeit: dreiMonate, text: "3 Monate")
        let ergebnis = HeuteVorLogik.auswahl([n2, n1], jetzt: jetzt)
        XCTAssertEqual(ergebnis?.nachricht.id, "m1")
    }

    func testKeinTrefferOhnePassendenTag() {
        let n = ChatModell.Nachricht(id: "m1", von: .ahmed, zeit: jetzt.addingTimeInterval(-5 * 86_400), text: "vor 5 Tagen")
        XCTAssertNil(HeuteVorLogik.auswahl([n], jetzt: jetzt))
    }

    func testGeloeschteSystemUndSpielZeilenZaehlenNicht() {
        let tag = Calendar.berlin.date(byAdding: .year, value: -1, to: jetzt)!
        let geloescht = ChatModell.Nachricht(id: "g", von: .ahmed, zeit: tag, text: "weg", geloescht: true)
        let system = ChatModell.Nachricht(id: "s", von: .ahmed, zeit: tag, system: "nah")
        XCTAssertNil(HeuteVorLogik.auswahl([geloescht, system], jetzt: jetzt))
    }

    func testUngespeicherterSnapZaehltNicht() {
        let tag = Calendar.berlin.date(byAdding: .year, value: -1, to: jetzt)!
        var n = ChatModell.Nachricht(id: "snap", von: .ahmed, zeit: tag)
        n.snap = ChatModell.SnapInfo(bleibt: false)
        XCTAssertNil(HeuteVorLogik.auswahl([n], jetzt: jetzt))
    }
}
