import XCTest
@testable import Lovea

/// `UebungsKatalog.alle` reads `Bundle.main`, which is empty inside XCTest (see `ShopKatalogTests`),
/// so the bundled-data tests load through `Bundle(for:)` an app class.
final class UebungsKatalogTests: XCTestCase {
    private let bundle = Bundle(for: FigurenModell.self)

    private func uebung(_ id: String, _ name: String, _ en: String) -> Uebung {
        Uebung(id: id, name: name, en: en, muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    }

    func testNormalFoldsUmlautsAndSpellings() {
        XCTAssertEqual(UebungsKatalog.normal("Bankdrücken"), "bankdrucken")
        XCTAssertEqual(UebungsKatalog.normal("bankdruecken"), "bankdrucken")
        XCTAssertEqual(UebungsKatalog.normal("Bankdrucken"), "bankdrucken")
        XCTAssertEqual(UebungsKatalog.normal("Schulter-Drücken"), "schulter drucken")
        XCTAssertEqual(UebungsKatalog.normal("Fuß"), "fuss")
    }

    func testSearchFindsBenchPressVariants() {
        let liste = [
            uebung("a", "Schrägbankdrücken mit Kurzhanteln", "dumbbell incline bench press"),
            uebung("b", "Bankdrücken mit Langhantel", "barbell bench press"),
            uebung("c", "Beinstrecker an der Maschine", "lever leg extension"),
        ]
        for text in ["bankdrücken", "bankdruecken", "Bankdrucken"] {
            XCTAssertEqual(UebungsKatalog.suchen(text, in: liste).map(\.id), ["b", "a"], text)
        }
        XCTAssertEqual(Set(UebungsKatalog.suchen("bench press", in: liste).map(\.id)), ["a", "b"])
        XCTAssertEqual(UebungsKatalog.suchen("kurzhantel bank", in: liste).map(\.id), ["a"])
        XCTAssertEqual(UebungsKatalog.suchen("", in: liste).map(\.id), ["b", "c", "a"])
        XCTAssertTrue(UebungsKatalog.suchen("klimmzug", in: liste).isEmpty)
    }

    func testBundledCatalogIsCompleteAndSearchable() throws {
        let alle = UebungsKatalog.laden(bundle)
        XCTAssertGreaterThanOrEqual(alle.count, 1400)
        XCTAssertEqual(Set(alle.map(\.id)).count, alle.count, "doppelte ids")
        XCTAssertFalse(alle.contains { $0.name.isEmpty || $0.koerper.isEmpty }, "leere Namen oder Koerperteile")
        for u in alle.prefix(50) { XCTAssertNotNil(UebungsKatalog.gif(u.id, bundle: bundle), u.id) }
        let bank = UebungsKatalog.suchen("bankdrücken", in: alle)
        XCTAssertGreaterThanOrEqual(bank.count, 5)
        XCTAssertTrue(bank.contains { $0.en == "barbell bench press" })
        XCTAssertFalse(UebungsKatalog.suchen("beinstrecker", in: alle).isEmpty)
        XCTAssertTrue(alle.contains { $0.istCardio })
    }
}
