import XCTest
@testable import Lovea

final class ZieleBefragungTests: XCTestCase {
    func testPoUndHaltung() {
        let r = ZieleLogik.rechnen(ziele: ["po", "haltung"], tageProWoche: 3)
        XCTAssertEqual(r.prio.first, .beine)
        XCTAssertEqual(r.prio.count, 5)
        XCTAssertEqual(r.saetze[.beine], 14)
    }

    func testReihenfolgeOhneDoppelte() {
        let r = ZieleLogik.rechnen(ziele: ["po", "haltung"], tageProWoche: 3)
        XCTAssertEqual(r.prio, [.beine, .bauch, .ruecken, .schulter, .brust])
        XCTAssertEqual(r.saetze[.bauch], 14)
        XCTAssertEqual(r.saetze[.ruecken], 10)
        XCTAssertEqual(r.saetze[.brust], 10)
    }

    func testKeineAuswahlFuelltMitStandard() {
        let r = ZieleLogik.rechnen(ziele: [], tageProWoche: 3)
        XCTAssertEqual(r.prio, [.beine, .ruecken, .schulter, .bauch, .brust])
        XCTAssertEqual(r.saetze[.beine], 14)
        XCTAssertEqual(r.saetze[.ruecken], 14)
        XCTAssertEqual(r.saetze[.schulter], 10)
    }

    func testAlleGruppenHabenEinenSatzwert() {
        let r = ZieleLogik.rechnen(ziele: ["stark"], tageProWoche: 3)
        XCTAssertEqual(r.saetze.count, MuskelGruppe.allCases.count)
        XCTAssertEqual(r.saetze[.nacken], 6)
        XCTAssertEqual(r.saetze[.bizeps], 6)
    }

    func testZweiTage() {
        let r = ZieleLogik.rechnen(ziele: ["straff"], tageProWoche: 2)
        XCTAssertEqual(r.saetze[.beine], 12)
        XCTAssertEqual(r.saetze[.ruecken], 12)
        XCTAssertEqual(r.saetze[.schulter], 10)
    }

    func testFuenfTage() {
        let r = ZieleLogik.rechnen(ziele: ["stark"], tageProWoche: 5)
        XCTAssertEqual(r.saetze[.beine], 16)
        XCTAssertEqual(r.saetze[.ruecken], 16)
        XCTAssertEqual(r.saetze[.brust], 10)
    }

    func testUnbekannteZieleWerdenIgnoriert() {
        let r = ZieleLogik.rechnen(ziele: ["quatsch"], tageProWoche: 4)
        XCTAssertEqual(r.prio, [.beine, .ruecken, .schulter, .bauch, .brust])
    }
}
