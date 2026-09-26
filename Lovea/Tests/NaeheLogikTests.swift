import XCTest
@testable import Lovea

final class NaeheLogikTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_800_000_000)

    private func nachrichten(_ n: Int, vorMinuten: Double = 10) -> [Date] {
        (0..<n).map { _ in jetzt.addingTimeInterval(-vorMinuten * 60) }
    }

    func testStufenGrenzen() {
        XCTAssertEqual(NaeheLogik.stufe(nachrichten: nachrichten(5), jetzt: jetzt), 0)
        XCTAssertEqual(NaeheLogik.stufe(nachrichten: nachrichten(6), jetzt: jetzt), 1)
        XCTAssertEqual(NaeheLogik.stufe(nachrichten: nachrichten(20), jetzt: jetzt), 1)
        XCTAssertEqual(NaeheLogik.stufe(nachrichten: nachrichten(21), jetzt: jetzt), 2)
        XCTAssertEqual(NaeheLogik.stufe(nachrichten: nachrichten(51), jetzt: jetzt), 3)
    }

    func testAlteNachrichtenZaehlenNicht() {
        XCTAssertEqual(NaeheLogik.stufe(nachrichten: nachrichten(60, vorMinuten: 130), jetzt: jetzt), 0)
    }

    func testZusammenGleicherOrt() {
        XCTAssertTrue(NaeheLogik.zusammen(a: nil, b: nil, ortA: "Zuhause", ortB: "Zuhause"))
    }

    func testZusammenNah() {
        let a = (lat: 51.5, lon: 7.46)
        let b = (lat: 51.5005, lon: 7.46)   // about 56 m north
        XCTAssertTrue(NaeheLogik.zusammen(a: a, b: b, ortA: nil, ortB: nil))
        let c = (lat: 51.502, lon: 7.46)    // about 222 m
        XCTAssertFalse(NaeheLogik.zusammen(a: a, b: c, ortA: nil, ortB: nil))
    }

    func testHandySchauen() {
        XCTAssertFalse(NaeheLogik.handySchauen(stufe: 0, jetzt: jetzt))
        let bei2 = Date(timeIntervalSince1970: 25 * 4 + 2)
        XCTAssertTrue(NaeheLogik.handySchauen(stufe: 1, jetzt: bei2))
        let bei10 = Date(timeIntervalSince1970: 25 * 4 + 10)
        XCTAssertFalse(NaeheLogik.handySchauen(stufe: 1, jetzt: bei10))
        let stufe2Bei2 = Date(timeIntervalSince1970: 15 * 3 + 2)
        XCTAssertTrue(NaeheLogik.handySchauen(stufe: 2, jetzt: stufe2Bei2))
    }
}
