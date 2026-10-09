import XCTest
@testable import Lovea

final class PunkteLogikTests: XCTestCase {

    // MARK: - Richtwert (Spec 4.1): sanity check for the whole formula at once

    /// "10.000 Schritte täglich, 3× Gym, Wasser meist geschafft ≈ 1.100 Punkte pro Woche."
    /// (Eine Woche vor dem Streak-Ende am 24.09.2026, damit die +5 noch zählen.)
    func testRichtwertZehntausendSchritteWoche() {
        let woche = ["2026-09-14", "2026-09-15", "2026-09-16", "2026-09-17", "2026-09-18", "2026-09-19", "2026-09-20"]
        let schritte = woche.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 10_000) }
        let gym = woche.prefix(3).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 1) }
        let wasser = woche.prefix(6).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 8) }
        let streak = Set(woche)

        let stand = PunkteLogik.stand(
            heute: "2026-09-20", schritte: schritte, gym: Array(gym), wasser: Array(wasser),
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: streak, spieleSiege: []
        )

        // 7*(100 Schritt-Punkte + 20 Tagesziel) + 3*40 Gym + 80 Wochenziel + 6*10 Wasser + 7*5 Streak
        // = 840 + 120 + 80 + 60 + 35 = 1135
        XCTAssertEqual(stand[.ahmed], 1135)
    }

    /// "Mit 15.000-Tagen ≈ 1.700." Seit dem 24.09.2026 ohne Chat-Streak: 35 weniger.
    func testRichtwertFuenfzehntausendSchritteWoche() {
        let woche = ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"]
        let schritte = woche.map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 15_000) }
        let gym = woche.prefix(3).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 1) }
        let wasser = woche.prefix(6).map { TagesEintrag(seq: 1, von: Person.ahmed, datum: $0, gesendetAm: $0, wert: 8) }

        let stand = PunkteLogik.stand(
            heute: "2026-10-04", schritte: schritte, gym: Array(gym), wasser: Array(wasser),
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: Set(woche), spieleSiege: []
        )

        // 7*(150 + 20 + 30) + 120 + 80 + 60 = 1400 + 120 + 80 + 60 = 1660
        XCTAssertEqual(stand[.ahmed], 1660)
    }

    // MARK: - "Woraus bestehen die Punkte?" (Controller-Nachtrag): eine Zeile pro Quelle

    func testTagesZeilenJeQuelleErgebenDieAlteTagessumme() {
        let tag = "2026-09-22"
        let stand = PunkteLogik.verlauf(
            heute: tag,
            schritte: [TagesEintrag(seq: 1, von: .ahmed, datum: tag, gesendetAm: tag, wert: 16_000)],
            gym: [TagesEintrag(seq: 1, von: .ahmed, datum: tag, gesendetAm: tag, wert: 1)],
            wasser: [TagesEintrag(seq: 1, von: .ahmed, datum: tag, gesendetAm: tag, wert: 8)],
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [tag],
            spieleSiege: [PunkteLogik.SpielSieg(von: .ahmed, datum: tag), PunkteLogik.SpielSieg(von: .ahmed, datum: tag)]
        )
        let ahmed = stand.filter { $0.von == .ahmed }
        let punkte = Dictionary(uniqueKeysWithValues: ahmed.map { ($0.grund, $0.punkte) })
        XCTAssertEqual(punkte, ["Schritte": 160, "Schrittziel": 20, "15.000 Schritte": 30, "Gym": 40, "Wasserziel": 10, "Chat-Streak": 5, "Spiel gewonnen": 20])
        let alteTagessumme = PunkteLogik.tagesPunkte(schritte: 16_000, zielSchritte: 10_000, gymAbgehakt: true, wasser: 8, zielWasser: 8, chatStreakTag: true, spieleGewonnen: 2)
        XCTAssertEqual(ahmed.reduce(0) { $0 + $1.punkte }, alteTagessumme)
        XCTAssertEqual(alteTagessumme, 285)
        XCTAssertEqual(stand.filter { $0.von == .annika }.map(\.grund), ["Chat-Streak"], "keine Null-Zeilen")
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

    /// Jede Habit kann jetzt vergangene Tage markieren (Z-35.3): spät nachgetragenes Wasser gibt wie
    /// Gym nach 7 Tagen keine Punkte mehr.
    func testWasserNachtraeglichNurInnerhalbVonSiebenTagen() {
        let stand = PunkteLogik.stand(
            heute: "2026-09-23", schritte: [], gym: [],
            wasser: [
                TagesEintrag(seq: 1, von: .ahmed, datum: "2026-09-17", gesendetAm: "2026-09-23", wert: 8),
                TagesEintrag(seq: 2, von: .ahmed, datum: "2026-09-10", gesendetAm: "2026-09-23", wert: 8),
            ],
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertEqual(stand[.ahmed], 10, "nur der 17.")
    }

    // MARK: - Review-Fokus 2: nachgetragene Schritte

    func testNachgetrageneSchritteGebenKeinePunkte() {
        let nachtrag = TagesEintrag(seq: 50, von: Person.ahmed, datum: "2026-07-01", gesendetAm: "2026-09-23", wert: 16_000, nachgetragen: true)
        let ohne = PunkteLogik.stand(
            heute: "2026-09-23", schritte: [nachtrag], gym: [], wasser: [],
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertNil(ohne[.ahmed], "0 Punkte, nur Anzeige")
        XCTAssertTrue(PunkteLogik.verlauf(
            heute: "2026-09-23", schritte: [nachtrag], gym: [], wasser: [],
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        ).isEmpty, "keine Zeile in \"Wofür?\"")

        // Kommt später ein echter Wert für denselben Tag (höhere seq), zählt der ganz normal.
        let echt = TagesEintrag(seq: 60, von: Person.ahmed, datum: "2026-07-01", gesendetAm: "2026-07-01", wert: 10_000)
        let mitEcht = PunkteLogik.stand(
            heute: "2026-09-23", schritte: [nachtrag, echt], gym: [], wasser: [],
            zielSchritte: [:], zielWasser: [:], zielGym: [:], chatStreakTage: [], spieleSiege: []
        )
        XCTAssertEqual(mitEcht[.ahmed], 120)
    }

    // MARK: - Review-Fokus 3: Chat-Streak endet am 24.09.2026

    func testChatStreakPunkteNurVorDemStichtag() {
        let stand = PunkteLogik.stand(
            heute: "2026-09-30", schritte: [], gym: [], wasser: [],
            zielSchritte: [:], zielWasser: [:], zielGym: [:],
            chatStreakTage: ["2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25"], spieleSiege: []
        )
        XCTAssertEqual(stand[.ahmed], 10, "22. und 23. bleiben, ab dem 24. nichts")
        XCTAssertEqual(stand[.annika], 10)
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

    /// Minor 4: Runde 2 kommt vor Runde 1 an, und beide Handys melden Runde 1 — trotzdem genau
    /// ein Sieg pro Runde, egal in welcher Reihenfolge.
    func testSpieleSiegeUnabhaengigVonAnkunftsreihenfolge() {
        let r1 = PunkteLogik.SpielStand(spiel: "s", gespielt: 1, ahmed: 1, annika: 0, datum: "2026-09-22", seq: 10, opId: "a")
        let r1Doppelt = PunkteLogik.SpielStand(spiel: "s", gespielt: 1, ahmed: 1, annika: 0, datum: "2026-09-22", seq: 11, opId: "b")
        let r2 = PunkteLogik.SpielStand(spiel: "s", gespielt: 2, ahmed: 1, annika: 1, datum: "2026-09-23", seq: 12, opId: "c")
        for reihenfolge in [[r1, r1Doppelt, r2], [r2, r1Doppelt, r1]] {
            let siege = PunkteLogik.spieleSiege(reihenfolge)
            XCTAssertEqual(siege.count, 2)
            XCTAssertEqual(siege.filter { $0.von == .ahmed }.map(\.datum), ["2026-09-22"])
            XCTAssertEqual(siege.filter { $0.von == .annika }.map(\.datum), ["2026-09-23"])
        }
    }
}
