import XCTest
@testable import Lovea

final class AhmedHilfeTests: XCTestCase {
    private var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return k
    }

    /// 2026-10-08 `stunde`:`minute` Berlin time.
    private func zeit(_ stunde: Int, _ minute: Int = 0) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: stunde, minute: minute))!
    }

    private func nachricht(_ id: String, von: Person, _ zeit: Date, system: String? = nil, geloescht: Bool = false) -> ChatModell.Nachricht {
        var n = ChatModell.Nachricht(id: id, von: von, zeit: zeit)
        n.text = "x"
        n.system = system
        n.geloescht = geloescht
        return n
    }

    private func wartet(_ liste: [ChatModell.Nachricht], ich: Person = .ahmed, jetzt: Date) -> String? {
        AhmedHilfe.wartet(auf: liste, ich: ich, jetzt: jetzt, kalender: kalender)?.id
    }

    func testHinweisNachZwanzigMinuten() {
        let liste = [nachricht("a", von: .annika, zeit(14))]
        XCTAssertNil(wartet(liste, jetzt: zeit(14, 19)))
        XCTAssertEqual(wartet(liste, jetzt: zeit(14, 20)), "a")
    }

    func testKeinHinweisNachZwoelfStunden() {
        let liste = [nachricht("a", von: .annika, zeit(8))]
        XCTAssertEqual(wartet(liste, jetzt: zeit(20)), "a")
        XCTAssertNil(wartet(liste, jetzt: zeit(20, 1)))
    }

    func testKeinHinweisWennAhmedZuletztSchrieb() {
        let liste = [nachricht("a", von: .annika, zeit(14)), nachricht("b", von: .ahmed, zeit(14, 5))]
        XCTAssertNil(wartet(liste, jetzt: zeit(15)))
    }

    func testSystemzeilenUndGeloeschtesZaehlenNicht() {
        let liste = [nachricht("a", von: .annika, zeit(14)),
                     nachricht("b", von: .ahmed, zeit(14, 5), geloescht: true),
                     nachricht("c", von: .ahmed, zeit(14, 6), system: "x")]
        XCTAssertEqual(wartet(liste, jetzt: zeit(15)), "a")
    }

    func testNachtsKeinHinweis() {
        let liste = [nachricht("a", von: .annika, zeit(21))]
        XCTAssertEqual(wartet(liste, jetzt: zeit(22, 30)), "a")
        XCTAssertNil(wartet(liste, jetzt: zeit(23)))
    }

    func testNurFuerAhmed() {
        let liste = [nachricht("a", von: .ahmed, zeit(14))]
        XCTAssertNil(wartet(liste, ich: .annika, jetzt: zeit(15)))
        XCTAssertNil(wartet([], jetzt: zeit(15)))
    }

    func testDauerText() {
        XCTAssertEqual(AhmedHilfe.dauerText(35 * 60), "35 Min.")
        XCTAssertEqual(AhmedHilfe.dauerText(2 * 3600 + 120), "2 Std.")
    }
}
