import XCTest
@testable import Lovea

/// Block 18: photo-stack grouping and the one-line preview (pure logic).
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

    func testVorschauZeigtTextOderArt() {
        XCTAssertEqual(ChatVorschau.inhalt(text("t", nach: 0, "Hallo")), "Hallo")
        XCTAssertEqual(ChatVorschau.inhalt(foto("f", nach: 0)), "Foto")
    }
}
