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

    // MARK: - Final-Review I-2: bestätigtes Echo eigener Ops

    func testEchoEigenerOpBekommtSeqUndWidgetAbhakenGewinnt() {
        var gym: [Person: [String: TagesEintrag<Int>]] = [:]
        let tag = "2026-09-23"
        // Morgens in der App abgehakt: erst optimistisch (seq nil), dann das bestätigte Echo.
        HealthFaltung.aufnehmen(&gym, TagesEintrag(seq: nil, von: .ahmed, datum: tag, gesendetAm: tag, wert: 1, id: "app"))
        HealthFaltung.aufnehmen(&gym, TagesEintrag(seq: 500, von: .ahmed, datum: tag, gesendetAm: tag, wert: 1, id: "app"))
        XCTAssertEqual(gym[.ahmed]?[tag]?.seq, 500, "das Echo ersetzt die optimistische Kopie")
        // Abends übers Widget wieder weg (POST /ops, seq 900) — muss auf diesem Gerät ankommen.
        HealthFaltung.aufnehmen(&gym, TagesEintrag(seq: 900, von: .ahmed, datum: tag, gesendetAm: tag, wert: 0, id: "widget"))
        XCTAssertEqual(gym[.ahmed]?[tag]?.wert, 0)
        // Der Widget-Merge reiht dieselbe Op später nochmal ein (seq nil): die bekannte seq bleibt.
        HealthFaltung.aufnehmen(&gym, TagesEintrag(seq: nil, von: .ahmed, datum: tag, gesendetAm: tag, wert: 0, id: "widget"))
        XCTAssertEqual(gym[.ahmed]?[tag]?.seq, 900)
        // Ein älteres, spät angekommenes Op verliert weiter.
        HealthFaltung.aufnehmen(&gym, TagesEintrag(seq: 400, von: .ahmed, datum: tag, gesendetAm: tag, wert: 1, id: "alt"))
        XCTAssertEqual(gym[.ahmed]?[tag]?.wert, 0)
    }

    func testZweiteZielAenderungAmSelbenTagGilt() {
        var ziele: [ZielAenderung] = []
        let tag = "2026-09-23"
        HealthLogik.zielAufnehmen(&ziele, ZielAenderung(seq: nil, datum: tag, wert: 12_000, id: "a"))
        HealthLogik.zielAufnehmen(&ziele, ZielAenderung(seq: nil, datum: tag, wert: 15_000, id: "b"))
        XCTAssertEqual(HealthLogik.zielAmTag(tag, ziele, standard: 10_000), 15_000, "beide unbestätigt: die spätere gilt")
        HealthLogik.zielAufnehmen(&ziele, ZielAenderung(seq: 10, datum: tag, wert: 12_000, id: "a"))
        XCTAssertEqual(HealthLogik.zielAmTag(tag, ziele, standard: 10_000), 15_000)
        HealthLogik.zielAufnehmen(&ziele, ZielAenderung(seq: 11, datum: tag, wert: 15_000, id: "b"))
        XCTAssertEqual(ziele.count, 2, "Echos ersetzen, statt anzuhängen")
        XCTAssertEqual(HealthLogik.zielAmTag(tag, ziele, standard: 10_000), 15_000, "wie auf dem Partnergerät")
    }

    // MARK: - Ansichten

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

    // MARK: - Einmaliges Nachtragen (Z-36.1, Review-Fokus 2)

    func testNachtragAuswahlUeberspringtVorhandeneTage() {
        let heute = "2026-09-23"
        let vorhanden: Set<String> = ["2026-09-10", "2026-08-01"]
        let tage = HealthLogik.nachtragTage(heute: heute, vorhanden: vorhanden)
        XCTAssertFalse(tage.contains("2026-09-10"), "schon ein Wert: nie überschreiben")
        XCTAssertFalse(tage.contains("2026-08-01"))
        XCTAssertEqual(tage.count, 82 - 2)
        XCTAssertEqual(tage.first, "2026-09-15", "heute und die 7 Tage davor sendet der Live-Weg ungekennzeichnet")
        XCTAssertEqual(tage.last, Datum.addTage(heute, -89), "90 Tage zusammen mit dem Live-Fenster")
    }

    /// 25.10.2026: Zeitumstellung — jeder Kalendertag genau einmal, keiner fehlt.
    func testNachtragTageUeberDieZeitumstellung() {
        let tage = HealthLogik.nachtragTage(heute: "2026-11-15", vorhanden: [])
        XCTAssertEqual(tage.count, 82)
        XCTAssertEqual(Set(tage).count, 82)
        for tag in ["2026-10-24", "2026-10-25", "2026-10-26"] { XCTAssertTrue(tage.contains(tag), tag) }
    }

    func testNachgetragenerTagZaehltErstMitEchtemWert() {
        let tag = "2026-08-01"
        let nachtrag = TagesEintrag(seq: 10, von: Person.ahmed, datum: tag, gesendetAm: "2026-09-23", wert: 7000, nachgetragen: true)
        XCTAssertNil(HealthFaltung.punktefaehig([nachtrag])[.ahmed]?[tag], "nur Anzeige")
        XCTAssertEqual(HealthFaltung.gefaltet([nachtrag])[.ahmed]?[tag]?.wert, 7000, "die Anzeige sieht ihn")
        let echt = TagesEintrag(seq: 11, von: Person.ahmed, datum: tag, gesendetAm: "2026-09-23", wert: 7100)
        XCTAssertEqual(HealthFaltung.punktefaehig([nachtrag, echt])[.ahmed]?[tag]?.wert, 7100, "späterer echter Wert gewinnt und zählt")
        let aelterEcht = TagesEintrag(seq: 5, von: Person.ahmed, datum: tag, gesendetAm: tag, wert: 9000)
        XCTAssertNil(HealthFaltung.punktefaehig([aelterEcht, nachtrag])[.ahmed]?[tag], "erst falten, dann filtern: kein älterer Wert schlüpft durch")
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

    // MARK: - Final-Review I-4: eine Nacht pro Aufwach-Tag

    private func intervall(_ tagVon: Int, _ stundeVon: Int, _ tagBis: Int, _ stundeBis: Int) -> HealthLogik.SchlafIntervall {
        HealthLogik.SchlafIntervall(
            von: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tagVon, hour: stundeVon))!,
            bis: Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tagBis, hour: stundeBis))!
        )
    }

    func testSchlafNachtZaehltDieVornachtNichtMit() {
        // So 23–Mo 07 und Mo 23–Di 07, beide im großzügigen HealthKit-Fenster für Dienstag.
        let intervalle = [intervall(20, 23, 21, 7), intervall(21, 23, 22, 7)]
        let dienstag = HealthLogik.schlafNacht(intervalle, tag: "2026-09-22")
        XCTAssertEqual(dienstag?.minuten, 8 * 60, "nur die eine Nacht, nicht 16 h")
        XCTAssertEqual(dienstag?.von, intervall(21, 23, 22, 7).von)
        XCTAssertEqual(HealthLogik.schlafNacht(intervalle, tag: "2026-09-21")?.von, intervall(20, 23, 21, 7).von, "die Vornacht gehört zum Montag")
    }

    func testSchlafNachtIgnoriertMittagsschlafUndHaeltKurzesAufwachen() {
        let nacht = [intervall(21, 23, 22, 3), intervall(22, 4, 22, 7)] // eine Stunde wach um 3
        let nickerchen = intervall(22, 14, 22, 15)
        let ergebnis = HealthLogik.schlafNacht(nacht + [nickerchen], tag: "2026-09-22")
        XCTAssertEqual(ergebnis?.minuten, 7 * 60, "Wachphase nicht gezählt, Nickerchen nicht dazu")
        XCTAssertEqual(ergebnis?.bis, intervall(22, 4, 22, 7).bis, "Aufwachen bleibt 07:00, nicht 15:00")
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
