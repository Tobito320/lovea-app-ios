import XCTest
@testable import Lovea

/// Z-32.4: the time capsule is gone. A Runde-2 `nachricht.neu` with `kapsel` (even one still
/// "locked" far in the future) is an ordinary, visible and searchable message.
@MainActor
final class KapselAlsNormalTests: XCTestCase {
    func testKapselInDerZukunftIstSichtbarUndDurchsuchbar() {
        let modell = ChatModell(registrieren: false)
        let d = Data(#"{"id":"k1","text":"Unser Geheimnis","kapsel":{"oeffnetAm":"2099-01-01"}}"#.utf8)
        modell.anwenden([Op(id: "o1", seq: 1, art: "nachricht.neu", von: .annika, zeit: Date(), d: d)])

        XCTAssertEqual(modell.nachrichten.map(\.id), ["k1"])
        XCTAssertEqual(modell.nachrichten.first?.text, "Unser Geheimnis")
        XCTAssertEqual(modell.suchen("geheimnis"), ["k1"])
        XCTAssertEqual(ChatVorschau.inhalt(modell.nachrichten[0]), "Unser Geheimnis")
        XCTAssertEqual(modell.ungelesen(fuer: .ahmed), 1)
    }
}
