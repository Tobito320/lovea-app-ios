import XCTest
@testable import Lovea

/// p63: der Date-Würfel auf dem Tisch.
@MainActor
final class ZimmerWuerfelTests: XCTestCase {
    private func speicher() -> DateSpeicher {
        DateSpeicher(ich: { .ahmed }, senden: { _ in }, merker: UserDefaults(suiteName: "zimmer-wuerfel-" + UUID().uuidString)!)
    }

    func testJederWurfIstEineIdeeSeinerGruppe() {
        for zahl in 0..<200 {
            let w = ZimmerWuerfel.wurf(nil, zahl: zahl)
            XCTAssertTrue(w.gruppe.ideen.contains(w.text), "\(zahl)")
        }
    }

    func testMitGruppeBleibtDerWurfInDerGruppe() {
        for g in WuerfelGruppe.allCases {
            for zahl in 0..<50 { XCTAssertEqual(ZimmerWuerfel.wurf(g, zahl: zahl).gruppe, g) }
        }
    }

    func testOhneGruppeKommenAlleVier() {
        XCTAssertEqual(Set((0..<8).map { ZimmerWuerfel.wurf(nil, zahl: $0).gruppe }), Set(WuerfelGruppe.allCases))
    }

    func testLetzterWurfKommtNichtNochEinmal() {
        for g in WuerfelGruppe.allCases {
            for zahl in 0..<20 {
                let erster = ZimmerWuerfel.wurf(g, zahl: zahl)
                XCTAssertNotEqual(ZimmerWuerfel.wurf(g, zahl: zahl, ausser: erster.text).text, erster.text)
            }
        }
    }

    func testJedeGruppeHatGenugVerschiedeneIdeen() {
        let alle = WuerfelGruppe.allCases.flatMap(\.ideen)
        XCTAssertEqual(Set(alle).count, alle.count)
        for g in WuerfelGruppe.allCases { XCTAssertGreaterThanOrEqual(g.ideen.count, 6, g.titel) }
    }

    func testAugenVonEinsBisSechs() {
        XCTAssertEqual(Set((0..<60).map(ZimmerWuerfel.augen)), Set(1...6))
        for n in 1...6 { XCTAssertEqual(ZimmerWuerfelZeichnung.punkte(n).count, n) }
    }

    func testUebernehmenLegtDieIdeeInDerPassendenKategorieAn() {
        let s = speicher()
        let w = WuerfelWurf(gruppe: .draussen, text: "Picknick im Park")
        XCTAssertTrue(ZimmerWuerfel.uebernehmen(w, in: s))
        XCTAssertEqual(s.ideen.map(\.titel), ["Picknick im Park"])
        XCTAssertEqual(s.ideen.first?.kategorie, .draussen)
        XCTAssertFalse(s.ideen.first?.erledigt ?? true)
    }

    func testUebernehmenDoppeltLegtNichtNochEinmalAn() {
        let s = speicher()
        XCTAssertTrue(ZimmerWuerfel.uebernehmen(WuerfelWurf(gruppe: .drinnen, text: "Alte Fotos anschauen"), in: s))
        XCTAssertFalse(ZimmerWuerfel.uebernehmen(WuerfelWurf(gruppe: .drinnen, text: "alte fotos anschauen"), in: s))
        XCTAssertEqual(s.ideen.count, 1)
    }

    func testGruppenKategorien() {
        XCTAssertEqual(WuerfelGruppe.allCases.map(\.kategorie), [.zuhause, .draussen, .aktivitaet, .besonders])
    }
}
