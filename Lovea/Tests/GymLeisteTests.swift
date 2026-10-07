import XCTest
@testable import Lovea

/// R7: reine Entscheidung für die Gym-Leiste (`GymLeisteLogik.zustand`), ohne Gerät oder Modelle.
final class GymLeisteTests: XCTestCase {
    func testSeitlichWischenDocktDieLeisteAlsKleinenKnopf() {
        XCTAssertEqual(GymLeisteLogik.seite(wisch: CGSize(width: -90, height: 10)), "links")
        XCTAssertEqual(GymLeisteLogik.seite(wisch: CGSize(width: 90, height: -5)), "rechts")
        XCTAssertNil(GymLeisteLogik.seite(wisch: CGSize(width: 30, height: 0)), "zu kurz")
        XCTAssertNil(GymLeisteLogik.seite(wisch: CGSize(width: 80, height: 120)), "eher senkrecht")
    }

    func testWederNochNichtWeggewischtIstAus() {
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: false, laufendeSeit: nil, weggewischt: false), .aus)
    }

    func testImGymOhneLaufendeEinheitZeigtVorschlag() {
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: true, laufendeSeit: nil, weggewischt: false), .vorschlag)
    }

    func testImGymAberWeggewischtIstAus() {
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: true, laufendeSeit: nil, weggewischt: true), .aus)
    }

    func testGeradeBeendetImGymZeigtFortsetzen() {
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: true, laufendeSeit: nil, weggewischt: false, fortsetzbar: true), .fortsetzen)
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: true, laufendeSeit: nil, weggewischt: true, fortsetzbar: true), .aus)
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: false, laufendeSeit: nil, weggewischt: false, fortsetzbar: true), .aus)
    }

    func testLaufendeEinheitGewinntImmer() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: true, laufendeSeit: start, weggewischt: false), .laeuft(seit: start))
        // Auch weggewischt oder nicht mehr im Gym: eine laufende Einheit zeigt die Uhr weiter.
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: true, laufendeSeit: start, weggewischt: true), .laeuft(seit: start))
        XCTAssertEqual(GymLeisteLogik.zustand(atGym: false, laufendeSeit: start, weggewischt: false), .laeuft(seit: start))
    }
}
