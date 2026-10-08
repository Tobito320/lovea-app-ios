import XCTest
@testable import Lovea

/// Schnittplan vor dem Senden eines Snap-Videos: reine Rechnung, kein Export.
final class SnapSchnittTests: XCTestCase {
    private func bereich(_ von: Double, _ bis: Double) -> SnapSchnitt.Bereich { .init(von: von, bis: bis) }

    func testNeuerPlanBehaeltAllesUndIstUnveraendert() {
        let plan = SnapSchnitt(dauer: 10)
        XCTAssertEqual(plan.behalten, [bereich(0, 10)])
        XCTAssertEqual(plan.ergebnisDauer, 10, accuracy: 0.0001)
        XCTAssertFalse(plan.veraendert)
        XCTAssertFalse(plan.schnittNoetig)
        XCTAssertTrue(plan.gueltig)
    }

    func testKuerzenSchneidetVornUndHinten() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertTrue(plan.kuerzen(anfang: 2, ende: 8))
        XCTAssertEqual(plan.behalten, [bereich(2, 8)])
        XCTAssertEqual(plan.ergebnisDauer, 6, accuracy: 0.0001)
        XCTAssertTrue(plan.schnittNoetig)
    }

    func testKuerzenKlemmtAufVideoGrenzen() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertTrue(plan.kuerzen(anfang: -3, ende: 99))
        XCTAssertEqual(plan.behalten, [bereich(0, 10)])
        XCTAssertFalse(plan.veraendert)
    }

    func testKuerzenLehntZuKurzenRestAbUndAendertNichts() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertFalse(plan.kuerzen(anfang: 5, ende: 5.2))
        XCTAssertFalse(plan.kuerzen(anfang: 7, ende: 3))
        XCTAssertEqual(plan.behalten, [bereich(0, 10)])
    }

    func testEntfernenTeiltDasVideoInZweiTeile() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertTrue(plan.entfernen(von: 3, bis: 5))
        XCTAssertEqual(plan.behalten, [bereich(0, 3), bereich(5, 10)])
        XCTAssertEqual(plan.ergebnisDauer, 8, accuracy: 0.0001)
    }

    func testEntfernenMitVertauschtenGrenzenGleichBehandelt() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertTrue(plan.entfernen(von: 5, bis: 3))
        XCTAssertEqual(plan.behalten, [bereich(0, 3), bereich(5, 10)])
    }

    func testUeberlappendeEntfernteBereicheWerdenEiner() {
        var plan = SnapSchnitt(dauer: 20)
        XCTAssertTrue(plan.entfernen(von: 2, bis: 6))
        XCTAssertTrue(plan.entfernen(von: 5, bis: 9))
        XCTAssertEqual(plan.entfernt, [bereich(2, 9)])
        XCTAssertEqual(plan.behalten, [bereich(0, 2), bereich(9, 20)])
    }

    func testMehrereEntfernteBereicheBleibenSortiert() {
        var plan = SnapSchnitt(dauer: 20)
        XCTAssertTrue(plan.entfernen(von: 12, bis: 14))
        XCTAssertTrue(plan.entfernen(von: 2, bis: 4))
        XCTAssertEqual(plan.behalten, [bereich(0, 2), bereich(4, 12), bereich(14, 20)])
        XCTAssertEqual(plan.ergebnisDauer, 16, accuracy: 0.0001)
    }

    func testEntfernenAmAnfangUndEndeLaesstKeinenLeerenTeilUebrig() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertTrue(plan.entfernen(von: 0, bis: 3))
        XCTAssertTrue(plan.entfernen(von: 8, bis: 10))
        XCTAssertEqual(plan.behalten, [bereich(3, 8)])
    }

    func testZuKurzerEntfernBereichIstKeinSchnitt() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertFalse(plan.entfernen(von: 4, bis: 4.05))
        XCTAssertTrue(plan.entfernt.isEmpty)
        XCTAssertFalse(plan.veraendert)
    }

    func testEntfernenLehntAbWennZuWenigUebrigBleibt() {
        var plan = SnapSchnitt(dauer: 10)
        XCTAssertFalse(plan.entfernen(von: 0, bis: 9.8))
        XCTAssertTrue(plan.entfernt.isEmpty)
        XCTAssertEqual(plan.behalten, [bereich(0, 10)])
    }

    func testEntfernenRueckgaengigStelltTeilWiederHer() {
        var plan = SnapSchnitt(dauer: 10)
        plan.entfernen(von: 3, bis: 5)
        plan.entfernenRueckgaengig(bei: 0)
        XCTAssertEqual(plan.behalten, [bereich(0, 10)])
        plan.entfernenRueckgaengig(bei: 4) // ungültiger Index: kein Absturz
        XCTAssertFalse(plan.veraendert)
    }

    func testEntfernterBereichAusserhalbDesGekuerztenFensters() {
        var plan = SnapSchnitt(dauer: 20)
        plan.entfernen(von: 1, bis: 3)
        plan.kuerzen(anfang: 5, ende: 15)
        XCTAssertEqual(plan.behalten, [bereich(5, 15)])
    }

    func testEntfernterBereichHintenUeberDasEndeHinaus() {
        var plan = SnapSchnitt(dauer: 20)
        plan.entfernen(von: 12, bis: 18)
        plan.kuerzen(anfang: 0, ende: 15)
        XCTAssertEqual(plan.behalten, [bereich(0, 12)])
    }

    func testNurStummAendertKeinenSchnittAberVeraendert() {
        var plan = SnapSchnitt(dauer: 10)
        plan.stumm = true
        XCTAssertTrue(plan.veraendert)
        XCTAssertFalse(plan.schnittNoetig)
        XCTAssertEqual(plan.behalten, [bereich(0, 10)])
    }

    func testNullLaengeIstUngueltig() {
        let plan = SnapSchnitt(dauer: 0)
        XCTAssertFalse(plan.gueltig)
        XCTAssertTrue(plan.behalten.isEmpty)
    }

    func testZeitText() {
        XCTAssertEqual(SnapSchnitt.zeit(7), "0:07")
        XCTAssertEqual(SnapSchnitt.zeit(65.4), "1:05")
        XCTAssertEqual(SnapSchnitt.zeit(-2), "0:00")
    }
}
