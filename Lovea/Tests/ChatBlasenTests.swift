import XCTest
@testable import Lovea

/// Z-32.4/Z-33.1: bubble grouping, emoji-only detection and where the long-press bar and menu go.
@MainActor
final class ChatBlasenTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func text(_ id: String, _ von: Person, nach sekunden: TimeInterval) -> ChatModell.Nachricht {
        ChatModell.Nachricht(id: id, von: von, zeit: t0.addingTimeInterval(sekunden), text: "hi")
    }

    func testGruppeGleicherAbsenderInnerhalbVon5Minuten() {
        XCTAssertTrue(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), text("b", .ahmed, nach: 299)))
        XCTAssertFalse(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), text("b", .ahmed, nach: 301)))
        XCTAssertFalse(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), text("b", .annika, nach: 10)))
        var weg = text("c", .ahmed, nach: 20)
        weg.geloescht = true
        XCTAssertFalse(BlasenGruppe.zusammen(text("a", .ahmed, nach: 0), weg), "a caption breaks the group")
    }

    func testLesekopfSitztUnterDerZuletztGelesenenEigenen() {
        let liste = [text("a", .ahmed, nach: 0), text("b", .annika, nach: 5), text("c", .ahmed, nach: 10), text("d", .ahmed, nach: 20)]
        let status = LeseStatus(nachrichten: liste, ich: .ahmed, gelesenBisPartner: t0.addingTimeInterval(12))
        XCTAssertEqual(status.gelesenID, "c")
        XCTAssertEqual(status.offen?.id, "d")
        let nieGelesen = LeseStatus(nachrichten: liste, ich: .ahmed, gelesenBisPartner: nil)
        XCTAssertNil(nieGelesen.gelesenID)
        XCTAssertEqual(nieGelesen.offen?.id, "d")
    }

    func testNurEmoji() {
        XCTAssertTrue(NachrichtBlase.nurEmoji("😂"))
        XCTAssertTrue(NachrichtBlase.nurEmoji("❤️ 😘"))
        XCTAssertFalse(NachrichtBlase.nurEmoji("😂😂😂😂"))
        XCTAssertFalse(NachrichtBlase.nurEmoji("ok 👍"))
        XCTAssertFalse(NachrichtBlase.nurEmoji(""))
    }

    func testLeisteUeberDerBlaseMenueDarunter() {
        let r = CGRect(x: 100, y: 400, width: 200, height: 40)
        let lage = FokusLayout.positionen(rahmen: r, leiste: 56, menue: 200, oben: 50, unten: 800)
        XCTAssertEqual(lage.leisteY, 336)
        XCTAssertEqual(lage.menueY, 448)
    }

    func testUntenGehtDasMenueNachOben() {
        let r = CGRect(x: 100, y: 700, width: 200, height: 40)
        let lage = FokusLayout.positionen(rahmen: r, leiste: 56, menue: 200, oben: 50, unten: 800)
        XCTAssertEqual(lage.leisteY, 636)
        XCTAssertEqual(lage.menueY, 428)
    }

    func testObenGehtDieLeisteUnterDieBlase() {
        let r = CGRect(x: 100, y: 60, width: 200, height: 40)
        let lage = FokusLayout.positionen(rahmen: r, leiste: 56, menue: 200, oben: 50, unten: 800)
        XCTAssertEqual(lage.leisteY, 108)
        XCTAssertEqual(lage.menueY, 172)
    }

    func testLeisteBleibtAufDemBildschirm() {
        let rechts = CGRect(x: 300, y: 400, width: 80, height: 40)
        XCTAssertEqual(FokusLayout.mitteX(rahmen: rechts, breite: 344, rechts: true, flaeche: 390), 208)
        let ganzRechts = CGRect(x: 350, y: 400, width: 40, height: 40)
        XCTAssertEqual(FokusLayout.mitteX(rahmen: ganzRechts, breite: 344, rechts: true, flaeche: 390), 210, "8 pt margin")
        let links = CGRect(x: 10, y: 400, width: 80, height: 40)
        XCTAssertEqual(FokusLayout.mitteX(rahmen: links, breite: 250, rechts: false, flaeche: 390), 135)
    }
}
