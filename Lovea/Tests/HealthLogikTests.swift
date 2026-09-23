import XCTest
@testable import Lovea

final class HealthLogikTests: XCTestCase {

    // MARK: - Ziel-Historie

    func testZielAmTagNimmtDenWertVorDemStichtag() {
        let aenderungen = [
            ZielAenderung(seq: 1, datum: "2026-09-01", wert: 8000),
            ZielAenderung(seq: 2, datum: "2026-09-15", wert: 12000),
        ]
        XCTAssertEqual(HealthLogik.zielAmTag("2026-09-10", aenderungen, standard: 10_000), 8000)
        XCTAssertEqual(HealthLogik.zielAmTag("2026-09-20", aenderungen, standard: 10_000), 12_000)
        XCTAssertEqual(HealthLogik.zielAmTag("2026-08-01", aenderungen, standard: 10_000), 10_000, "vor jeder Änderung gilt der Standard")
    }

    func testZielAmTagAendertNichtRueckwirkend() {
        // Z-21.2: eine heutige Änderung darf einen früheren Tag nicht neu bewerten.
        let aenderungen = [ZielAenderung(seq: 1, datum: "2026-09-23", wert: 5000)]
        XCTAssertEqual(HealthLogik.zielAmTag("2026-09-22", aenderungen, standard: 10_000), 10_000)
    }

    // MARK: - Stufen (Spec 3.2)

    func testGymStufeWochenzielGeschafft() {
        XCTAssertEqual(HealthLogik.gymStufe(heuteAbgehakt: true, erledigtInWoche: 3, ziel: 3, wochentag: 4), 3)
    }

    func testGymStufeAufKurs() {
        // Donnerstag (4/7 der Woche), Ziel 3: fällig wären ceil(3*4/7) = 2 Tage.
        XCTAssertEqual(HealthLogik.gymStufe(heuteAbgehakt: true, erledigtInWoche: 2, ziel: 3, wochentag: 4), 2)
    }

    func testGymStufeNurHeuteAbgehaktAberNichtAufKurs() {
        // Sonntag, nur der heutige Tag erledigt, Wochenziel 3 -> klar hinter der Pace.
        XCTAssertEqual(HealthLogik.gymStufe(heuteAbgehakt: true, erledigtInWoche: 1, ziel: 3, wochentag: 7), 1)
    }

    func testGymStufeNichts() {
        XCTAssertEqual(HealthLogik.gymStufe(heuteAbgehakt: false, erledigtInWoche: 0, ziel: 3, wochentag: 1), 0)
    }

    func testWasserStufen() {
        XCTAssertEqual(HealthLogik.wasserStufe(glaeser: 0, ziel: 8), 0)
        XCTAssertEqual(HealthLogik.wasserStufe(glaeser: 3, ziel: 8), 1, "unter 50 %")
        XCTAssertEqual(HealthLogik.wasserStufe(glaeser: 4, ziel: 8), 2, "genau 50 %")
        XCTAssertEqual(HealthLogik.wasserStufe(glaeser: 8, ziel: 8), 3)
        XCTAssertEqual(HealthLogik.wasserStufe(glaeser: 12, ziel: 8), 3, "über dem Ziel bleibt Stufe 3")
    }

    // MARK: - Ansichten

    func testWocheTageMontagBisSonntag() {
        XCTAssertEqual(HealthLogik.wocheTage("2026-09-23"), ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27"])
    }

    func testMonatsGitterAktuellerMonat() {
        let zellen = HealthLogik.monatsGitter(heute: "2026-09-23", monateZurueck: 0)
        let tage = zellen.compactMap { $0 }
        XCTAssertEqual(tage.first, "2026-09-01")
        XCTAssertEqual(tage.last, "2026-09-30")
        XCTAssertEqual(tage.count, 30)
        XCTAssertEqual(zellen.count % 7, 0, "volle Wochenzeilen, mit Füllzellen aufgefüllt")
    }

    func testMonatsGitterEinenMonatZurueck() {
        let zellen = HealthLogik.monatsGitter(heute: "2026-09-23", monateZurueck: 1)
        let tage = zellen.compactMap { $0 }
        XCTAssertEqual(tage.first, "2026-08-01")
        XCTAssertEqual(tage.last, "2026-08-31")
    }

    func testMonatsGitterKlemmtNieInDieZukunft() {
        let vorwaerts = HealthLogik.monatsGitter(heute: "2026-09-23", monateZurueck: -3)
        let aktuell = HealthLogik.monatsGitter(heute: "2026-09-23", monateZurueck: 0)
        XCTAssertEqual(vorwaerts, aktuell)
    }

    func testJahresGitterEndetHeuteUndGehtNieInDieZukunft() {
        let tage = HealthLogik.jahresGitter(heute: "2026-09-23")
        XCTAssertEqual(tage.last, "2026-09-23")
        XCTAssertTrue(tage.allSatisfy { $0 <= "2026-09-23" })
        XCTAssertGreaterThan(tage.count, 300)
    }

    // MARK: - Schlaf

    func testSchlafZusammenfassenMergtUeberlappendeIntervalle() {
        // iPhone und Watch schreiben leicht versetzt dieselbe Nacht.
        let iphone = HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 23, minute: 0))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 6, minute: 0))!
        )
        let watch = HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 23, minute: 30))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 6, minute: 10))!
        )
        let ergebnis = HealthLogik.schlafZusammenfassen([iphone, watch])
        XCTAssertEqual(ergebnis?.minuten, 7 * 60 + 10, "das Overlap darf nicht doppelt gezählt werden")
        XCTAssertEqual(Datum.text(ergebnis!.bis), "2026-09-23", "die Nacht zählt zum Aufwach-Tag")
    }

    func testSchlafZusammenfassenHaeltGetrennteNickerchenGetrennt() {
        let nacht = HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 23, minute: 0))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 6, minute: 0))!
        )
        let mittagsschlaf = HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 13, minute: 0))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 13, minute: 30))!
        )
        let ergebnis = HealthLogik.schlafZusammenfassen([nacht, mittagsschlaf])
        XCTAssertEqual(ergebnis?.minuten, 7 * 60 + 30, "nicht zusammenhängende Intervalle werden trotzdem summiert")
    }

    /// Review-Fokus 1: 25.10.2026 ist die Zeitumstellung (03:00 CEST -> 02:00 CET) — die reale Dauer
    /// zwischen zwei Wanduhrzeiten ist an diesem Tag eine Stunde länger, `schlafZusammenfassen` muss
    /// die echte verstrichene Zeit liefern (Date-Subtraktion), nicht die naive Wanduhr-Differenz.
    func testSchlafZusammenfassenUeberlebtDieZeitumstellung() {
        let intervall = HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 0, minute: 30))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 8, minute: 0))!
        )
        let ergebnis = HealthLogik.schlafZusammenfassen([intervall])
        XCTAssertEqual(ergebnis?.minuten, 8 * 60 + 30, "eine Stunde mehr als die 7:30 Wanduhr-Differenz, wegen der Zeitumstellung")
        XCTAssertEqual(Datum.text(ergebnis!.bis), "2026-10-25")
    }

    // MARK: - Senden nur bei Änderung

    func testSollSchritteSendenErsterWertDesTages() {
        XCTAssertTrue(HealthLogik.sollSchritteSenden(anzahl: 120, zuletzt: nil, heutigerTag: "2026-09-23", vergangen: 0))
    }

    func testSollSchritteSendenNeuerTag() {
        let zuletzt = (datum: "2026-09-22", anzahl: 9000)
        XCTAssertTrue(HealthLogik.sollSchritteSenden(anzahl: 10, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 5))
    }

    func testSollSchritteSendenKleinerSprungWirdGedrosselt() {
        let zuletzt = (datum: "2026-09-23", anzahl: 1000)
        XCTAssertFalse(HealthLogik.sollSchritteSenden(anzahl: 1030, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 60))
    }

    func testSollSchritteSendenSprungAbFuenfzig() {
        let zuletzt = (datum: "2026-09-23", anzahl: 1000)
        XCTAssertTrue(HealthLogik.sollSchritteSenden(anzahl: 1050, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 5))
    }

    func testSollSchritteSendenNachFuenfzehnMinuten() {
        let zuletzt = (datum: "2026-09-23", anzahl: 1000)
        XCTAssertTrue(HealthLogik.sollSchritteSenden(anzahl: 1005, zuletzt: zuletzt, heutigerTag: "2026-09-23", vergangen: 15 * 60))
    }

    // MARK: - HealthFaltung (Review-Fokus 2: höchster seq gewinnt, Ankunftsreihenfolge egal)

    func testHealthFaltungHoechsterSeqGewinntUnabhaengigVonDerReihenfolge() {
        let eintraege = [
            TagesEintrag(seq: 5, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 4000),
            TagesEintrag(seq: 2, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 9999), // älter, kommt aber später an
        ]
        let gefaltet = HealthFaltung.gefaltet(eintraege)
        XCTAssertEqual(gefaltet[.ahmed]?["2026-09-23"]?.wert, 4000)
    }

    func testHealthFaltungUnbestaetigteOpGiltAlsNeuesteInformation() {
        let eintraege = [
            TagesEintrag(seq: 5, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 4000),
            TagesEintrag(seq: nil, von: .ahmed, datum: "2026-09-23", gesendetAm: "2026-09-23", wert: 4500),
        ]
        XCTAssertEqual(HealthFaltung.gefaltet(eintraege)[.ahmed]?["2026-09-23"]?.wert, 4500)
    }
}
