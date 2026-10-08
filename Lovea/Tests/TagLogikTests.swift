import XCTest
@testable import Lovea

/// "Ahmeds Tag": Momente -> Zeitleiste. Tage nach Berliner Kalender, alle Zeiten fest vorgegeben.
final class TagLogikTests: XCTestCase {
    private let kal = Calendar.berlin

    private func zeit(_ tag: Int, _ h: Int, _ m: Int = 0) -> Date {
        kal.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: h, minute: m))!
    }

    private func moment(_ id: String, _ zeit: Date, _ sorte: TagMoment.Sorte = .herz) -> TagMoment {
        TagMoment(id: id, zeit: zeit, sorte: sorte, text: id)
    }

    private func leiste(_ roh: [TagMoment], tag: Int = 8) -> [TagMoment] {
        TagLogik.zeitleiste(roh, tag: zeit(tag, 12), kalender: kal)
    }

    func testLeererTagHatKeineMomente() {
        XCTAssertTrue(leiste([]).isEmpty)
    }

    func testMomenteSindNachZeitSortiert() {
        let roh = [moment("h", zeit(8, 20)), moment("s", zeit(8, 7), .schlaf), moment("f", zeit(8, 13), .foto)]
        XCTAssertEqual(leiste(roh).map(\.sorte), [.schlaf, .foto, .herz])
    }

    func testTagesgrenzeIstMitternachtInBerlin() {
        let roh = [moment("k", zeit(8, 23, 59)), moment("d", zeit(9, 0, 1))]
        XCTAssertEqual(leiste(roh, tag: 8).map(\.id), ["k"])
        XCTAssertEqual(leiste(roh, tag: 9).map(\.id), ["d"])
    }

    func testGleicheSorteKurzHintereinanderWirdZusammengefasst() {
        let roh = (0..<14).map { moment("h\($0)", zeit(8, 20, $0)) }
        let l = leiste(roh)
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l[0].anzahl, 14)
        XCTAssertEqual(l[0].anzeige, "14× h0")
    }

    func testSortenWerdenNichtVermischtUndFensterTrennt() {
        let roh = [moment("f", zeit(8, 12), .foto), moment("s", zeit(8, 12, 1), .snap),
                   moment("h1", zeit(8, 9)), moment("h2", zeit(8, 15))]
        XCTAssertEqual(leiste(roh).map(\.anzahl), [1, 1, 1, 1])
    }

    func testNichtGruppierbareSortenBleibenEinzeln() {
        let roh = [moment("a", zeit(8, 10), .gym), moment("b", zeit(8, 10, 5), .gym)]
        XCTAssertEqual(leiste(roh).count, 2)
    }
}
