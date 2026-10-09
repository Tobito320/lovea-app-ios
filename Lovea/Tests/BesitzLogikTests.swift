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

    // MARK: - Final-Review I-1: Urteil hängt nur an Daten bis zum eigenen seq

    private func kauf(_ seq: Int, _ id: String, _ artikel: String, verdient: Int) -> BesitzLogik.Kauf {
        BesitzLogik.Kauf(seq: seq, id: id, von: .annika, artikel: artikel, fuer: .annika, verdient: verdient)
    }

    func testAbgelehnterKaufBleibtAbgelehntWennSpaeterMehrPunkteKommen() {
        // Zwei Geräte, je 4000 verdient, zwei Taschen gleichzeitig: 101 wird abgelehnt.
        let kaeufe = [kauf(100, "a", "gucci-tasche", verdient: 4000), kauf(101, "b", "gucci-tasche", verdient: 4000)]
        XCTAssertEqual(BesitzLogik.auswerten(kaeufe, verdient: [.annika: 4000], preis: preis).abgelehnt, ["b"])
        // Eine Woche später hat sie 5000 mehr verdient — "b" darf NICHT nachträglich durchgehen.
        let spaeter = BesitzLogik.auswerten(kaeufe, verdient: [.annika: 9000], preis: preis)
        XCTAssertEqual(spaeter.abgelehnt, ["b"])
        XCTAssertEqual(spaeter.ausgegeben[.annika], 4000)
    }

    func testAngenommenerKaufUeberlebtSpaeterWenigerPunkte() {
        // Gym abgehakt (+40), mit genau dem Stand gekauft, dann Gym wieder weg: verdient fällt unter den Preis.
        let kaeufe = [kauf(100, "a", "gucci-tasche", verdient: 4000)]
        let ergebnis = BesitzLogik.auswerten(kaeufe, verdient: [.annika: 3960], preis: preis)
        XCTAssertTrue(ergebnis.besitzt("gucci-tasche", .annika), "Gekauftes gehört einem für immer (Spec 4.3)")
        XCTAssertTrue(ergebnis.abgelehnt.isEmpty)
    }

    func testSpaetererKaufFlackertNichtMitDemLebenszeitStand() {
        // Review-Szenario: 100 (4000) ok, 101 (4000) abgelehnt, 150 (Socken, verdient 4150) ok —
        // bei jedem späteren Lebenszeit-Stand dasselbe Ergebnis.
        let kaeufe = [kauf(100, "a", "gucci-tasche", verdient: 4000), kauf(101, "b", "gucci-tasche", verdient: 4000), kauf(150, "c", "socken", verdient: 4150)]
        for lebenszeit in [4150, 8000, 8150, 12_000] {
            let ergebnis = BesitzLogik.auswerten(kaeufe, verdient: [.annika: lebenszeit], preis: preis)
            XCTAssertEqual(ergebnis.abgelehnt, ["b"], "bei \(lebenszeit)")
            XCTAssertTrue(ergebnis.besitzt("socken", .annika), "bei \(lebenszeit)")
        }
    }

    // MARK: - Review-Fokus 3: Flammen und Chat-Themes fallen aus dem Katalog (Erstattung)

    func testWeggefallenerArtikelWirdErstattetUndDieAnderenKaeufeBehaltenIhrUrteil() {
        let vorher: [String: Int] = ["socken": 150, "flamme.herz": 300, "gucci-tasche": 4000]
        let nachher = vorher.filter { $0.key != "flamme.herz" } // Katalog ohne Flammen
        let kaeufe = [
            kauf(10, "flamme", "flamme.herz", verdient: 500),
            kauf(20, "socken", "socken", verdient: 500),         // eigenes verdient: 500 - 300 = 200 >= 150
            kauf(30, "tasche", "gucci-tasche", verdient: 3000),  // nie genug, egal mit oder ohne Flamme
        ]
        let alt = BesitzLogik.auswerten(kaeufe, verdient: [.annika: 5000], preis: { vorher[$0] })
        let neu = BesitzLogik.auswerten(kaeufe, verdient: [.annika: 5000], preis: { nachher[$0] })

        XCTAssertTrue(alt.besitzt("flamme.herz", .annika))
        XCTAssertTrue(neu.abgelehnt.contains("flamme"), "ohne Katalog-Preis abgelehnt = erstattet")
        XCTAssertFalse(neu.besitzt("flamme.herz", .annika))
        XCTAssertTrue(neu.besitzt("socken", .annika), "späterer Kauf mit eigenem verdient bleibt angenommen")
        XCTAssertTrue(neu.abgelehnt.contains("tasche"), "abgelehnt bleibt abgelehnt")
        XCTAssertEqual(alt.abgelehnt, ["tasche"])
        XCTAssertEqual(neu.abgelehnt, ["flamme", "tasche"])
        XCTAssertEqual((alt.ausgegeben[.annika] ?? 0) - (neu.ausgegeben[.annika] ?? 0), 300, "der Kontostand steigt um den Flammen-Preis")
    }

    // MARK: - Final-Review I-5: exklusives Teil für "Gemeinsam Monat"

    func testExklusivesTeilProErreichtemMonat() {
        let exklusiv = ["uhr.rolex-submariner", "tier.vogel-blau"]
        XCTAssertEqual(BesitzLogik.exklusivFrei(erreichteMonate: 0, exklusiv: exklusiv), [])
        XCTAssertEqual(BesitzLogik.exklusivFrei(erreichteMonate: 1, exklusiv: exklusiv), ["uhr.rolex-submariner"])
        XCTAssertEqual(BesitzLogik.exklusivFrei(erreichteMonate: 5, exklusiv: exklusiv), Set(exklusiv))
    }

    func testUnbestaetigteOpsWerdenNachDenBestaetigtenVerarbeitet() {
        let unbestaetigt = BesitzLogik.Kauf(seq: nil, id: "b", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let bestaetigt = BesitzLogik.Kauf(seq: 1, id: "a", von: .ahmed, artikel: "gucci-tasche", fuer: .ahmed)
        let ergebnis = BesitzLogik.auswerten([unbestaetigt, bestaetigt], verdient: [.ahmed: 4000], preis: preis)
        XCTAssertTrue(ergebnis.besitzt("gucci-tasche", .ahmed), "\"a\" (bestätigt) gewinnt")
        XCTAssertTrue(ergebnis.abgelehnt.contains("b"))
    }
}
