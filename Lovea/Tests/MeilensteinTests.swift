import XCTest
@testable import Lovea

final class MeilensteinTests: XCTestCase {
    func testZweiMonateAmZwoelftenTag() {
        let s = Meilenstein.naechster(heute: "2026-10-08")
        XCTAssertEqual(s.titel, "2 Monate")
        XCTAssertEqual(s.tage, 18)
        XCTAssertEqual(s.fortschritt, 12.0 / 30.0, accuracy: 0.0001)
    }

    func testErsterMonatAbStart() {
        let s = Meilenstein.naechster(heute: "2026-08-26")
        XCTAssertEqual(s.titel, "1 Monat")
        XCTAssertEqual(s.tage, 31)
        XCTAssertEqual(s.fortschritt, 0)
    }

    func testAmMeilensteinTagGiltDerNaechste() {
        let s = Meilenstein.naechster(heute: "2026-09-26")
        XCTAssertEqual(s.titel, "2 Monate")
        XCTAssertEqual(s.fortschritt, 0)
    }

    func testNachElfMonatenKommtEinJahrDannJahre() {
        XCTAssertEqual(Meilenstein.naechster(heute: "2027-08-01").titel, "1 Jahr")
        XCTAssertEqual(Meilenstein.naechster(heute: "2027-08-26").titel, "2 Jahre")
    }

    func testVorDemStart() {
        let s = Meilenstein.naechster(heute: "2026-08-20")
        XCTAssertEqual(s.titel, "1 Monat")
        XCTAssertEqual(s.fortschritt, 0)
    }

    func testText() {
        XCTAssertEqual(Meilenstein.Stand(titel: "2 Monate", tage: 18, fortschritt: 0.4).text, "noch 18 Tage bis 2 Monate")
        XCTAssertEqual(Meilenstein.Stand(titel: "2 Monate", tage: 1, fortschritt: 0.9).text, "noch 1 Tag bis 2 Monate")
    }
}
