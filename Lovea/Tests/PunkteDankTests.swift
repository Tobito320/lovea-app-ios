import XCTest
@testable import Lovea

final class PunkteDankTests: XCTestCase {
    func testJederBekommtGenauEinmal5000() {
        let ops: [(id: String, fuer: Person)] = [(DankLogik.opId(.ahmed), .ahmed), (DankLogik.opId(.annika), .annika)]
        let e = DankLogik.eintraege(ops)
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(e.filter { $0.von == .ahmed }.map(\.punkte), [5000])
        XCTAssertEqual(e.filter { $0.von == .annika }.map(\.punkte), [5000])
    }

    func testZweiGeraeteSendenDieselbeOpZaehltEinmal() {
        let ops: [(id: String, fuer: Person)] = Array(repeating: (DankLogik.opId(.ahmed), Person.ahmed), count: 3)
        let e = DankLogik.eintraege(ops)
        XCTAssertEqual(e.map(\.punkte), [5000])
        XCTAssertEqual(DankLogik.op(fuer: .ahmed, von: .ahmed).id, DankLogik.op(fuer: .ahmed, von: .annika).id)
    }

    func testFremdeIdZaehltNicht() {
        XCTAssertTrue(DankLogik.eintraege([("zufall", .ahmed), (DankLogik.opId(.annika), .ahmed)]).isEmpty)
    }

    func testNichtErneutNachNeuinstallationWennImLog() {
        XCTAssertTrue(DankLogik.fehlende(gebucht: [.ahmed, .annika]).isEmpty)
        XCTAssertEqual(DankLogik.fehlende(gebucht: [.ahmed]), [.annika])
        XCTAssertEqual(DankLogik.fehlende(gebucht: []).count, 2)
    }

    func testLabelDeutschUndOpRoundtrip() {
        XCTAssertEqual(DankLogik.grund, "Danke fürs Aushalten der App-Probleme")
        let op = DankLogik.op(fuer: .annika, von: .ahmed)
        XCTAssertEqual(op.art, DankLogik.art)
        XCTAssertEqual(op.daten(DankLogik.D.self)?.fuer, .annika)
        XCTAssertEqual(op.id, "dank-2026-10-07-annika")
    }
}
