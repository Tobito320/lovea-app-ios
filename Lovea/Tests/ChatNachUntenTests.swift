import SwiftUI
import XCTest
@testable import Lovea

/// p66: the round "down" arrow in the open chat. Logic is a pure struct (the list itself is private
/// and not testable); the render board is the visual proof.
@MainActor
final class ChatNachUntenTests: XCTestCase {
    func testAmEndeKeinPfeil() {
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: true)
        XCTAssertFalse(pfeil.sichtbar)
        XCTAssertEqual(pfeil.neu, 0)
    }

    func testNachZiehenAmEndeKeinPfeil() {
        // Ahmed 09.10.: after the first drag the arrow stayed up at the very bottom.
        var pfeil = ChatNachUnten()
        pfeil.nutzerZog()
        pfeil.lage(amEnde: false)
        pfeil.lage(amEnde: true)
        XCTAssertFalse(pfeil.sichtbar)
    }

    func testBeimOeffnenKeinFlackern() {
        // First layout pass can report "not at the end" before the bottom anchor settled.
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: false)
        XCTAssertFalse(pfeil.sichtbar)
    }

    func testNachAmEndeUndHochscrollenSichtbar() {
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: true)
        pfeil.lage(amEnde: false)
        XCTAssertTrue(pfeil.sichtbar)
    }

    func testNutzerZiehtOhneEndeGesehenZeigtPfeil() {
        // Opened at an old message (search / jump), the user scrolls: the arrow is allowed.
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: false)
        pfeil.nutzerZog()
        XCTAssertTrue(pfeil.sichtbar)
    }

    func testNeueNachrichtenZaehlenNurWeitOben() {
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: true)
        pfeil.eingetroffen(vomPartner: 2)
        XCTAssertEqual(pfeil.neu, 0, "at the end the list follows, nothing to count")
        pfeil.lage(amEnde: false)
        pfeil.eingetroffen(vomPartner: 1)
        pfeil.eingetroffen(vomPartner: 2)
        XCTAssertEqual(pfeil.neu, 3)
    }

    func testEigeneNachrichtenZaehlenNicht() {
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: true)
        pfeil.lage(amEnde: false)
        pfeil.eingetroffen(vomPartner: 0)
        XCTAssertEqual(pfeil.neu, 0)
    }

    func testZurueckAmEndeSetztZaehlerZurueck() {
        var pfeil = ChatNachUnten()
        pfeil.lage(amEnde: true)
        pfeil.lage(amEnde: false)
        pfeil.eingetroffen(vomPartner: 4)
        pfeil.lage(amEnde: true)
        XCTAssertFalse(pfeil.sichtbar)
        XCTAssertEqual(pfeil.neu, 0)
        pfeil.lage(amEnde: false)
        XCTAssertEqual(pfeil.neu, 0, "the count starts fresh after a visit to the end")
    }

    func testPlakettenText() {
        XCTAssertNil(ChatNachUnten.plakette(0))
        XCTAssertEqual(ChatNachUnten.plakette(1), "1")
        XCTAssertEqual(ChatNachUnten.plakette(99), "99")
        XCTAssertEqual(ChatNachUnten.plakette(100), "99+")
        XCTAssertEqual(ChatNachUnten.plakette(1_000), "99+")
    }

    func testNeueAmListenendeZaehlen() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        func n(_ id: String, _ von: Person, system: Bool = false) -> ChatModell.Nachricht {
            var m = ChatModell.Nachricht(id: id, von: von, zeit: t0, text: "x")
            if system { m.system = "hat in Aufnahmen gespeichert" }
            return m
        }
        let neu = [n("1", .annika), n("2", .ahmed), n("3", .annika, system: true), n("4", .annika)]
        XCTAssertEqual(ChatNachUnten.vomPartner(neu, ich: .ahmed), 2, "own and grey system rows do not count")
    }

    func testPfeilRenderGalerie() {
        let zellen: [(titel: String, ansicht: AnyView)] = [0, 3, 12, 150].map { anzahl in
            (titel: ChatNachUnten.plakette(anzahl).map { "Plakette \($0)" } ?? "ohne Plakette", ansicht: AnyView(
                ChatNachUntenKnopf(neu: anzahl, aktion: {})
                    .padding(24)
                    .background(Color(uiColor: .systemGroupedBackground))
            ))
        }
        RenderTafel.speichern("chat-pfeil", spalten: 4, zellen: zellen)
    }
}
