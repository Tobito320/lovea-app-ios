import XCTest
@testable import Lovea

/// p47: gekaufte Teile, die aus dem Shop genommen wurden, werden genau einmal erstattet.
final class ShopErstattungTests: XCTestCase {
    /// Katalog nach dem Aufräumen, nur was die Tests brauchen (`ShopKatalog.alle` ist im XCTest leer).
    private let katalog: [String: Int] = ["tasche.guess-tasche": 1600, "tier.hund-braun": 3500]
    private func preis(_ id: String) -> Int? { katalog[id] }

    private func kauf(_ id: String, _ artikel: String, von: Person = .annika, fuer: Person? = nil, seq: Int? = 1, verdient: Int? = 20_000) -> BesitzLogik.Kauf {
        BesitzLogik.Kauf(seq: seq, id: id, von: von, artikel: artikel, fuer: fuer ?? von, zeit: Date(timeIntervalSince1970: 1_790_000_000), verdient: verdient)
    }

    private func erstattungen(_ kaeufe: [BesitzLogik.Kauf]) -> [ShopErstattung.Erstattung] {
        ShopErstattung.erstattungen(kaeufe, verdient: [.ahmed: 20_000, .annika: 20_000], katalogPreis: preis)
    }

    func testEntfernterKaufWirdEinmalMitFesterIdErstattet() {
        let e = erstattungen([kauf("k1", "uhr.rolex")])
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].id, "erstattung-k1")
        XCTAssertEqual(e[0].rueckgabe.punkte, 13_000)
        XCTAssertEqual(e[0].rueckgabe.von, .annika)
        XCTAssertEqual(e[0].rueckgabe.grund, "Erstattung: Rolex Datejust")
        XCTAssertEqual(e[0].kauf.punkte, -13_000)
        XCTAssertEqual(e[0].kauf.punkte + e[0].rueckgabe.punkte, 0, "Verlauf summiert sich auf null")
    }

    func testGleicherKaufMehrfachGeliefertZaehltEinmal() {
        // Op kommt optimistisch (seq nil), dann bestätigt, dann vom zweiten Gerät noch einmal.
        let e = erstattungen([kauf("k1", "uhr.rolex", seq: nil), kauf("k1", "uhr.rolex", seq: 7), kauf("k1", "uhr.rolex", seq: 7)])
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e, erstattungen([kauf("k1", "uhr.rolex", seq: 9)]), "gleiche Zeilen bei jedem Neustart")
    }

    func testReihenfolgeDerLieferungAendertNichts() {
        let a = kauf("k1", "pose.model"), b = kauf("k2", "schmuck.perlenkette", von: .ahmed)
        XCTAssertEqual(erstattungen([a, b]), erstattungen([b, a]))
        XCTAssertEqual(Set(erstattungen([a, b]).map(\.id)), ["erstattung-k1", "erstattung-k2"])
    }

    func testBehaltenesTeilWirdNichtErstattet() {
        XCTAssertTrue(erstattungen([kauf("k1", "tasche.guess-tasche"), kauf("k2", "tier.hund-braun")]).isEmpty)
    }

    func testUnbekanntesTeilOhneAltpreisWirdNichtErstattet() {
        XCTAssertTrue(erstattungen([kauf("k1", "erfunden.xyz")]).isEmpty)
    }

    func testAbgelehnterKaufWirdNichtErstattet() {
        // Beim Kauf nur 500 verdient: schon damals abgelehnt, hat nie etwas gekostet.
        XCTAssertTrue(erstattungen([kauf("k1", "uhr.rolex", verdient: 500)]).isEmpty)
    }

    func testGeschenkGehtAnDenZahler() {
        let e = erstattungen([kauf("k1", "backdrop.neon", von: .ahmed, fuer: .annika)])
        XCTAssertEqual(e.first?.rueckgabe.von, .ahmed)
        XCTAssertEqual(e.first?.rueckgabe.punkte, 1_200)
    }

    func testZweiKaeufeDesselbenTeilsWerdenJeKaufErstattet() {
        let e = erstattungen([kauf("k1", "uhr.guess", seq: 1), kauf("k2", "uhr.guess", seq: 2)])
        XCTAssertEqual(e.map(\.id), ["erstattung-k1", "erstattung-k2"])
    }

    /// Kontostand: nach dem Entfernen zählt der Kauf nicht mehr als ausgegeben, die Punkte sind wieder da.
    func testKontostandIstNachDemEntfernenVoll() {
        let kaeufe = [kauf("k1", "uhr.rolex"), kauf("k2", "tasche.guess-tasche", seq: 2)]
        let vorher = BesitzLogik.auswerten(kaeufe, verdient: [.annika: 20_000], preis: { self.preis($0) ?? ShopErstattung.entfernt[$0]?.preis })
        XCTAssertEqual(vorher.ausgegeben[.annika], 14_600)
        let nachher = BesitzLogik.auswerten(kaeufe, verdient: [.annika: 20_000], preis: preis)
        XCTAssertEqual(nachher.ausgegeben[.annika], 1_600, "Rolex kostet nichts mehr")
        XCTAssertFalse(nachher.besitzt("uhr.rolex", .annika))
        XCTAssertTrue(nachher.besitzt("tasche.guess-tasche", .annika))
    }

    func testTabelleHatKeinenBehaltenenUndKeinenExklusivenArtikel() {
        for id in katalog.keys { XCTAssertNil(ShopErstattung.entfernt[id], id) }
        XCTAssertNil(ShopErstattung.entfernt["uhr.rolex-submariner"], "Challenge-Belohnung wurde nie gekauft")
        XCTAssertGreaterThanOrEqual(ShopErstattung.entfernt.count, 60)
        XCTAssertFalse(ShopErstattung.entfernt.values.contains { $0.preis <= 0 || $0.name.isEmpty })
    }
}
