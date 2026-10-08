import XCTest
@testable import Lovea

// "Wer von uns ist eher?", Wordle-Duell und Schiffe versenken: reine Logik und Modell-Faltung.

final class EherLogikTests: XCTestCase {

    func testWahlUndPerson() {
        XCTAssertEqual(Eher.wahl(.ahmed), 0)
        XCTAssertEqual(Eher.wahl(.annika), 1)
        XCTAssertEqual(Eher.person(wahl: 0), .ahmed)
        XCTAssertEqual(Eher.person(wahl: 1), .annika)
        XCTAssertNil(Eher.person(wahl: 2))
        XCTAssertNil(Eher.person(wahl: -1))
    }

    func testAussagenZehnOhneWiederholungUndDeterministisch() {
        let pool = (0..<30).map { "Aussage \($0)" }
        let a = Eher.aussagen(pool: pool, spiel: "g1", partie: 0)
        XCTAssertEqual(a.count, Eher.anzahl)
        XCTAssertEqual(Set(a).count, a.count, "keine Aussage doppelt in einer Runde")
        XCTAssertEqual(a, Eher.aussagen(pool: pool, spiel: "g1", partie: 0), "beide Geräte sehen dasselbe")
    }

    func testNaechsteRundeNimmtAndereAussagenBisDerPoolDurchIst() {
        let pool = (0..<30).map { "Aussage \($0)" }
        let r0 = Eher.aussagen(pool: pool, spiel: "g1", partie: 0)
        let r1 = Eher.aussagen(pool: pool, spiel: "g1", partie: 1)
        let r2 = Eher.aussagen(pool: pool, spiel: "g1", partie: 2)
        XCTAssertTrue(Set(r0).isDisjoint(with: r1))
        XCTAssertTrue(Set(r1).isDisjoint(with: r2))
        XCTAssertEqual(Set(r0 + r1 + r2), Set(pool))
        XCTAssertEqual(Eher.aussagen(pool: pool, spiel: "g1", partie: 3), r0, "danach von vorn")
    }

    func testDoppelteImPoolFallenWeg() {
        XCTAssertEqual(Set(Eher.aussagen(pool: ["a", "a", "b"], spiel: "g", partie: 0)), ["a", "b"])
        XCTAssertEqual(Eher.aussagen(pool: [], spiel: "g", partie: 0), [])
    }

    func testGleichBrauchtBeideAntworten() {
        let a = [0, 1, 0], b = [0, 0, 0]
        XCTAssertTrue(Eher.gleich(a, b, frage: 0))
        XCTAssertFalse(Eher.gleich(a, b, frage: 1))
        XCTAssertTrue(Eher.gleich(a, b, frage: 2))
        XCTAssertFalse(Eher.gleich(a, b, frage: 3), "noch nicht beantwortet")
        XCTAssertFalse(Eher.gleich([5], [5], frage: 0), "ungültiger Code zählt nicht")
    }

    func testStandZaehltNurFertigeFragen() {
        let z: [Person: [Int]] = [.ahmed: [0, 0, 0], .annika: [0, 1]]
        XCTAssertEqual(Eher.stand(zuege: z), Eher.Stand(gleich: 1, fertig: 2))
        let leer = Eher.stand(zuege: [:])
        XCTAssertEqual(leer.fertig, 0)
        XCTAssertEqual(leer.gleich, 0)
    }

    func testEndeKeinSiegerPaarWertung() {
        let z: [Person: [Int]] = [
            .ahmed: Array(repeating: 0, count: 10),
            .annika: [0, 1, 0, 1, 0, 1, 0, 1, 0, 1],
        ]
        let s = Eher.stand(zuege: z)
        XCTAssertEqual(s.fertig, 10)
        let e = Eher.ende(s)
        XCTAssertNil(e.sieger)
        XCTAssertEqual(e.punkte, SpielPunkte(ahmed: 5, annika: 5))
        XCTAssertEqual(e.titel, "Ziemlich im Takt")
        XCTAssertEqual(Eher.ende(Eher.Stand(gleich: 9, fertig: 10)).titel, "Ihr tickt gleich!")
        XCTAssertEqual(Eher.ende(Eher.Stand(gleich: 2, fertig: 10)).titel, "Gegensätze ziehen sich an")
    }

    func testBilanzTextPaarWertung() {
        let p = SpielPunkte(ahmed: 7, annika: 3)
        XCTAssertTrue(SpielArt.eher.paarWertung)
        XCTAssertEqual(SpielArt.eher.bilanzText(p), "7 von 10 gleich")
        XCTAssertFalse(SpielArt.xo.paarWertung)
        XCTAssertEqual(SpielArt.xo.bilanzText(p), p.text)
    }

    func testAussagenDateiImBundle() throws {
        let liste = Eher.laden(bundle: Bundle(for: SpieleModell.self))
        XCTAssertGreaterThanOrEqual(liste.count, 60)
        XCTAssertEqual(Set(liste).count, liste.count)
        XCTAssertTrue(liste.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}

final class WordleLogikTests: XCTestCase {

    private func woerter() -> Wordle.Woerter {
        Wordle.Woerter(ziele: ["KISTE", "LIEBE"], erlaubt: ["hause"])
    }

    func testBewertenAllesRichtig() {
        XCTAssertEqual(Wordle.bewerten("KÜSSE", ziel: "KÜSSE"), Array(repeating: Wordle.Farbe.richtig, count: 5))
        XCTAssertEqual(Wordle.bewerten("küsse", ziel: "KÜSSE"), Array(repeating: Wordle.Farbe.richtig, count: 5))
    }

    func testBewertenDoppelteBuchstaben() {
        // K I S T E gegen K E K S E
        XCTAssertEqual(
            Wordle.bewerten("KEKSE", ziel: "KISTE"),
            [.richtig, .fehlt, .fehlt, .vorhanden, .richtig]
        )
        // L I E B E gegen E E E E E: nur die zwei echten E sind grün, der Rest bleibt grau
        XCTAssertEqual(
            Wordle.bewerten("EEEEE", ziel: "LIEBE"),
            [.fehlt, .fehlt, .richtig, .fehlt, .richtig]
        )
    }

    func testTastaturFarbenZeigenDieBesteFarbe() {
        let m = Wordle.tastaturFarben(tipps: ["KEKSE"], ziel: "KISTE")
        XCTAssertEqual(m["K"], .richtig)
        XCTAssertEqual(m["E"], .richtig)
        XCTAssertEqual(m["S"], .vorhanden)
        XCTAssertNil(m["Z"])
    }

    func testGueltigNurWoerterAusDerListe() {
        let w = woerter()
        XCTAssertTrue(Wordle.gueltig("kiste", in: w))
        XCTAssertTrue(Wordle.gueltig("HAUSE", in: w), "erlaubte Tipps zählen auch")
        XCTAssertFalse(Wordle.gueltig("XXXXX", in: w))
        XCTAssertFalse(Wordle.gueltig("KIST", in: w))
    }

    func testTagInBerlin() {
        XCTAssertEqual(Wordle.tag(Date(timeIntervalSince1970: 0)), "1970-01-01")
        let spaet = ISO8601DateFormatter().date(from: "2026-06-30T22:30:00Z")
        XCTAssertEqual(Wordle.tag(try XCTUnwrap(spaet)), "2026-07-01", "00:30 Uhr Sommerzeit ist schon der nächste Tag")
    }

    func testZielGleichFuerBeideUndWechseltMitDerPartie() {
        let w = Wordle.laden(bundle: Bundle(for: SpieleModell.self))
        let a = Wordle.ziel(woerter: w, tag: "2026-10-08", partie: 0)
        XCTAssertEqual(a, Wordle.ziel(woerter: w, tag: "2026-10-08", partie: 0))
        XCTAssertTrue(w.ziele.contains(a))
        let partien = Set((0..<10).map { Wordle.ziel(woerter: w, tag: "2026-10-08", partie: $0) })
        XCTAssertGreaterThan(partien.count, 1)
        XCTAssertEqual(Wordle.ziel(woerter: Wordle.Woerter(ziele: [], erlaubt: []), tag: "x", partie: 0), "")
    }

    func testLaufGewonnenZaehltBisZumTreffer() {
        let l = Wordle.lauf(tipps: ["AAAAA", "KISTE"], zeiten: [1000, 2500], ziel: "KISTE")
        XCTAssertEqual(l, Wordle.Lauf(gewonnen: true, versuche: 2, ms: 2500, fertig: true))
        let danach = Wordle.lauf(tipps: ["KISTE", "AAAAA"], zeiten: [800, 900], ziel: "KISTE")
        XCTAssertEqual(danach.versuche, 1, "Tipps nach dem Treffer zählen nicht")
    }

    func testLaufVerlorenNachSechsVersuchen() {
        let sechs = Array(repeating: "AAAAA", count: 6)
        let l = Wordle.lauf(tipps: sechs, zeiten: [1, 2, 3, 4, 5, 6], ziel: "KISTE")
        XCTAssertEqual(l, Wordle.Lauf(gewonnen: false, versuche: 6, ms: 6, fertig: true))
        XCTAssertFalse(Wordle.lauf(tipps: Array(sechs.prefix(3)), zeiten: [1, 2, 3], ziel: "KISTE").fertig)
    }

    private func lauf(_ gewonnen: Bool, _ versuche: Int, _ ms: Int = 0, fertig: Bool = true) -> Wordle.Lauf {
        Wordle.Lauf(gewonnen: gewonnen, versuche: versuche, ms: ms, fertig: fertig)
    }

    func testWenigerVersucheGewinnen() {
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(true, 3), annika: lauf(true, 4)), .sieg(.ahmed))
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(true, 5), annika: lauf(true, 2)), .sieg(.annika))
    }

    func testGleicheVersucheEntscheidetDieZeit() {
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(true, 3, 9000), annika: lauf(true, 3, 8000)), .sieg(.annika))
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(true, 3, 8000), annika: lauf(true, 3, 8000)), .remis)
    }

    func testNurEinerGeloestUndBeideFertig() {
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(false, 6), annika: lauf(true, 6)), .sieg(.annika))
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(false, 6), annika: lauf(false, 6)), .remis)
    }

    func testFrueheEntscheidungWennDerGegnerNichtMehrAufholt() {
        let fertig3 = lauf(true, 3, 1000)
        XCTAssertEqual(Wordle.ausgang(ahmed: fertig3, annika: lauf(false, 2, fertig: false)), .offen, "Annika kann noch in 3 lösen")
        XCTAssertEqual(Wordle.ausgang(ahmed: fertig3, annika: lauf(false, 3, fertig: false)), .sieg(.ahmed), "Annikas nächster Versuch wäre der vierte")
        XCTAssertEqual(Wordle.ausgang(ahmed: lauf(false, 1, fertig: false), annika: lauf(false, 0, fertig: false)), .offen)
    }

    func testEndeTextUndPunkte() {
        XCTAssertNil(Wordle.ende(ahmed: lauf(false, 1, fertig: false), annika: lauf(false, 0, fertig: false), ziel: "kiste"))
        let e = Wordle.ende(ahmed: lauf(true, 3), annika: lauf(true, 4), ziel: "kiste")
        XCTAssertEqual(e?.sieger, .ahmed)
        XCTAssertEqual(e?.punkte, SpielPunkte(ahmed: 1, annika: 0))
        XCTAssertTrue(e?.text.contains("KISTE") ?? false)
        let remis = Wordle.ende(ahmed: lauf(false, 6), annika: lauf(false, 6), ziel: "KISTE")
        XCTAssertNil(remis?.sieger)
        XCTAssertEqual(remis?.punkte, SpielPunkte())
    }

    func testWortlisteImBundle() {
        let w = Wordle.laden(bundle: Bundle(for: SpieleModell.self))
        XCTAssertGreaterThanOrEqual(w.ziele.count, 300)
        let erlaubteBuchstaben = Set(Wordle.tastatur.joined())
        for wort in w.ziele + w.erlaubt {
            XCTAssertEqual(wort.count, Wordle.laenge, wort)
            XCTAssertEqual(wort, Wordle.norm(wort), wort)
            XCTAssertTrue(Set(wort).isSubset(of: erlaubteBuchstaben), "\(wort) hat einen Buchstaben ohne Taste")
        }
        XCTAssertEqual(Set(w.ziele).count, w.ziele.count)
        XCTAssertTrue(Set(w.ziele).isSubset(of: w.menge))
    }

    func testTastaturHatAlleBuchstabenEinmal() {
        let alle = Array(Wordle.tastatur.joined())
        XCTAssertEqual(alle.count, 29)
        XCTAssertEqual(Set(alle).count, 29)
        XCTAssertTrue(Set(alle).isSuperset(of: Set("ÄÖÜ")))
    }
}

final class SchiffeLogikTests: XCTestCase {

    /// Gültige Testflotte: vier Reihen links oben, nichts überlappt.
    private let flotte: [Schiff] = [
        Schiff(start: 0, laenge: 4, quer: true),   // 0 1 2 3
        Schiff(start: 8, laenge: 3, quer: true),   // 8 9 10
        Schiff(start: 16, laenge: 3, quer: true),  // 16 17 18
        Schiff(start: 24, laenge: 2, quer: true),  // 24 25
        Schiff(start: 32, laenge: 2, quer: true),  // 32 33
    ]
    private let alleZellen = [0, 1, 2, 3, 8, 9, 10, 16, 17, 18, 24, 25, 32, 33]

    func testKoordinate() {
        XCTAssertEqual(Schiffe.koordinate(0), "A1")
        XCTAssertEqual(Schiffe.koordinate(9), "B2")
        XCTAssertEqual(Schiffe.koordinate(63), "H8")
        XCTAssertEqual(Schiffe.koordinate(64), "?")
    }

    func testSchiffAufDemBrett() {
        XCTAssertTrue(Schiff(start: 4, laenge: 4, quer: true).aufDemBrett)
        XCTAssertFalse(Schiff(start: 6, laenge: 4, quer: true).aufDemBrett, "kein Umbruch in die nächste Reihe")
        XCTAssertTrue(Schiff(start: 48, laenge: 2, quer: false).aufDemBrett)
        XCTAssertFalse(Schiff(start: 56, laenge: 2, quer: false).aufDemBrett)
        XCTAssertFalse(Schiff(start: 64, laenge: 2, quer: true).aufDemBrett)
        XCTAssertEqual(Schiff(start: 9, laenge: 3, quer: false).zellen, [9, 17, 25])
    }

    func testFlottenRegeln() {
        XCTAssertTrue(Schiffe.gueltig(flotte))
        XCTAssertEqual(Schiffe.laengen.reduce(0, +), 14)
        var ueberlappt = flotte
        ueberlappt[1] = Schiff(start: 1, laenge: 3, quer: false)  // 1 9 17 trifft Schiff 0 und 2
        XCTAssertFalse(Schiffe.gueltig(ueberlappt))
        XCTAssertFalse(Schiffe.gueltig(Array(flotte.dropLast())), "ein Schiff fehlt")
        var falsch = flotte
        falsch[0] = Schiff(start: 0, laenge: 5, quer: true)
        XCTAssertFalse(Schiffe.gueltig(falsch), "falsche Länge")
    }

    func testZufaelligeFlotteIstImmerGueltigUndDeterministischMitSeed() {
        for seed in 0..<60 {
            var z = Zufall(UInt64(seed))
            XCTAssertTrue(Schiffe.gueltig(Schiffe.zufaellig(using: &z)), "Seed \(seed)")
        }
        var a = Zufall(UInt64(7)), b = Zufall(UInt64(7))
        XCTAssertEqual(Schiffe.zufaellig(using: &a), Schiffe.zufaellig(using: &b))
        XCTAssertTrue(Schiffe.gueltig(Schiffe.zufaellig()))
    }

    func testListeEndetBeiDerErstenLuecke() {
        XCTAssertEqual(Schiffe.liste(aus: [0: 5, 1: 7, 3: 9]), [5, 7])
        XCTAssertEqual(Schiffe.liste(aus: [:]), [])
        XCTAssertEqual(Schiffe.liste(aus: [1: 4]), [])
    }

    private func stand(_ a: [Int], _ b: [Int], starter: Person = .ahmed) -> Schiffe.Stand {
        Schiffe.stand(starter: starter, flotten: [.ahmed: flotte, .annika: flotte], schuesse: [.ahmed: a, .annika: b])
    }

    func testOhneBeideFlottenNochNichtBereit() {
        let s = Schiffe.stand(starter: .ahmed, flotten: [.ahmed: flotte], schuesse: [:])
        XCTAssertFalse(s.bereit)
        XCTAssertNil(s.amZug)
        XCTAssertNil(s.sieger)
    }

    func testStarterSchiesstZuerst() {
        XCTAssertEqual(stand([], []).amZug, .ahmed)
        XCTAssertEqual(stand([], [], starter: .annika).amZug, .annika)
        XCTAssertTrue(stand([], []).bereit)
    }

    func testAbwechselndAuchNachTreffer() {
        let s = stand([0], [])
        XCTAssertEqual(s.verlauf, [Schiffe.Schuss(von: .ahmed, zelle: 0, ausgang: .treffer)])
        XCTAssertEqual(s.amZug, .annika, "nach einem Treffer ist trotzdem der andere dran")
    }

    func testWasserTrefferUndVersenkt() {
        let s = stand([0, 1, 2, 3], [63, 62, 61])
        XCTAssertEqual(s.verlauf.count, 7)
        XCTAssertEqual(s.verlauf[1].ausgang, .wasser)
        XCTAssertEqual(s.verlauf[6].ausgang, .versenkt(flotte[0]))
        XCTAssertEqual(s.versenkt(von: .ahmed), [flotte[0]])
        XCTAssertTrue(s.versenkt(von: .annika).isEmpty)
        XCTAssertEqual(s.amZug, .annika)
        XCTAssertEqual(s.beschossen(von: .ahmed), [0, 1, 2, 3])
    }

    func testSiegWennAlleSchiffeVersenkt() {
        let ahmed = alleZellen
        let annika = (0..<13).map { 63 - $0 }
        let s = stand(ahmed, annika)
        XCTAssertEqual(s.sieger, .ahmed)
        XCTAssertNil(s.amZug)
        XCTAssertEqual(s.versenkt(von: .ahmed).count, 5)
        // Weitere Schüsse nach dem Sieg ändern nichts.
        let spaeter = stand(ahmed + [40], annika + [50])
        XCTAssertEqual(spaeter.sieger, .ahmed)
        XCTAssertEqual(spaeter.verlauf.count, s.verlauf.count)
    }

    func testDoppelterSchussKostetKeinenZug() {
        let s = stand([0, 0, 1], [63])
        XCTAssertEqual(s.verlauf.count, 3)
        XCTAssertEqual(s.verlauf.map(\.zelle), [0, 63, 1])
        XCTAssertEqual(s.amZug, .annika)
    }

    func testSchussAusserhalbDesBrettsWirdUebersprungen() {
        let s = stand([99, -1, 5], [])
        XCTAssertEqual(s.verlauf.map(\.zelle), [5])
    }

    func testOpsFaltenSichInsModellErsterGewinnt() {
        let m = SpieleModell(registrieren: false)
        m.anwenden(op("spiel.einladung", ["id": "g", "art": "schiffe"]))
        let schiffe: [[String: Any]] = flotte.map { ["start": $0.start, "laenge": $0.laenge, "quer": $0.quer] }

        m.anwenden(op("spiel.flotte", ["id": "g", "partie": 0, "schiffe": schiffe]))
        XCTAssertEqual(m.spiele["g"]?.flotten[0]?[.ahmed], flotte)

        // Zweite Flotte derselben Person in derselben Runde zählt nicht.
        let anders: [[String: Any]] = [["start": 56, "laenge": 4, "quer": true]]
        m.anwenden(op("spiel.flotte", ["id": "g", "partie": 0, "schiffe": anders]))
        XCTAssertEqual(m.spiele["g"]?.flotten[0]?[.ahmed], flotte)

        // Ungültige Flotte von Annika wird verworfen.
        m.anwenden(op("spiel.flotte", ["id": "g", "partie": 0, "schiffe": anders], von: .annika))
        XCTAssertNil(m.spiele["g"]?.flotten[0]?[.annika])

        // Dieselbe Op doppelt (Wiedergabe) ändert nichts.
        m.anwenden(op("spiel.schuss", ["id": "g", "partie": 0, "nr": 0, "zelle": 5]))
        m.anwenden(op("spiel.schuss", ["id": "g", "partie": 0, "nr": 0, "zelle": 6]))
        m.anwenden(op("spiel.schuss", ["id": "g", "partie": 0, "nr": 1, "zelle": 64]))
        m.anwenden(op("spiel.schuss", ["id": "g", "partie": 0, "nr": 1, "zelle": 7]))
        XCTAssertEqual(m.spiele["g"]?.schuesse[0]?[.ahmed], [0: 5, 1: 7])
        XCTAssertEqual(Schiffe.liste(aus: m.spiele["g"]?.schuesse[0]?[.ahmed] ?? [:]), [5, 7])
    }

    func testFlotteUndSchussGeltenNurFuerSchiffe() {
        let m = SpieleModell(registrieren: false)
        m.anwenden(op("spiel.einladung", ["id": "x", "art": "xo"]))
        let schiffe: [[String: Any]] = flotte.map { ["start": $0.start, "laenge": $0.laenge, "quer": $0.quer] }
        m.anwenden(op("spiel.flotte", ["id": "x", "partie": 0, "schiffe": schiffe]))
        m.anwenden(op("spiel.schuss", ["id": "x", "partie": 0, "nr": 0, "zelle": 5]))
        XCTAssertNil(m.spiele["x"]?.flotten[0])
        XCTAssertNil(m.spiele["x"]?.schuesse[0])
    }

    private func op(_ art: String, _ d: [String: Any], von: Person = .ahmed) -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(), d: try! JSONSerialization.data(withJSONObject: d))
    }
}
