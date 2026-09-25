import XCTest
@testable import Lovea

final class ChallengeLogikTests: XCTestCase {

    private static let ziel140k = [ZielAenderung(seq: 1, datum: "2000-01-01", wert: 140_000)]

    // MARK: - Duell der Woche

    /// Review-Fokus 4: ein Tag, an dem nur eine Person Daten hat, darf im Duell nicht als 0 gegen
    /// die andere zählen. Ahmed hat alle 7 Tage à 8.000, Annika 6 Tage à 9.000 und einen fehlenden
    /// Tag — ein naiver Vergleich über ALLE Tage gäbe Ahmed (56.000) den Sieg über Annika (54.000).
    /// Fair verglichen (nur die 6 gemeinsamen Tage) gewinnt Annika 54.000 zu 48.000.
    func testDuellVergleichtNurTageMitDatenBeiderPersonen() {
        let montag = "2026-09-21"
        let tage = (0..<7).map { Datum.addTage(montag, $0) }
        var schritte = tage.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 8000) }
        schritte += tage.dropLast().map { TagesEintrag(seq: 1, von: Person.annika, datum: $0, gesendetAm: $0, wert: 9000) } // letzter Tag fehlt

        let wochen = ChallengeLogik.wochen(heute: "2026-09-28", schritte: schritte, zielGemeinsamWocheAenderungen: Self.ziel140k)
        let woche = wochen.first { $0.montag == montag }!

        XCTAssertTrue(woche.abgeschlossen)
        XCTAssertEqual(woche.schritteDuell[.ahmed], 48_000)
        XCTAssertEqual(woche.schritteDuell[.annika], 54_000)
        XCTAssertEqual(woche.duellSieger, .annika)
    }

    func testDuellOhneGemeinsameTageHatKeinenSieger() {
        let montag = "2026-09-21"
        let schritte = [TagesEintrag(seq: 1, von: Person.ahmed, datum: montag, gesendetAm: montag, wert: 20_000)]
        let woche = ChallengeLogik.wochen(heute: "2026-09-28", schritte: schritte, zielGemeinsamWocheAenderungen: Self.ziel140k).first { $0.montag == montag }!
        XCTAssertNil(woche.duellSieger)
    }

    func testDuellNochNichtAbgeschlossenHatNochKeinenSieger() {
        let montag = "2026-09-21"
        let tage = (0..<7).map { Datum.addTage(montag, $0) }
        let schritte = tage.flatMap { tag in
            [TagesEintrag(seq: 1, von: Person.ahmed, datum: tag, gesendetAm: tag, wert: 20_000),
             TagesEintrag(seq: 1, von: Person.annika, datum: tag, gesendetAm: tag, wert: 1000)]
        }
        // Mittwoch derselben Woche: die Woche läuft noch.
        let woche = ChallengeLogik.wochen(heute: "2026-09-23", schritte: schritte, zielGemeinsamWocheAenderungen: Self.ziel140k).first { $0.montag == montag }!
        XCTAssertFalse(woche.abgeschlossen)
        XCTAssertNil(woche.duellSieger, "kein Ergebnis, solange die Woche noch läuft")
    }

    // MARK: - Gemeinsam Woche

    func testGemeinsamWocheErreichtAmTagDesUeberschreitens() {
        let montag = "2026-09-21"
        let tage = (0..<7).map { Datum.addTage(montag, $0) }
        // 20.000/Tag pro Person = 40.000 gemeinsam/Tag -> nach 4 Tagen (160.000) über dem Ziel 140.000.
        let schritte = tage.flatMap { tag in
            [TagesEintrag(seq: 1, von: Person.ahmed, datum: tag, gesendetAm: tag, wert: 20_000),
             TagesEintrag(seq: 1, von: Person.annika, datum: tag, gesendetAm: tag, wert: 20_000)]
        }
        let woche = ChallengeLogik.wochen(heute: "2026-09-27", schritte: schritte, zielGemeinsamWocheAenderungen: Self.ziel140k).first { $0.montag == montag }!
        XCTAssertEqual(woche.gemeinsamErreichtAm, "2026-09-24", "am 4. Tag (24.) wird die 140.000 zuerst überschritten")
    }

    func testGemeinsamWocheNichtErreicht() {
        let montag = "2026-09-21"
        let schritte = [TagesEintrag(seq: 1, von: Person.ahmed, datum: montag, gesendetAm: montag, wert: 5000)]
        let woche = ChallengeLogik.wochen(heute: "2026-09-28", schritte: schritte, zielGemeinsamWocheAenderungen: Self.ziel140k).first { $0.montag == montag }!
        XCTAssertNil(woche.gemeinsamErreichtAm)
    }

    /// Eine heute gesendete Zieländerung darf eine VERGANGENE, schon abgeschlossene Woche nicht neu
    /// bewerten (sonst würde `stand` rückwirkend fallen und ein akzeptierter `BesitzLogik`-Kauf
    /// könnte rückwirkend ungültig werden).
    func testZielGemeinsamWocheAenderungWirktNichtRueckwirkend() {
        let vergangeneWoche = "2026-09-14" // Montag
        let tage = (0..<7).map { Datum.addTage(vergangeneWoche, $0) }
        // 21.000/Tag gemeinsam -> 147.000 in der Woche: über dem ALTEN Ziel 140.000, unter einem
        // später (heute) gesetzten höheren Ziel 200.000.
        let schritte = tage.flatMap { tag in
            [TagesEintrag(seq: 1, von: Person.ahmed, datum: tag, gesendetAm: tag, wert: 10_500),
             TagesEintrag(seq: 1, von: Person.annika, datum: tag, gesendetAm: tag, wert: 10_500)]
        }
        let aenderungen = [
            ZielAenderung(seq: 1, datum: "2000-01-01", wert: 140_000),
            ZielAenderung(seq: 2, datum: "2026-09-23", wert: 200_000), // erst danach geändert
        ]
        let woche = ChallengeLogik.wochen(heute: "2026-09-25", schritte: schritte, zielGemeinsamWocheAenderungen: aenderungen).first { $0.montag == vergangeneWoche }!
        XCTAssertEqual(woche.gemeinsamZiel, 140_000, "für die vergangene Woche galt noch das alte Ziel")
        XCTAssertNotNil(woche.gemeinsamErreichtAm)
    }

    // MARK: - Gemeinsam Monat

    func testGemeinsamMonatFesteSchwelle() {
        XCTAssertEqual(ChallengeLogik.zielGemeinsamMonat, 600_000)
    }

    func testGemeinsamMonatErreicht() {
        let tage = (1...20).map { String(format: "2026-09-%02d", $0) }
        let schritte = tage.flatMap { tag in
            [TagesEintrag(seq: 1, von: Person.ahmed, datum: tag, gesendetAm: tag, wert: 16_000),
             TagesEintrag(seq: 1, von: Person.annika, datum: tag, gesendetAm: tag, wert: 16_000)]
        }
        let monat = ChallengeLogik.monate(heute: "2026-09-23", schritte: schritte).first { $0.monat == "2026-09" }!
        // 20 Tage * 32.000 = 640.000, über 600.000 spätestens am 19. Tag (608.000).
        XCTAssertNotNil(monat.gemeinsamErreichtAm)
        XCTAssertTrue(monat.gemeinsamErreichtAm! <= "2026-09-23")
    }

    // MARK: - Serien (Spec 4.1: 3/7/14/30 Tage am Stück)

    func testSerieVergibtJedenMeilensteinEinmalProLauf() {
        let start = "2026-08-01"
        let tage = (0..<10).map { Datum.addTage(start, $0) }
        let schritte = tage.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 10_000) }
        let boni = ChallengeLogik.serienBoni(heute: "2026-08-10", schritte: schritte, zielSchritte: [:])
        XCTAssertEqual(boni.map(\.laenge).sorted(), [3, 7], "10 Tage am Stück: Meilensteine 3 und 7 sind erreicht, 14 noch nicht")
        XCTAssertEqual(boni.reduce(0) { $0 + $1.punkte }, 130)
    }

    func testSerieBrichtBeiLueckeAbUndKannErneutStarten() {
        let boniQuelle: [TagesEintrag<Int>] = [
            TagesEintrag(seq: 1, von: .ahmed, datum: "2026-08-01", gesendetAm: "2026-08-01", wert: 10_000),
            TagesEintrag(seq: 1, von: .ahmed, datum: "2026-08-02", gesendetAm: "2026-08-02", wert: 10_000),
            TagesEintrag(seq: 1, von: .ahmed, datum: "2026-08-03", gesendetAm: "2026-08-03", wert: 10_000),
            // 04./05.: Lücke (keine Daten)
            TagesEintrag(seq: 1, von: .ahmed, datum: "2026-08-06", gesendetAm: "2026-08-06", wert: 10_000),
            TagesEintrag(seq: 1, von: .ahmed, datum: "2026-08-07", gesendetAm: "2026-08-07", wert: 10_000),
            TagesEintrag(seq: 1, von: .ahmed, datum: "2026-08-08", gesendetAm: "2026-08-08", wert: 10_000),
        ]
        let boni = ChallengeLogik.serienBoni(heute: "2026-08-08", schritte: boniQuelle, zielSchritte: [:])
        XCTAssertEqual(boni.map(\.laenge), [3, 3], "zwei getrennte 3er-Läufe geben beide +30")
    }

    func testLaufendeSerieZaehltRueckwaertsAbHeute() {
        let tage = ["2026-08-06", "2026-08-07", "2026-08-08"]
        let schritte = tage.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 10_000) }
        let laufend = ChallengeLogik.laufendeSerie(heute: "2026-08-08", schritte: schritte, zielSchritte: [:])
        XCTAssertEqual(laufend[.ahmed], 3)
        XCTAssertEqual(laufend[.annika], 0)
    }

    func testLaufendeSerieIstNullWennHeuteNichtsZaehlt() {
        let schritte = [TagesEintrag(seq: 1, von: Person.ahmed, datum: "2026-08-07", gesendetAm: "2026-08-07", wert: 10_000)]
        let laufend = ChallengeLogik.laufendeSerie(heute: "2026-08-08", schritte: schritte, zielSchritte: [:])
        XCTAssertEqual(laufend[.ahmed], 0, "gestern zählt nicht mehr, wenn heute noch nichts vorliegt")
    }

    // MARK: - Review-Fokus 2: nachgetragene Schritte zählen für keine Challenge

    func testNachgetrageneTageNichtImDuellUndNichtGemeinsam() {
        let montag = "2026-07-06"
        let tage = (0..<7).map { Datum.addTage(montag, $0) }
        var schritte = tage.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: "2026-09-23", wert: 30_000, nachgetragen: true) }
        schritte += tage.map { TagesEintrag(seq: 1, von: Person.annika, datum: $0, gesendetAm: $0, wert: 5000) }
        let heute = "2026-09-23"

        let woche = ChallengeLogik.wochen(heute: heute, schritte: schritte, zielGemeinsamWocheAenderungen: Self.ziel140k).first { $0.montag == montag }!
        XCTAssertEqual(woche.schritteDuell[.ahmed], 0, "kein gemeinsamer Tag mit echten Werten")
        XCTAssertNil(woche.duellSieger)
        XCTAssertEqual(woche.schritteGesamt, 35_000, "nur Annikas echte Schritte")
        XCTAssertNil(woche.gemeinsamErreichtAm)

        XCTAssertEqual(ChallengeLogik.monate(heute: heute, schritte: schritte).first { $0.monat == "2026-07" }?.schritteGesamt, 35_000)
        XCTAssertTrue(ChallengeLogik.serienBoni(heute: heute, schritte: schritte, zielSchritte: [:]).filter { $0.von == .ahmed }.isEmpty)
    }

    func testLaufendeSerieOhneNachgetrageneTage() {
        let schritte = [
            TagesEintrag(seq: 1, von: Person.ahmed, datum: "2026-08-07", gesendetAm: "2026-09-23", wert: 12_000, nachgetragen: true),
            TagesEintrag(seq: 1, von: Person.ahmed, datum: "2026-08-08", gesendetAm: "2026-08-08", wert: 12_000),
        ]
        XCTAssertEqual(ChallengeLogik.laufendeSerie(heute: "2026-08-08", schritte: schritte, zielSchritte: [:])[.ahmed], 1)
    }

    // MARK: - Gesamt-Bonus

    func testPunkteBonusSummiertAlleAbgeschlossenenChallenges() {
        let woche = ChallengeLogik.WochenErgebnis(
            montag: "2026-09-21", sonntag: "2026-09-27", abgeschlossen: true,
            schritteDuell: [.ahmed: 60_000, .annika: 50_000], duellSieger: .ahmed,
            schritteGesamt: 150_000, gemeinsamZiel: 140_000, gemeinsamErreichtAm: "2026-09-25"
        )
        let monat = ChallengeLogik.MonatsErgebnis(monat: "2026-09", schritteGesamt: 610_000, gemeinsamErreichtAm: "2026-09-22")
        let serien = [ChallengeLogik.SerienBonus(von: .ahmed, datum: "2026-09-23", laenge: 3, punkte: 30)]

        let bonus = ChallengeLogik.punkteBonus(wochen: [woche], monate: [monat], serien: serien)

        XCTAssertEqual(bonus[.ahmed], 150 /* Duell */ + 150 /* gemeinsam Woche */ + 500 /* gemeinsam Monat */ + 30 /* Serie */)
        XCTAssertEqual(bonus[.annika], 150 + 500)
    }
}
