import XCTest
@testable import Lovea

/// Echoes of own ops refold only when they change the order (no 100-300 ms jolt after each save).
/// Convergence of the real folds lives in `KalenderModellTests` (I-1).
final class SeqFaltungTests: XCTestCase {
    private func op(_ id: String, seq: Int?) -> Op {
        Op(id: id, seq: seq, art: "liste.setzen", von: .ahmed, zeit: Date(), d: Data("{}".utf8))
    }

    func testEchoInOrderDoesNotRefold() {
        var faltung = SeqFaltung()
        XCTAssertEqual(faltung.aufnehmen([op("b", seq: 10)])?.map(\.id), ["b"])
        XCTAssertEqual(faltung.aufnehmen([op("a", seq: nil)])?.map(\.id), ["a"])
        XCTAssertEqual(faltung.aufnehmen([op("a", seq: 11)])?.map(\.id), [], "oldest open op confirmed on top keeps its place")
        XCTAssertEqual(faltung.aufnehmen([op("c", seq: 12)])?.map(\.id), ["c"])
    }

    func testOutOfOrderEchoRefolds() {
        var faltung = SeqFaltung()
        _ = faltung.aufnehmen([op("a", seq: nil)])
        XCTAssertNil(faltung.aufnehmen([op("b", seq: 10)]), "confirmed op below an open one")
        XCTAssertNil(faltung.aufnehmen([op("a", seq: 9)]), "echo below a known seq")
        XCTAssertEqual(faltung.sortiert.map(\.id), ["a", "b"])
    }

    func testEchoOfNewerOpenOpRefolds() {
        var faltung = SeqFaltung()
        _ = faltung.aufnehmen([op("a", seq: nil), op("c", seq: nil)])
        XCTAssertNil(faltung.aufnehmen([op("c", seq: 5)]), "c now sorts before the still open a")
        XCTAssertEqual(faltung.sortiert.map(\.id), ["c", "a"])
        XCTAssertEqual(faltung.aufnehmen([op("a", seq: 6)])?.map(\.id), [])
    }
}
