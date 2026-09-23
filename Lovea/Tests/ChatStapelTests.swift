import XCTest
@testable import Lovea

/// Block 18: photo-stack grouping and the Chats-row preview (pure logic).
@MainActor
final class ChatStapelTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func foto(_ id: String, von: Person = .ahmed, nach sekunden: TimeInterval, antwortAuf: String? = nil) -> ChatModell.Nachricht {
        ChatModell.Nachricht(
            id: id, von: von, zeit: t0.addingTimeInterval(sekunden),
            medien: [ChatModell.MedienEintrag(id: "m-\(id)", typ: "foto", breite: 3, hoehe: 4, dauer: nil, pegel: nil)],
            antwortAuf: antwortAuf
        )
    }

    private func text(_ id: String, von: Person = .ahmed, nach sekunden: TimeInterval, _ inhalt: String = "hi") -> ChatModell.Nachricht {
        ChatModell.Nachricht(id: id, von: von, zeit: t0.addingTimeInterval(sekunden), text: inhalt)
    }

    func testFotosInnerhalbVon60SekundenWerdenEinStapel() {
        let gruppen = ChatStapel.gruppieren([foto("a", nach: 0), foto("b", nach: 20), foto("c", nach: 75)])
        XCTAssertEqual(gruppen.map { $0.nachrichten.map(\.id) }, [["a", "b", "c"]], "jeder Abstand ≤ 60 s zum vorherigen")
    }

    func testLueckeAnderePersonUndTextTrennenStapel() {
        let gruppen = ChatStapel.gruppieren([
            foto("a", nach: 0), foto("b", nach: 61), // gap too long
            foto("c", von: .annika, nach: 70),        // other person
            text("d", nach: 80), foto("e", nach: 90),
        ])
        XCTAssertEqual(gruppen.map { $0.nachrichten.map(\.id) }, [["a"], ["b"], ["c"], ["d"], ["e"]])
    }

    func testAntwortStartetStapelTrittAberKeinemBei() {
        let gruppen = ChatStapel.gruppieren([foto("a", nach: 0), foto("b", nach: 5, antwortAuf: "x"), foto("c", nach: 10)])
        XCTAssertEqual(gruppen.map { $0.nachrichten.map(\.id) }, [["a"], ["b", "c"]])
    }

    func testSnapUndGeloeschtesFotoStapelnNicht() {
        var snap = foto("s", nach: 0)
        snap.snap = ChatModell.SnapInfo(bleibt: false)
        var weg = foto("w", nach: 10)
        weg.geloescht = true
        XCTAssertFalse(ChatStapel.istBild(snap))
        XCTAssertFalse(ChatStapel.istBild(weg))
        XCTAssertEqual(ChatStapel.gruppieren([snap, foto("a", nach: 5), weg]).count, 3)
    }

    func testVorschauTipptSchlaegtAlles() {
        let zeile = ChatVorschau.zeile(nachrichten: [text("a", nach: 0)], ich: .ahmed, gelesenVonPartner: nil, gelesenVonMir: nil, partnerTippt: true)
        XCTAssertEqual(zeile.text, "Tippt …")
        XCTAssertTrue(zeile.neu)
    }

    func testVorschauNeuerSnapUndUngelesenerText() {
        var snap = foto("s", von: .annika, nach: 0)
        snap.snap = ChatModell.SnapInfo(bleibt: false)
        let neuerSnap = ChatVorschau.zeile(nachrichten: [snap], ich: .ahmed, gelesenVonPartner: nil, gelesenVonMir: nil, partnerTippt: false)
        XCTAssertEqual(neuerSnap, .init(symbol: "square.fill", text: "Neuer Snap", neu: true))

        let nachricht = text("t", von: .annika, nach: 10, "Hallo")
        let ungelesen = ChatVorschau.zeile(nachrichten: [nachricht], ich: .ahmed, gelesenVonPartner: nil, gelesenVonMir: t0, partnerTippt: false)
        XCTAssertEqual(ungelesen, .init(symbol: "bubble.left.fill", text: "Hallo", neu: true))
        let gelesen = ChatVorschau.zeile(nachrichten: [nachricht], ich: .ahmed, gelesenVonPartner: nil, gelesenVonMir: t0.addingTimeInterval(10), partnerTippt: false)
        XCTAssertFalse(gelesen.neu)
    }

    func testVorschauEigeneNachrichtZugestelltOderGeoeffnet() {
        let eigene = text("t", nach: 10, "Hi")
        let zugestellt = ChatVorschau.zeile(nachrichten: [eigene], ich: .ahmed, gelesenVonPartner: t0, gelesenVonMir: nil, partnerTippt: false)
        XCTAssertEqual(zugestellt.text, "Zugestellt · Hi")
        let geoeffnet = ChatVorschau.zeile(nachrichten: [eigene], ich: .ahmed, gelesenVonPartner: t0.addingTimeInterval(10), gelesenVonMir: nil, partnerTippt: false)
        XCTAssertEqual(geoeffnet.text, "Geöffnet · Hi")
    }
}
