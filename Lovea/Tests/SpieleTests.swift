import XCTest
@testable import Lovea

final class SpieleLogikTests: XCTestCase {

    // MARK: - Zufall

    func testSeedIstFnv1aUndStabil() {
        XCTAssertEqual(Zufall.seed(""), 0xCBF2_9CE4_8422_2325)
        XCTAssertEqual(Zufall.seed("a"), 0xAF63_DC4C_8601_EC8C)
    }

    func testGemischtIstDeterministischUndEinePermutation() {
        let werte = Array(0..<20)
        var a = Zufall("spiel-1#0"), b = Zufall("spiel-1#0"), c = Zufall("spiel-2#0")
        let x = a.gemischt(werte), y = b.gemischt(werte), z = c.gemischt(werte)
        XCTAssertEqual(x, y, "gleicher Seed, gleiche Reihenfolge auf beiden Geräten")
        XCTAssertNotEqual(x, z)
        XCTAssertEqual(x.sorted(), werte)
    }

    // MARK: - Duell.wort

    func testDuellWortGleicheWahlGiltImmer() {
        let v = ["Katze", "Pizza", "Mond"]
        for seed: UInt64 in 0..<10 {
            XCTAssertEqual(Duell.wort(wahlA: 1, wahlB: 1, vorschlaege: v, seed: seed), "Pizza")
        }
    }

    func testDuellWortVerschiedeneWahlNimmtEinesDerBeidenUndIstSymmetrisch() {
        let v = ["Katze", "Pizza", "Mond"]
        var gesehen = Set<String>()
        for seed: UInt64 in 0..<20 {
            let w = Duell.wort(wahlA: 0, wahlB: 2, vorschlaege: v, seed: seed)
            XCTAssertTrue(["Katze", "Mond"].contains(w))
            XCTAssertEqual(w, Duell.wort(wahlA: 2, wahlB: 0, vorschlaege: v, seed: seed), "A und B vertauscht, gleiches Ergebnis")
            gesehen.insert(w)
        }
        XCTAssertEqual(gesehen.count, 2, "der Zufall entscheidet mal so, mal so")
    }

    func testDuellWortRobust() {
        XCTAssertEqual(Duell.wort(wahlA: 0, wahlB: 0, vorschlaege: [], seed: 1), "")
        XCTAssertEqual(Duell.wort(wahlA: 9, wahlB: 9, vorschlaege: ["A", "B"], seed: 1), "B")
    }

    func testDuellVorschlaegeDreiVerschiedeneUndDeterministisch() {
        let pool = ["a", "b", "c", "d", "e", "a"]
        let x = Duell.vorschlaege(pool: pool, seed: 42)
        XCTAssertEqual(x.count, 3)
        XCTAssertEqual(Set(x).count, 3)
        XCTAssertEqual(x, Duell.vorschlaege(pool: pool, seed: 42))
    }

    func testWortlisteImBundleHatGut300WoerterOhneDoppelte() throws {
        let bundle = Bundle(for: SpieleModell.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "duell-woerter", withExtension: "json")
                ?? bundle.url(forResource: "duell-woerter", withExtension: "json", subdirectory: "Spiele")
        )
        let liste = try XCTUnwrap(Wortliste.dekodieren(try Data(contentsOf: url)))
        for vibe in Wortliste.vibes { XCTAssertGreaterThanOrEqual(liste[vibe]?.count ?? 0, 30, vibe) }
        let alle = liste.values.flatMap { $0 }
        XCTAssertGreaterThanOrEqual(alle.count, 290)
        XCTAssertEqual(Set(alle).count, alle.count)
    }

    func testPoolFaelltAufAlleZurueck() {
        let w = ["leicht": ["Haus"], "tiere": ["Katze"]]
        XCTAssertEqual(Wortliste.pool(vibe: "tiere", woerter: w, eigene: []), ["Katze"])
        XCTAssertEqual(Wortliste.pool(vibe: "eigene", woerter: w, eigene: []), ["Haus", "Katze"])
        XCTAssertEqual(Wortliste.pool(vibe: "eigene", woerter: w, eigene: ["Schnuffel"]), ["Schnuffel"])
        XCTAssertEqual(Wortliste.pool(vibe: "gemischt", woerter: w, eigene: ["Schnuffel"]), ["Haus", "Katze", "Schnuffel"])
    }

    // MARK: - XO

    func testXOSiegerReiheSpalteDiagonale() {
        let A: Person? = .ahmed, N: Person? = .annika, o: Person? = nil
        XCTAssertEqual(XO.sieger(feld: [A, A, A, N, N, o, o, o, o]), .ahmed)
        XCTAssertEqual(XO.sieger(feld: [N, A, o, N, A, o, N, o, A]), .annika)
        XCTAssertEqual(XO.sieger(feld: [o, o, N, A, N, A, N, o, A]), .annika)
        XCTAssertNil(XO.sieger(feld: [A, N, A, A, N, N, N, A, A]), "volles Feld ohne Reihe")
        XCTAssertNil(XO.sieger(feld: [o, o, o, o, o, o, o, o, o]))
        XCTAssertNil(XO.sieger(feld: [A, A, A]), "falsche Größe")
    }

    func testXOStandSpieltAbwechselndNach() {
        let s = XO.stand(starter: .annika, zuege: [.annika: [0, 1, 2], .ahmed: [4, 5]])
        XCTAssertEqual(s.sieger, .annika)
        XCTAssertNil(s.amZug)

        let warten = XO.stand(starter: .annika, zuege: [.annika: [0, 1], .ahmed: [4]])
        XCTAssertEqual(warten.amZug, .ahmed)
        XCTAssertEqual(warten.feld.compactMap { $0 }.count, 3)

        let belegt = XO.stand(starter: .ahmed, zuege: [.ahmed: [0], .annika: [0]])
        XCTAssertEqual(belegt.amZug, .annika, "ungültiger Zug hält die Wiedergabe an")
    }

    // MARK: - SSP

    func testSSPSiegerAlleKombinationen() {
        XCTAssertEqual(SSP.sieger(a: .stein, b: .schere), .stein)
        XCTAssertEqual(SSP.sieger(a: .schere, b: .stein), .stein)
        XCTAssertEqual(SSP.sieger(a: .schere, b: .papier), .schere)
        XCTAssertEqual(SSP.sieger(a: .papier, b: .schere), .schere)
        XCTAssertEqual(SSP.sieger(a: .papier, b: .stein), .papier)
        XCTAssertEqual(SSP.sieger(a: .stein, b: .papier), .papier)
        for h in SSP.allCases { XCTAssertNil(SSP.sieger(a: h, b: h)) }
    }

    func testSSPBestOfThreeUnentschiedenZaehltNicht() {
        let st = SSP.stein.rawValue, sc = SSP.schere.rawValue, pa = SSP.papier.rawValue
        let s = SSP.stand([.ahmed: [st, st, pa, st], .annika: [st, sc, sc, sc]])
        XCTAssertEqual(s.sieger, .ahmed)
        XCTAssertEqual(s.runden, 4)
        XCTAssertEqual(s.siege, SpielPunkte(ahmed: 2, annika: 1))

        XCTAssertNil(SSP.stand([.ahmed: [st], .annika: []]).sieger)
    }

    // MARK: - Reaktion

    func testReaktionZuFruehVerliert() {
        XCTAssertEqual(ReaktionsDuell.rundenSieger(ahmed: -1, annika: 900), .annika)
        XCTAssertEqual(ReaktionsDuell.rundenSieger(ahmed: 250, annika: -1), .ahmed)
        XCTAssertNil(ReaktionsDuell.rundenSieger(ahmed: -1, annika: -1))
        XCTAssertEqual(ReaktionsDuell.rundenSieger(ahmed: 250, annika: 300), .ahmed)
        XCTAssertNil(ReaktionsDuell.rundenSieger(ahmed: 300, annika: 300))
    }

    func testReaktionVerzoegerungZwischenZweiUndSechsUndGleich() {
        for r in 0..<50 {
            let d = ReaktionsDuell.verzoegerung(spiel: "s", partie: 0, runde: r)
            XCTAssertTrue((2...6).contains(d))
            XCTAssertEqual(d, ReaktionsDuell.verzoegerung(spiel: "s", partie: 0, runde: r))
        }
    }

    func testReaktionErsterMitDreiSiegen() {
        let s = ReaktionsDuell.stand([.ahmed: [200, 200, -1, 200], .annika: [300, 300, 300, 300]])
        XCTAssertEqual(s.sieger, .ahmed)
        XCTAssertEqual(s.siege, SpielPunkte(ahmed: 3, annika: 1))
    }

    // MARK: - Memory

    func testMemoryKartenSindPaareUndGleichGemischt() {
        let motive = (0..<8).map { "s:\($0)" }
        let a = Memory.karten(motive: motive, seed: 7)
        XCTAssertEqual(a, Memory.karten(motive: motive, seed: 7))
        XCTAssertEqual(a.count, 16)
        XCTAssertEqual(Dictionary(grouping: a, by: { $0 }).values.map(\.count), Array(repeating: 2, count: 8))
    }

    func testMemoryTrefferBehaeltZugFehlgriffGibtAb() {
        let karten = ["a", "b", "a", "b"]
        let s = Memory.stand(karten: karten, starter: .ahmed, zuege: [.ahmed: [0, 2, 1, 3]])
        XCTAssertTrue(s.fertig)
        XCTAssertEqual(s.paare, SpielPunkte(ahmed: 2, annika: 0))

        let fehl = Memory.stand(karten: karten, starter: .ahmed, zuege: [.ahmed: [0, 1], .annika: [2]])
        XCTAssertEqual(fehl.amZug, .annika)
        XCTAssertEqual(fehl.offen, [2])
        XCTAssertEqual(fehl.zuletzt, [])
        XCTAssertFalse(fehl.fertig)

        let nurFehl = Memory.stand(karten: karten, starter: .ahmed, zuege: [.ahmed: [0, 1]])
        XCTAssertEqual(nurFehl.zuletzt, [0, 1])
    }

    // MARK: - Kennen

    func testKennenFuenfFragenDeterministisch() {
        let eigene = [KennenFrage(text: "Eigene {name}", optionen: ["a", "b"])]
        let f = Kennen.fragen(eigene: eigene, seed: 3)
        XCTAssertEqual(f.count, 5)
        XCTAssertEqual(f, Kennen.fragen(eigene: eigene, seed: 3))
        XCTAssertTrue(f.contains(eigene[0]), "eigene Fragen kommen immer mit")
        XCTAssertEqual(Kennen.fragen(eigene: [], seed: 3).count, 5, "ohne eigene Daten nur der feste Satz")
        XCTAssertEqual(Kennen.treffer(antworten: [0, 1, 2, 3, 0], tipps: [0, 1, 0, 3, 1]), 3)
        XCTAssertEqual(eigene[0].text(fuer: .annika), "Eigene Annika")
    }
}

// MARK: - Faltung

@MainActor
final class SpieleModellTests: XCTestCase {

    private func op(_ art: String, _ d: [String: Any], von: Person = .ahmed, id: String = UUID().uuidString, seq: Int? = nil) -> Op {
        Op(id: id, seq: seq, art: art, von: von, zeit: Date(), d: try! JSONSerialization.data(withJSONObject: d))
    }

    func testBilanzZaehltLetztesErgebnisProSpielUndIstIdempotent() {
        let m = SpieleModell(registrieren: false)
        m.anwenden(op("spiel.einladung", ["id": "x1", "art": "xo", "einstellungen": [String: Any](), "bis": "2026-09-23T12:02:00.000Z"]))
        m.anwenden(op("spiel.einladung", ["id": "x2", "art": "xo", "einstellungen": [String: Any](), "bis": "2026-09-23T12:02:00.000Z"]))
        m.anwenden(op("spiel.einladung", ["id": "d1", "art": "duell", "einstellungen": ["runden": 3, "dauer": 60, "vibes": ["leicht"]] as [String: Any]]))

        let e1 = op("spiel.ergebnis", ["id": "x1", "gespielt": 1, "punkte": ["ahmed": 1, "annika": 0]])
        let e3 = op("spiel.ergebnis", ["id": "x1", "gespielt": 3, "punkte": ["ahmed": 1, "annika": 2]], von: .annika)
        m.anwenden(e1)
        m.anwenden(e3)
        m.anwenden(e1) // late duplicate / older result must not win
        m.anwenden(op("spiel.ergebnis", ["id": "x2", "gespielt": 1, "punkte": ["ahmed": 0, "annika": 1]]))
        m.anwenden(op("spiel.ergebnis", ["id": "d1", "gespielt": 1, "punkte": ["ahmed": 1, "annika": 0]]))
        m.anwenden(op("spiel.ergebnis", ["id": "unbekannt", "gespielt": 9, "punkte": ["ahmed": 9, "annika": 9]]))

        XCTAssertEqual(m.spiele["x1"]?.ergebnis, SpieleModell.Ergebnis(gespielt: 3, punkte: SpielPunkte(ahmed: 1, annika: 2)))
        XCTAssertEqual(m.bilanz[.xo], SpielPunkte(ahmed: 1, annika: 3))
        XCTAssertEqual(m.bilanz[.duell], SpielPunkte(ahmed: 1, annika: 0))
        XCTAssertEqual(m.gespielt[.xo], 4)
        XCTAssertEqual(m.spiele["d1"]?.einstellungen.runden, 3)
        XCTAssertEqual(SpielPunkte(ahmed: 1, annika: 2).text, "Annika 2 : Ahmed 1")
    }

    func testEinladungVerfaelltUndVerschwindet() {
        let m = SpieleModell(registrieren: false)
        let bis = SpieleModell.datumString(Date().addingTimeInterval(120))
        m.anwenden(op("spiel.einladung", ["id": "s1", "art": "ssp", "bis": bis]))
        XCTAssertTrue(m.sichtbar("s1"))
        m.anwenden(op("spiel.verfallen", ["id": "s1"]))
        XCTAssertFalse(m.sichtbar("s1"))

        m.anwenden(op("spiel.einladung", ["id": "s2", "art": "ssp", "bis": SpieleModell.datumString(Date().addingTimeInterval(-1))]))
        XCTAssertFalse(m.sichtbar("s2"), "abgelaufen, auch ohne Server-Op")

        m.anwenden(op("spiel.einladung", ["id": "s3", "art": "ssp", "bis": bis]))
        m.anwenden(op("spiel.angenommen", ["id": "s3"], von: .annika))
        XCTAssertTrue(m.spiele["s3"]?.sichtbar(jetzt: Date().addingTimeInterval(600)) ?? false, "angenommen bleibt stehen")
    }

    func testBilderStimmenUndNachrichtWerdenZugeordnet() {
        let m = SpieleModell(registrieren: false)
        m.anwenden(op("spiel.einladung", ["id": "d", "art": "duell"]))
        m.anwenden(op("nachricht.neu", ["id": "n1", "spiel": ["id": "d"]]))
        m.anwenden(op("spiel.bild", ["id": "d", "runde": 0, "medienId": "m1"], von: .ahmed))
        m.anwenden(op("spiel.bild", ["id": "d", "runde": 0, "medienId": "m2"], von: .annika))
        m.anwenden(op("spiel.stimme", ["id": "d", "runde": 0, "fuer": "annika"], von: .ahmed))
        XCTAssertEqual(m.spiele["d"]?.nachrichtId, "n1")
        XCTAssertEqual(m.spiele["d"]?.bilder[0], [.ahmed: "m1", .annika: "m2"])
        XCTAssertEqual(m.spiele["d"]?.stimmen[0], [.ahmed: .annika])
    }

    func testEigeneWoerterAusEinstellung() {
        let m = SpieleModell(registrieren: false)
        m.anwenden(op("einstellung.setzen", ["schluessel": "duellWoerter", "wert": ["Schnuffel", "Pupsbär"]], von: .annika))
        m.anwenden(op("einstellung.setzen", ["schluessel": "flamme", "wert": true]))
        m.anwenden(op("einstellung.setzen", ["schluessel": "duellWoerter", "wert": ["Pupsbär", "Keks"]], von: .ahmed))
        XCTAssertEqual(m.alleEigenenWoerter, ["Pupsbär", "Keks", "Schnuffel"])
    }

    func testNeueEinladungErsetztDieOffeneAlte() {
        let m = SpieleModell(registrieren: false)
        let bis = SpieleModell.datumString(Date().addingTimeInterval(120))
        m.anwenden(op("spiel.einladung", ["id": "a", "art": "xo", "bis": bis], von: .ahmed))
        m.anwenden(op("spiel.einladung", ["id": "c", "art": "ssp", "bis": bis], von: .annika))
        m.anwenden(op("spiel.einladung", ["id": "b", "art": "memory", "bis": bis], von: .ahmed))
        m.anwenden(op("spiel.angenommen", ["id": "b"], von: .annika))
        XCTAssertEqual(m.offeneEinladungen(von: .ahmed), ["a"], "nur die wartende eigene, nicht die angenommene")
        XCTAssertEqual(m.offeneEinladungen(von: .annika), ["c"])

        // einladen() sends this for every id above before the new invitation.
        m.anwenden(op("spiel.abgebrochen", ["id": "a"], von: .ahmed))
        m.anwenden(op("spiel.einladung", ["id": "d", "art": "xo", "bis": bis], von: .ahmed))
        XCTAssertFalse(m.sichtbar("a"))
        XCTAssertEqual(m.offeneEinladungen(von: .ahmed), ["d"], "immer nur eine aktive Einladung")
        XCTAssertTrue(m.sichtbar("b"))
        XCTAssertTrue(m.sichtbar("c"), "die Einladung des Partners bleibt")
    }

    func testAbbrechenFaltetWieVerfallenNurVomEinladenden() {
        let m = SpieleModell(registrieren: false)
        let bis = SpieleModell.datumString(Date().addingTimeInterval(120))
        m.anwenden(op("spiel.einladung", ["id": "s", "art": "reaktion", "bis": bis], von: .annika))
        m.anwenden(op("spiel.abgebrochen", ["id": "s"], von: .ahmed))
        XCTAssertTrue(m.sichtbar("s"), "der Eingeladene kann nicht abbrechen")

        let abbruch = op("spiel.abgebrochen", ["id": "s"], von: .annika)
        m.anwenden(abbruch)
        m.anwenden(abbruch) // server echo
        XCTAssertFalse(m.sichtbar("s"))
        XCTAssertEqual(m.spiele["s"]?.verfallen, true)
        XCTAssertEqual(m.offeneEinladungen(von: .annika), [])
        m.anwenden(op("spiel.abgebrochen", ["id": "unbekannt"], von: .annika))
        XCTAssertNil(m.spiele["unbekannt"])
    }

    func testDuellDreiRundenAutomatischLeichtMittelSchwer() {
        let drei = SpieleModell.Einstellungen.duell(runden: 3, dauer: 300, vibe: "tiere")
        XCTAssertEqual(drei, SpieleModell.Einstellungen(runden: 3, dauer: 300, vibes: ["leicht", "mittel", "schwer"]))
        XCTAssertEqual(SpieleModell.Einstellungen.duell(), SpieleModell.Einstellungen(runden: 1, dauer: 60, vibes: [Wortliste.gemischt]), "Standard: 1 Runde, 60 s, zufällig")
        XCTAssertEqual(SpieleModell.Einstellungen.duell(vibe: "suess").vibes, ["suess"])
    }

    func testAeltererZugUeberschreibtNeuerePartieNicht() {
        let m = SpieleModell(registrieren: false)
        m.zugAnwenden(Zug(id: "g", partie: 2, zuege: [1]), von: .annika)
        m.zugAnwenden(Zug(id: "g", partie: 1, zuege: [1, 2, 3]), von: .annika)
        XCTAssertEqual(m.zug("g", .annika)?.partie, 2)
        XCTAssertEqual(m.partie("g"), 2)
    }
}
