import XCTest
@testable import Lovea

/// p61: the room's pieces (what is chosen, what is saved, what the shop sells) and the cat's rules.
final class ZimmerWahlTests: XCTestCase {
    private func zimmerArtikel() throws -> [ShopArtikel] {
        let bundle = Bundle(for: FigurenModell.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "katalog", withExtension: "json")
                ?? bundle.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop")
        )
        return try JSONDecoder().decode([ShopArtikel].self, from: try Data(contentsOf: url)).filter { $0.kategorie == "zimmer" }
    }

    func testKatalogUndZimmerTeileSindDieselbenZehn() throws {
        let artikel = try zimmerArtikel()
        XCTAssertEqual(Set(artikel.map(\.id)), Set(ZimmerTeile.alle.keys))
        XCTAssertEqual(artikel.count, ZimmerTeile.alle.count)
        XCTAssertTrue(artikel.allSatisfy { $0.geschlecht == "n" && !$0.exklusiv && $0.preis > 0 && $0.id.hasPrefix("zimmer.") })
        for (id, teil) in ZimmerTeile.alle { XCTAssertEqual(teil.id, id) }
    }

    func testWenigeTeileProArt() {
        let proArt = Dictionary(grouping: ZimmerTeile.alle.values, by: \.art).mapValues(\.count)
        for art in [ZimmerArt.wand, .teppich, .bettwaesche] { XCTAssertTrue((2...3).contains(proArt[art] ?? 0), "\(art)") }
        XCTAssertEqual(proArt[.lampe], 2)
    }

    func testJedeArtHatEinenStandardMitDerRichtigenArt() {
        for art in ZimmerArt.allCases {
            XCTAssertEqual(ZimmerTeile.standard[art]?.art, art)
            XCTAssertEqual(ZimmerWahl.standard.teil(art), ZimmerTeile.standard[art])
            XCTAssertNil(ZimmerWahl.standard.eigenes(art))
        }
    }

    func testEinrichtenErsetztDasTeilDerselbenArt() {
        var w = ZimmerWahl.standard.einrichten("zimmer.wand-rose")
        XCTAssertTrue(w.traegt("zimmer.wand-rose"))
        w = w.einrichten("zimmer.wand-salbei")
        XCTAssertEqual(w.teil(.wand).id, "zimmer.wand-salbei")
        XCTAssertFalse(w.traegt("zimmer.wand-rose"))
        XCTAssertEqual(w.teil(.lampe).id, "standard.lampe", "andere Arten bleiben")
        w = w.einrichten("zimmer.lampe-rattan")
        XCTAssertEqual(w.teil(.wand).id, "zimmer.wand-salbei")
        XCTAssertEqual(w.eigenes(.lampe)?.id, "zimmer.lampe-rattan")
    }

    func testUnbekanntesAendertNichts() {
        let w = ZimmerWahl.standard.einrichten("zimmer.wand-rose")
        XCTAssertEqual(w.einrichten("zimmer.gibts-nicht"), w)
        XCTAssertEqual(w.einrichten("tier.katze-schwarz"), w)
    }

    func testWegraeumenNurWasGetragenWird() {
        let w = ZimmerWahl.standard.einrichten("zimmer.teppich-herz")
        XCTAssertEqual(w.wegraeumen("zimmer.teppich-wolke"), w, "ein anderes Teil bleibt liegen")
        let leer = w.wegraeumen("zimmer.teppich-herz")
        XCTAssertEqual(leer, .standard)
        XCTAssertEqual(leer.teil(.teppich).id, "standard.teppich")
    }

    func testSpeichernUndLesenGehtHinUndZurueck() {
        let w = ZimmerWahl.standard.einrichten("zimmer.wand-himmel").einrichten("zimmer.bett-herzen").einrichten("zimmer.lampe-laterne")
        XCTAssertEqual(ZimmerWahl(json: w.json), w)
        XCTAssertEqual(ZimmerWahl(json: ZimmerWahl.standard.json), .standard)
        XCTAssertEqual(ZimmerWahl(json: nil), .standard)
    }

    func testBeschaedigtesFaelltAufDenStandard() {
        let kaputt: JSONValue = .object([
            "wand": .string("zimmer.lampe-rattan"),
            "lampe": .string("zimmer.gibts-nicht"),
            "boden": .string("zimmer.wand-rose"),
            "teppich": .number(3),
            "bettwaesche": .string("zimmer.bett-salbei"),
        ])
        let w = ZimmerWahl(json: kaputt)
        XCTAssertEqual(w.teil(.wand).id, "standard.wand", "Teil der falschen Art")
        XCTAssertEqual(w.teil(.lampe).id, "standard.lampe")
        XCTAssertEqual(w.teil(.teppich).id, "standard.teppich")
        XCTAssertEqual(w.teil(.bettwaesche).id, "zimmer.bett-salbei", "Gültiges bleibt")
        XCTAssertEqual(ZimmerWahl(json: .string("quatsch")), .standard)
    }

    func testDasZimmerGehoertBeiden() {
        var besitz = BesitzLogik.Ergebnis()
        besitz.besitz[.annika] = ["zimmer.wand-rose"]
        XCTAssertTrue(ZimmerWahl.gehoert("zimmer.wand-rose", besitz: besitz))
        XCTAssertFalse(ZimmerWahl.gehoert("zimmer.wand-salbei", besitz: besitz))
    }

    func testBettwaescheBehaeltDasBettMusterNurImStandard() {
        XCTAssertNil(ZimmerWahl.standard.eigenes(.bettwaesche))
        XCTAssertNotNil(ZimmerWahl.standard.einrichten("zimmer.bett-salbei").eigenes(.bettwaesche))
    }
}

final class ZimmerKatzeTests: XCTestCase {
    func testAbendUndNachtSchlaeftSieAufDemBett() {
        for zeit in [Tageszeit.abend, .nacht] {
            for platz in Platz.allCases {
                let s = ZimmerKatze.szene(zeit: zeit, annika: platz)
                XCTAssertEqual(s.zustand, .schlaeft, "\(zeit) \(platz)")
                XCTAssertEqual(s.ort, ZimmerKatze.bettOrt)
            }
        }
    }

    func testTagsSchlaeftSieBeiBettUndSofa() {
        for zeit in [Tageszeit.morgen, .tag] {
            for platz in [Platz.bett, .sofa] {
                XCTAssertEqual(ZimmerKatze.szene(zeit: zeit, annika: platz).zustand, .schlaeft)
            }
        }
    }

    func testSieFolgtAnnikaZumFensterUndWillBeiDenBlumenGestreicheltWerden() {
        let fenster = ZimmerKatze.szene(zeit: .tag, annika: .fenster)
        XCTAssertEqual(fenster.zustand, .folgt)
        XCTAssertLessThan(fenster.ort.x, ZuhauseOrte.fuss(.fenster, .annika).x, "links neben Annika")
        XCTAssertTrue(fenster.nachRechts, "schaut zu ihr")
        let blumen = ZimmerKatze.szene(zeit: .morgen, annika: .blumen)
        XCTAssertEqual(blumen.zustand, .will)
        XCTAssertGreaterThan(blumen.ort.x, ZuhauseOrte.fuss(.blumen, .annika).x, "rechts neben Annika")
        XCTAssertFalse(blumen.nachRechts)
        XCTAssertEqual(fenster.ort.y, ZuhauseOrte.fussY)
    }

    func testDieKatzeBleibtImZimmerUndZeigtAmTagAlleDreiZustaende() {
        var zustaende = Set<KatzenZustand>()
        for zeit in Tageszeit.allCases {
            for schritt in ZuhauseAblauf.abfolge(zeit) {
                let s = ZimmerKatze.szene(zeit: zeit, annika: schritt.annika)
                XCTAssertTrue((0...ZuhauseZeichnung.breite).contains(s.ort.x) && (0...ZuhauseZeichnung.hoehe).contains(s.ort.y), "\(zeit) \(schritt.annika)")
                zustaende.insert(s.zustand)
            }
        }
        XCTAssertEqual(zustaende, [.schlaeft, .folgt, .will])
    }

    func testDieKatzeFolgtNurDemSzenenstandKeineEigeneZeit() {
        // Same input, same picture: it is a pure function of the step, so it moves only when the step does.
        for zeit in Tageszeit.allCases {
            for platz in Platz.allCases {
                XCTAssertEqual(ZimmerKatze.szene(zeit: zeit, annika: platz), ZimmerKatze.szene(zeit: zeit, annika: platz))
            }
        }
    }

    func testDieBlaseNurBeiWachemUngestreicheltemTier() {
        XCTAssertFalse(ZimmerKatze.wuenscht(.schlaeft, gestreichelt: false))
        XCTAssertTrue(ZimmerKatze.wuenscht(.will, gestreichelt: false))
        XCTAssertTrue(ZimmerKatze.wuenscht(.folgt, gestreichelt: false))
        XCTAssertFalse(ZimmerKatze.wuenscht(.will, gestreichelt: true))
    }

    func testWelcheKatze() {
        XCTAssertEqual(ZimmerKatze.id(tiere: [nil, nil]), ZimmerKatze.standardId)
        XCTAssertEqual(ZimmerKatze.id(tiere: ["tier.hund-braun", nil]), ZimmerKatze.standardId)
        XCTAssertEqual(ZimmerKatze.id(tiere: ["tier.hase-weiss", "tier.katze-orange"]), "tier.katze-orange")
        XCTAssertNotNil(haustierKatalog[ZimmerKatze.standardId])
    }
}

final class KatzeLogikTests: XCTestCase {
    private typealias Op3 = (id: String, tag: String, von: Person)

    func testDieOpIdTraegtTagUndPerson() {
        XCTAssertEqual(KatzeLogik.opId(tag: "2026-10-08", von: .ahmed), "katze-2026-10-08-ahmed")
        XCTAssertNotEqual(KatzeLogik.opId(tag: "2026-10-08", von: .ahmed), KatzeLogik.opId(tag: "2026-10-08", von: .annika))
    }

    func testEinmalProTagUndPerson() {
        let id = KatzeLogik.opId(tag: "2026-10-08", von: .ahmed)
        let doppelt: [Op3] = [(id, "2026-10-08", .ahmed), (id, "2026-10-08", .ahmed), (id, "2026-10-08", .ahmed)]
        let e = KatzeLogik.eintraege(doppelt)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.punkte, KatzeLogik.punkte)
        XCTAssertEqual(e.first?.von, .ahmed)
        XCTAssertEqual(e.first?.datum, "2026-10-08")
    }

    func testJederTagUndJedePersonZaehltEinmal() {
        let ops: [Op3] = [
            (KatzeLogik.opId(tag: "2026-10-08", von: .ahmed), "2026-10-08", .ahmed),
            (KatzeLogik.opId(tag: "2026-10-08", von: .annika), "2026-10-08", .annika),
            (KatzeLogik.opId(tag: "2026-10-09", von: .ahmed), "2026-10-09", .ahmed),
        ]
        let e = KatzeLogik.eintraege(ops)
        XCTAssertEqual(e.count, 3)
        XCTAssertEqual(e.reduce(0) { $0 + $1.punkte }, 3 * KatzeLogik.punkte)
    }

    func testEineOpMitFalscherIdZaehltNicht() {
        let e = KatzeLogik.eintraege([("irgendwas", "2026-10-08", .ahmed), (KatzeLogik.opId(tag: "2026-10-07", von: .ahmed), "2026-10-08", .ahmed)])
        XCTAssertTrue(e.isEmpty, "die ID muss zu Tag und Person passen, sonst liessen sich Punkte erfinden")
    }

    func testDieOpHatDieFesteIdUndDenTag() throws {
        let op = KatzeLogik.op(tag: "2026-10-08", von: .annika)
        XCTAssertEqual(op.id, "katze-2026-10-08-annika")
        XCTAssertEqual(op.art, KatzeLogik.art)
        XCTAssertEqual(op.von, .annika)
        XCTAssertEqual(try XCTUnwrap(op.daten(KatzeLogik.D.self)).tag, "2026-10-08")
    }

    func testKleinePunkte() {
        XCTAssertTrue((1...25).contains(KatzeLogik.punkte))
    }
}

/// The model side: stroking twice on one day gives the points once, and the score moves by exactly that.
@MainActor
final class KatzeStreichelnTests: XCTestCase {
    func testZweimalStreichelnGibtDiePunkteEinmal() {
        let vorher = Raum.shared.ich
        Raum.shared.ich = .ahmed
        defer { Raum.shared.ich = vorher }
        let m = PunkteModell.shared
        let start = m.stand[.ahmed] ?? 0
        let erstes = m.katzeStreicheln()
        let nachErstem = m.stand[.ahmed] ?? 0
        let zweites = m.katzeStreicheln()
        let nachZweitem = m.stand[.ahmed] ?? 0
        XCTAssertTrue(m.katzeGestreichelt(.ahmed))
        XCTAssertFalse(m.katzeGestreichelt(.annika), "die Katze der anderen zählt nicht")
        XCTAssertEqual(zweites, 0)
        XCTAssertEqual(nachZweitem, nachErstem)
        XCTAssertEqual(nachErstem - start, erstes, "der Stand steigt um genau die gemeldeten Punkte (0 oder \(KatzeLogik.punkte))")
        XCTAssertTrue([0, KatzeLogik.punkte].contains(erstes))
    }
}
