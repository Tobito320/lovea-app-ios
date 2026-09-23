import XCTest
@testable import Lovea

final class BesitzLogikTests: XCTestCase {

    private let katalog: [String: Int] = ["socken": 150, "gucci-tasche": 4000]
    private func preis(_ id: String) -> Int? { katalog[id] }

    func testKaufWirdVomKontostandDesKaeufersAbgezogen() {
        let kauf = BesitzLogik.Kauf(seq: 1, id: "k1", von: .ahmed, artikel: "socken", fuer: .ahmed)
        let ergebnis = BesitzLogik.auswerten([kauf], verdient: [.ahmed: 200], preis: preis)
        XCTAssertTrue(ergebnis.besitzt("socken", .ahmed))
        XCTAssertTrue(ergebnis.abgelehnt.isEmpty)
    }

    func testUnbekannterArtikelWirdAbgelehnt() {
        let kauf = BesitzLogik.Kauf(seq: 1, id: "k1", von: .ahmed, artikel: "unbekannt", fuer: .ahmed)
        let ergebnis = BesitzLogik.auswerten([kauf], verdient: [.ahmed: 100_000], preis: preis)
        XCTAssertTrue(ergebnis.abgelehnt.contains("k1"))
        XCTAssertFalse(ergebnis.besitzt("unbekannt", .ahmed))
    }

    func testKaufDerDenStandUnterNullBraechteWirdAbgelehnt() {
        let kauf = BesitzLogik.Kauf(seq: 1, id: "k1", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let ergebnis = BesitzLogik.auswerten([kauf], verdient: [.ahmed: 3999], preis: preis)
        XCTAssertTrue(ergebnis.abgelehnt.contains("k1"))
        XCTAssertFalse(ergebnis.besitzt("gucci-tasche", .ahmed))
    }

    func testGeschenkGehoertDemEmpfaengerDerKaeuferZahlt() {
        let kauf = BesitzLogik.Kauf(seq: 1, id: "k1", von: .ahmed, artikel: "socken", fuer: .annika)
        let ergebnis = BesitzLogik.auswerten([kauf], verdient: [.ahmed: 200, .annika: 0], preis: preis)
        XCTAssertTrue(ergebnis.besitzt("socken", .annika))
        XCTAssertFalse(ergebnis.besitzt("socken", .ahmed), "Ahmed zahlt, aber besitzt es nicht selbst")
    }

    func testDoppelteOpIdZaehltNurEinmal() {
        let kauf = BesitzLogik.Kauf(seq: 1, id: "k1", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let dupliziert = BesitzLogik.Kauf(seq: 2, id: "k1", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let ergebnis = BesitzLogik.auswerten([kauf, dupliziert], verdient: [.ahmed: 4000], preis: preis)
        XCTAssertTrue(ergebnis.besitzt("gucci-tasche", .ahmed))
        // Hätte die doppelte id ein zweites Mal abgebucht, wäre 4000 (2*4000) hier abgelehnt.
        XCTAssertTrue(ergebnis.abgelehnt.isEmpty)
    }

    /// Review-Fokus 3: zwei Geräte derselben Person kaufen "gleichzeitig" — beide zusammen reichen
    /// nicht, der frühere `seq` gewinnt, deterministisch auf beiden Geräten.
    func testGleichzeitigeKaeufeDerselbenPersonFruehererSeqGewinnt() {
        let zuerst = BesitzLogik.Kauf(seq: 5, id: "a", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let danach = BesitzLogik.Kauf(seq: 6, id: "b", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        // Nur 4000 Punkte insgesamt, aber zwei Taschen zu je 4000 gleichzeitig eingereicht, absichtlich in
        // vertauschter Reihenfolge im Array, um zu zeigen, dass nach `seq` sortiert wird, nicht nach Ankunft.
        let ergebnis = BesitzLogik.auswerten([danach, zuerst], verdient: [.ahmed: 4000], preis: preis)
        XCTAssertTrue(ergebnis.abgelehnt.contains("b"), "der später gesendete Kauf wird abgelehnt")
        XCTAssertFalse(ergebnis.abgelehnt.contains("a"))
    }

    func testUnbestaetigteOpsWerdenNachDenBestaetigtenVerarbeitet() {
        let unbestaetigt = BesitzLogik.Kauf(seq: nil, id: "b", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let bestaetigt = BesitzLogik.Kauf(seq: 1, id: "a", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let ergebnis = BesitzLogik.auswerten([unbestaetigt, bestaetigt], verdient: [.ahmed: 4000], preis: preis)
        XCTAssertTrue(ergebnis.besitzt("gucci-tasche", .ahmed), "\"a\" (bestätigt) gewinnt")
        XCTAssertTrue(ergebnis.abgelehnt.contains("b"))
    }
}
