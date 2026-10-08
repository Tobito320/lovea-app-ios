import XCTest
@testable import Lovea

final class PostLogikTests: XCTestCase {
    private func n(_ id: String, von: Person = .annika, zeit: TimeInterval = 100, text: String? = nil, medien: [ChatModell.MedienEintrag] = []) -> ChatModell.Nachricht {
        var x = ChatModell.Nachricht(id: id, von: von, zeit: Date(timeIntervalSince1970: zeit))
        x.text = text
        x.medien = medien
        return x
    }

    private let stimme = ChatModell.MedienEintrag(id: "m", typ: "sprache", breite: 0, hoehe: 0, dauer: 3, pegel: nil)
    private let foto = ChatModell.MedienEintrag(id: "f", typ: "foto", breite: 1, hoehe: 1, dauer: nil, pegel: nil)

    func testBriefErkennung() {
        XCTAssertTrue(PostLogik.istBrief(n("a", text: PostLogik.briefKopf + "Hallo")))
        XCTAssertTrue(PostLogik.istBrief(n("b", text: String(repeating: "x", count: 140))))
        XCTAssertFalse(PostLogik.istBrief(n("c", text: "kurz")))
        XCTAssertFalse(PostLogik.istBrief(n("d", text: PostLogik.briefKopf + "mit Foto", medien: [foto])))
        XCTAssertFalse(PostLogik.istBrief(n("e")))
    }

    func testSprachpostNurSprache() {
        XCTAssertTrue(PostLogik.istSprachpost(n("a", medien: [stimme])))
        XCTAssertFalse(PostLogik.istSprachpost(n("b", medien: [foto])))
    }

    func testNurVomPartner() {
        let alle = [n("a", von: .annika, text: PostLogik.briefKopf + "x"), n("b", von: .ahmed, text: PostLogik.briefKopf + "y"), n("c", von: .annika, medien: [stimme])]
        XCTAssertEqual(PostLogik.briefe(alle, von: .annika).map(\.id), ["a"])
        XCTAssertEqual(PostLogik.sprachpost(alle, von: .annika).map(\.id), ["c"])
    }

    func testNeuNachZeitpunkt() {
        let post = [n("a", zeit: 100), n("b", zeit: 200)]
        XCTAssertEqual(PostLogik.neu(post, seit: Date(timeIntervalSince1970: 0)), 2)
        XCTAssertEqual(PostLogik.neu(post, seit: Date(timeIntervalSince1970: 100)), 1)
        XCTAssertEqual(PostLogik.neu(post, seit: Date(timeIntervalSince1970: 200)), 0)
    }

    func testBriefTextHinUndZurueck() {
        XCTAssertNil(PostLogik.briefText("  \n "))
        let t = PostLogik.briefText(" Hallo ")
        XCTAssertEqual(t, "Brief\n\nHallo")
        XCTAssertEqual(PostLogik.lesetext(n("a", text: t)), "Hallo")
    }
}
