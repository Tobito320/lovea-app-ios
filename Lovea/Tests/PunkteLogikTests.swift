import XCTest
@testable import Lovea

final class PunkteLogikTests: XCTestCase {

    // MARK: - Richtwert (Spec 4.1): sanity check for the whole formula at once

    /// "10.000 Schritte täglich, 3× Gym, Wasser meist geschafft ≈ 1.100 Punkte pro Woche."
    func testRichtwertZehntausendSchritteWoche() {
        let woche = ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27"]
        let schritte = woche.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 10_000) }
        let gym = woche.prefix(3).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 1) }
        let wasser = woche.prefix(6).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 8) }
        let streak = Set(woche)

        let stand = PunkteLogik.stand(
            heute: "2026-09-27", schritte: schritte, gym: Array(gym), wasser: Array(wasser),
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: streak, spieleSiege: []
        )

        // 7*(100 Schritt-Punkte + 20 Tagesziel) + 3*40 Gym + 80 Wochenziel + 6*10 Wasser + 7*5 Streak
        // = 840 + 120 + 80 + 60 + 35 = 1135
        XCTAssertEqual(stand[.ahmed], 1135)
    }

    /// "Mit 15.000-Tagen ≈ 1.700."
    func testRichtwertFuenfzehntausendSchritteWoche() {
        let woche = ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27"]
        let schritte = woche.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 15_000) }
        let gym = woche.prefix(3).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 1) }
        let wasser = woche.prefix(6).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 8) }

        let stand = PunkteLogik.stand(
            heute: "2026-09-27", schritte: schritte, gym: Array(gym), wasser: Array(wasser),
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: Set(woche), spieleSiege: []
        )

        // 7*(150 + 20 + 30) + 120 + 80 + 60 + 35 = 1400 + 120 + 80 + 60 + 35 = 1695
        XCTAssertEqual(stand[.ahmed], 1695)
    }

    // MARK: - 300er Deckel

    func testSchrittPunkteGedeckeltBei300() {
        let punkte = PunkteLogik.tagesPunkte(schritte: 40_000, zielSchritte: 10_000, gymAbgehakt: false, wasser: 0, zielWasser: 8, chatStreakTag: false, spieleGewonnen: 0)
        // Deckel 300 + 20 (Ziel) + 30 (ab 15k) = 350, nicht 400+20+30
        XCTAssertEqual(punkte, 350)
    }

    // MARK: - Review-Fokus 2: dieselbe Op zweimal / ein Tag mehrfach gesetzt

    func testDuplikatOderMehrfachesSetzenZaehltNurEinmal() {
        let ohneDuplikat = PunkteLogik.stand(
            heute: "2026-09-23",
            schritte: [TagesEintrag(seq: 3, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 5000)],
            gym: [], wasser: [], zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        let mitDuplikatUndFalscherReihenfolge = PunkteLogik.stand(
            heute: "2026-09-23",
            schritte: [
                TagesEintrag(seq: 3, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 5000),
                TagesEintrag(seq: 1, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 9999), // älter, kommt aber zuletzt im Array an
            ],
            gym: [], wasser: [], zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertEqual(ohneDuplikat, mitDuplikatUndFalscherReihenfolge, "der höhere seq gewinnt, unabhängig von der Ankunftsreihenfolge")
    }

    // MARK: - Nachträgliche Gym-Tage (Spec 4.1: nur bis 7 Tage zurück)

    func testGymNachtraeglichInnerhalbVonSiebenTagenZaehlt() {
        let stand = PunkteLogik.stand(
            heute: "2026-09-23",
            schritte: [],
            gym: [TagesEintrag(seq: 1, von: .ahmed, datum: "2026-09-17", gesendetAm: "2026-09-23", wert: 1)], // 6 Tage später markiert
            wasser: [], zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertEqual(stand[.ahmed], 40)
    }

    /// Die 7-Tage-Regel gilt für den GEWINNER der Faltung (höchster seq), nicht für jede Roh-Op für
    /// sich: ein spätes Zurücknehmen (Op selbst >7 Tage nach `datum` gesendet) muss trotzdem
    /// gewinnen und darf nicht dazu führen, dass das frühere Abhaken fälschlich stehen bleibt.
    func testSpaetesZuruecknehmenGewinntAuchWennEsSelbstIneligibelIst() {
        let stand = PunkteLogik.stand(
            heute: "2026-09-23",
            schritte: [],
            gym: [
                TagesEintrag(seq: 1, von: .ahmed, datum: "2026-09-10", gesendetAm: "2026-09-10", wert: 1),
                TagesEintrag(seq: 2, von: .ahmed, datum: "2026-09-10", gesendetAm: "2026-09-20", wert: 0),
            ],
            wasser: [], zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertNil(stand[.ahmed], "zurückgenommen, keine Punkte")
    }

    func testGymNachtraeglichNachSiebenTagenZaehltNicht() {
        let stand = PunkteLogik.stand(
            heute: "2026-09-23",
            schritte: [],
            gym: [TagesEintrag(seq: 1, von: .ahmed, datum: "2026-09-10", gesendetAm: "2026-09-23", wert: 1)], // 13 Tage später
            wasser: [], zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertNil(stand[.ahmed], "keine Punkte, aber (anderswo) grün im Verlauf")
    }

    // MARK: - Review-Fokus 4: Tag ohne Health-Daten ist kein Nachteil

    func testTagOhneSchritteDatenGibtEinfachKeineSchrittPunkte() {
        let punkte = PunkteLogik.tagesPunkte(schritte: nil, zielSchritte: 10_000, gymAbgehakt: true, wasser: 8, zielWasser: 8, chatStreakTag: false, spieleGewonnen: 0)
        XCTAssertEqual(punkte, 50, "nur Gym (40) + Wasser (10), keine 0-Schritte-Strafe")
    }

    // MARK: - Ziele ändern wirkt nicht rückwirkend

    func testGeaenderteZieleWirkenNichtAufVergangeneTage() {
        let schritte = [TagesEintrag(seq: 1, von: Person.ahmed, datum: "2026-09-20", gesendetAm: "2026-09-20", wert: 9000)]
        let zielAenderung = [Person.ahmed: [ZielAenderung(seq: 5, datum: "2026-09-23", wert: 8000)]] // Ziel erst ab dem 23. gesenkt

        let stand = PunkteLogik.stand(
            heute: "2026-09-23", schritte: schritte, gym: [], wasser: [],
            zielSchritte: zielAenderung, zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        // 9000/100 = 90 Schritt-Punkte, aber KEIN Zielbonus, weil am 20. noch 10.000 galten
        XCTAssertEqual(stand[.ahmed], 90)
    }

    // MARK: - Spiele gewonnen

    func testGewonneneSpieleZaehlenZehnPunkteJeSieg() {
        let punkte = PunkteLogik.tagesPunkte(schritte: nil, zielSchritte: 10_000, gymAbgehakt: false, wasser: 0, zielWasser: 8, chatStreakTag: false, spieleGewonnen: 2)
        XCTAssertEqual(punkte, 20)
    }

    /// Ein Sieg an einem Tag OHNE jede andere Aktivität (keine Schritte-Daten, kein Streak, kein
    /// Gym/Wasser) darf nicht verloren gehen, nur weil kein anderer Datenpunkt diesen Tag in die
    /// Verlaufs-Menge einbringt.
    func testGewonnenesSpielAnEinemSonstLeerenTagZaehltImStand() {
        let stand = PunkteLogik.stand(
            heute: "2026-09-23", schritte: [], gym: [], wasser: [],
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [],
            spieleSiege: [PunkteLogik.SpielSieg(von: .annika, datum: "2026-09-23")]
        )
        XCTAssertEqual(stand[.annika], 10)
    }
}
