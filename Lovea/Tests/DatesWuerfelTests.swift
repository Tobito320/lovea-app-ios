import XCTest
@testable import Lovea

final class DatesWuerfelTests: XCTestCase {
    private func idee(_ id: String, erledigt: Bool = false, geloescht: Bool = false) -> DateIdee {
        DateIdee(id: id, titel: "Idee \(id)", kategorie: .essen, erledigt: erledigt, geloescht: geloescht, geaendert: Date(), von: .ahmed)
    }

    func testPoolHatOffeneIdeenUndWuenscheOhneErledigtes() {
        let p = DatesWuerfel.pool(ideen: [idee("a"), idee("b", erledigt: true), idee("c", geloescht: true)],
                                  wuensche: [(id: "w1", text: "Kino")], letzte: [])
        XCTAssertEqual(Set(p.map(\.id)), ["a", "liste-w1"])
        XCTAssertEqual(p.first { $0.id == "liste-w1" }?.text, "Kino")
    }

    func testLetzteGezogeneBleibenDraussen() {
        let p = DatesWuerfel.pool(ideen: [idee("a"), idee("b")], wuensche: [], letzte: ["a"])
        XCTAssertEqual(p.map(\.id), ["b"])
    }

    func testIstAllesKuerzlichDranGewesenKommtTrotzdemEtwas() {
        let p = DatesWuerfel.pool(ideen: [idee("a")], wuensche: [], letzte: ["a"])
        XCTAssertEqual(p.map(\.id), ["a"])
    }

    func testLeerBleibtLeer() {
        XCTAssertTrue(DatesWuerfel.pool(ideen: [], wuensche: [], letzte: []).isEmpty)
    }
}
