import XCTest
@testable import Lovea

/// Audit #4: `ChatModell` patches/appends instead of re-sorting per batch. Whatever the batching,
/// the order must equal a full sort by (seq, zeit), unconfirmed last.
@MainActor
final class ChatReihenfolgeTests: XCTestCase {

    private let basis = Date(timeIntervalSince1970: 1_790_000_000)

    private func op(_ art: String, _ d: String, von: Person = .ahmed, seq: Int?, t: Double, id: String = UUID().uuidString) -> Op {
        Op(id: id, seq: seq, art: art, von: von, zeit: basis.addingTimeInterval(t), d: Data(d.utf8))
    }

    private func neu(_ id: String, seq: Int?, t: Double, opId: String = UUID().uuidString) -> Op {
        op("nachricht.neu", #"{"id":"\#(id)","text":"\#(id)"}"#, von: .annika, seq: seq, t: t, id: opId)
    }

    /// Out-of-order seqs, an optimistic send and its echo, a mid-list insert, a delete within 5 s,
    /// a `snap.wiederholt` line that moves down, and plain field updates.
    private func ops() -> [Op] {
        [
            neu("m1", seq: 1, t: 0),
            neu("m2", seq: 3, t: 2),
            neu("m3", seq: 2, t: 1),
            neu("m4", seq: nil, t: 3, opId: "m4-op"),
            neu("m4", seq: 5, t: 3, opId: "m4-op"),
            neu("m5", seq: 4, t: 4),
            op("nachricht.reaktion", #"{"id":"m1","emoji":"herz"}"#, seq: 10, t: 10),
            neu("m6", seq: 6, t: 5),
            op("nachricht.geloescht", #"{"id":"m6"}"#, seq: 11, t: 7),
            op("snap.wiederholt", #"{"id":"m2","anzahl":1}"#, von: .annika, seq: 7, t: 7),
            neu("m7", seq: 8, t: 8),
            op("snap.wiederholt", #"{"id":"m2","anzahl":2}"#, von: .annika, seq: 9, t: 9),
            neu("m8", seq: nil, t: 12),
            op("stern", #"{"id":"m3","an":true}"#, seq: 12, t: 13),
        ]
    }

    private func zustand(_ modell: ChatModell) -> [String] {
        modell.nachrichten.map { "\($0.id)|\($0.seq ?? -1)|\($0.reaktionen.count)|\($0.gesternt.count)" }
    }

    func testOrderIsTheSameForAnyBatching() {
        let einzeln = ChatModell(registrieren: false)
        for op in ops() { einzeln.anwenden([op]) }

        let alle = ChatModell(registrieren: false)
        alle.anwenden(ops())

        let dreier = ChatModell(registrieren: false)
        let liste = ops()
        for start in stride(from: 0, to: liste.count, by: 3) {
            dreier.anwenden(Array(liste[start..<min(start + 3, liste.count)]))
        }

        let erwartet = ["m1", "m3", "m2", "m5", "m4", "m7", "wiederholt-m2-annika", "m8"]
        XCTAssertEqual(einzeln.nachrichten.map(\.id), erwartet)
        XCTAssertEqual(alle.nachrichten.map(\.id), erwartet)
        XCTAssertEqual(dreier.nachrichten.map(\.id), erwartet)
        XCTAssertEqual(zustand(einzeln), zustand(alle))
        XCTAssertEqual(zustand(dreier), zustand(alle))
        XCTAssertEqual(einzeln.nachricht("m1")?.reaktionen[.ahmed], "herz")
        XCTAssertEqual(einzeln.nachrichten.first { $0.id == "m3" }?.gesternt, [.ahmed])
    }

    /// Field updates and lookups keep working after a mid-list insert moved every later index.
    func testUpdateAfterMidListInsertHitsTheRightRow() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([neu("a", seq: 1, t: 0), neu("c", seq: 3, t: 2)])
        modell.anwenden([neu("b", seq: 2, t: 1)])
        modell.anwenden([op("nachricht.reaktion", #"{"id":"c","emoji":"x"}"#, seq: 4, t: 3)])
        XCTAssertEqual(modell.nachrichten.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(modell.nachrichten[2].reaktionen[.ahmed], "x")
        XCTAssertTrue(modell.nachrichten[1].reaktionen.isEmpty)
    }
}
