import XCTest
@testable import Lovea

/// p69 (48): a partner on an old build never sends `app.kann`, so Ahmed gets a notice that his change of her
/// figure (`figur.aussehenFuer`, p68) does not reach her phone yet.
@MainActor
final class AppKannTests: XCTestCase {
    func testKeineListeHeisstAlteApp() {
        XCTAssertFalse(AppKann.versteht(nil, AppKann.figurFuerPartner))
        XCTAssertNotNil(AppKann.updateHinweis(.annika, kann: nil))
    }

    func testListeMitDerFaehigkeitGibtKeinenHinweis() {
        XCTAssertTrue(AppKann.versteht([AppKann.figurFuerPartner], AppKann.figurFuerPartner))
        XCTAssertNil(AppKann.updateHinweis(.annika, kann: [AppKann.figurFuerPartner]))
    }

    func testListeOhneDieFaehigkeitGibtHinweis() {
        XCTAssertFalse(AppKann.versteht(["etwas.anderes"], AppKann.figurFuerPartner))
        XCTAssertNotNil(AppKann.updateHinweis(.annika, kann: ["etwas.anderes"]))
        XCTAssertNotNil(AppKann.updateHinweis(.annika, kann: []))
    }

    func testHinweisNenntDieAlteAppUndDasUpdate() throws {
        let text = try XCTUnwrap(AppKann.updateHinweis(.annika, kann: nil))
        XCTAssertTrue(text.contains("Annika"))
        XCTAssertTrue(text.contains("updaten"))
    }

    /// The art string is what old builds ignore: it must be the one the figure model reads.
    func testFaehigkeitIstDieArtDieDasFigurenModellLiest() throws {
        let a = FigurAussehen.standard(for: .annika)
        let op = Op.neu(AppKann.figurFuerPartner, AussehenFuerD(fuer: .annika, aussehen: a), von: .ahmed)
        XCTAssertEqual(FigurenModell.aussehenZiel(op)?.person, .annika)
    }

    func testEigeneListeEnthaeltDieFigurFaehigkeit() {
        XCTAssertTrue(AppKann.eigene.contains(AppKann.figurFuerPartner))
    }

    func testListeUeberlebtDenWegDurchEineOp() throws {
        let op = Op.neu(AppKann.art, AppKann.Liste(kann: AppKann.eigene), von: .annika)
        XCTAssertEqual(op.art, "app.kann")
        XCTAssertEqual(op.daten(AppKann.Liste.self)?.kann, AppKann.eigene)
    }
}
