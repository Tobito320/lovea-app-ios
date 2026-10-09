import XCTest
@testable import Lovea

/// Health-Coach: Marker am Ende der Antwort trennen und prüfen (`CoachMarker.swift`). Reine Logik.
final class CoachMarkerTests: XCTestCase {

    private func zerlegt(_ roh: String) -> CoachMarker.Zerlegt { CoachMarker.zerlegen(roh) }

    // MARK: - Text

    func testTextOhneMarkerBleibtGleich() {
        XCTAssertEqual(zerlegt("Hallo du"), CoachMarker.Zerlegt(text: "Hallo du", marker: []))
    }

    func testMarkerAmEndeWerdenAbgeschnitten() {
        let z = zerlegt("Dein Tag war gut.\n[[weiter: Wie war mein Schlaf? | Was esse ich heute? | Training morgen?]]")
        XCTAssertEqual(z.text, "Dein Tag war gut.")
        XCTAssertEqual(z.folgefragen, ["Wie war mein Schlaf?", "Was esse ich heute?", "Training morgen?"])
    }

    func testDoppelteEckigeKlammernOhneMarkerBleibenText() {
        XCTAssertEqual(zerlegt("Siehe [[1]] und [[2]]").text, "Siehe [[1]] und [[2]]")
        XCTAssertEqual(zerlegt("Um [[10:30 Uhr]] los").text, "Um [[10:30 Uhr]] los")
    }

    func testUnbekannterMarkerVerschwindet() {
        let z = zerlegt("Text [[foo: bar]] weiter")
        XCTAssertEqual(z.text, "Text  weiter")
        XCTAssertTrue(z.marker.isEmpty)
    }

    func testAbgeschnittenerMarkerVerschwindet() {
        XCTAssertEqual(zerlegt("Gut gemacht.\n[[weiter: Wie war | Was es").text, "Gut gemacht.")
        XCTAssertEqual(zerlegt("Gut.\n[[wei").text, "Gut.")
    }

    func testHoechstensVierMarker() {
        let roh = "[[gehe: schritte]][[gehe: training]][[gehe: gewicht]][[gehe: verlauf]][[gehe: schritte]]"
        let z = zerlegt(roh)
        XCTAssertEqual(z.text, "")
        XCTAssertEqual(z.wege.map { $0.ziel }, [.schritte, .training, .gewicht, .verlauf])
    }

    // MARK: - weiter

    func testWeiterNimmtHoechstensDreiUndKeineLeeren() {
        let z = zerlegt("[[weiter: A? |  | B? | C? | D?]]")
        XCTAssertEqual(z.folgefragen, ["A?", "B?", "C?"])
    }

    func testWeiterOhneFragenIstKeinMarker() {
        XCTAssertTrue(zerlegt("[[weiter: | ]]").marker.isEmpty)
    }

    // MARK: - chart

    func testChartMitDreiPunkten() {
        let z = zerlegt("[[chart: Schritte | Mo 8200 | Di 9100 | Mi 7,5]]")
        XCTAssertEqual(z.diagramm?.titel, "Schritte")
        XCTAssertEqual(z.diagramm?.punkte, [
            CoachMarker.Punkt(label: "Mo", wert: 8200),
            CoachMarker.Punkt(label: "Di", wert: 9100),
            CoachMarker.Punkt(label: "Mi", wert: 7.5),
        ])
    }

    func testChartMitDatumAlsLabel() {
        let z = zerlegt("[[chart: Schritte | 12.10. 7400 | 13.10. 8100 | 14.10. 6900]]")
        XCTAssertEqual(z.diagramm?.punkte.map(\.label), ["12.10.", "13.10.", "14.10."])
    }

    func testChartMitWenigerAlsDreiPunktenFaelltWeg() {
        XCTAssertTrue(zerlegt("[[chart: T | Mo 1 | Di 2]]").marker.isEmpty)
    }

    func testChartUeberspringtKaputtePunkte() {
        let z = zerlegt("[[chart: T | Mo 1 | Di x | Mi 3 | Do 4]]")
        XCTAssertEqual(z.diagramm?.punkte.map(\.label), ["Mo", "Mi", "Do"])
        XCTAssertTrue(zerlegt("[[chart: T | Mo 1 | Di x | Mi 3]]").marker.isEmpty)
    }

    func testChartNimmtHoechstensAchtPunkte() {
        let punkte = (1...9).map { "T\($0) \($0)" }.joined(separator: " | ")
        XCTAssertEqual(zerlegt("[[chart: Titel | \(punkte)]]").diagramm?.punkte.count, 8)
    }

    func testChartLehntNegativeUndUnendlicheWerteAb() {
        XCTAssertTrue(zerlegt("[[chart: T | Mo -1 | Di 2 | Mi 3]]").marker.isEmpty)
        XCTAssertTrue(zerlegt("[[chart: T | Mo inf | Di 2 | Mi 3]]").marker.isEmpty)
    }

    // MARK: - fortschritt

    func testFortschritt() {
        let z = zerlegt("[[fortschritt: Schritte heute | 6200 | 10000]]")
        XCTAssertEqual(z.fortschritt?.label, "Schritte heute")
        XCTAssertEqual(z.fortschritt?.aktuell, 6200)
        XCTAssertEqual(z.fortschritt?.ziel, 10000)
    }

    func testFortschrittMitZielNullOderZuWenigTeilenFaelltWeg() {
        XCTAssertNil(zerlegt("[[fortschritt: A | 5 | 0]]").fortschritt)
        XCTAssertNil(zerlegt("[[fortschritt: A | 5]]").fortschritt)
        XCTAssertNil(zerlegt("[[fortschritt: A | x | 5]]").fortschritt)
        XCTAssertNil(zerlegt("[[fortschritt: A | -1 | 5]]").fortschritt)
    }

    // MARK: - gehe

    func testGeheMitUndOhneBeschriftung() {
        let z = zerlegt("[[gehe: schritte | Schritte öffnen]][[gehe: Training]]")
        XCTAssertEqual(z.wege.map { $0.ziel }, [.schritte, .training])
        XCTAssertEqual(z.wege.map { $0.beschriftung }, ["Schritte öffnen", "Training öffnen"])
    }

    func testGeheKuerztDieBeschriftungAuf24Zeichen() {
        let z = zerlegt("[[gehe: gewicht | 12345678901234567890123456789]]")
        XCTAssertEqual(z.wege.first?.beschriftung, "123456789012345678901234")
    }

    func testGeheMitUnbekanntemZielFaelltWeg() {
        XCTAssertTrue(zerlegt("[[gehe: konto | Konto]]").marker.isEmpty)
        XCTAssertTrue(zerlegt("[[gehe: ]]").marker.isEmpty)
    }

    // MARK: - erinnerung

    func testErinnerung() {
        let z = zerlegt("[[erinnerung: 07:30 | Wasser trinken]]")
        XCTAssertEqual(z.erinnerung?.stunde, 7)
        XCTAssertEqual(z.erinnerung?.minute, 30)
        XCTAssertEqual(z.erinnerung?.text, "Wasser trinken")
    }

    func testErinnerungMitUngueltigerZeitOderOhneTextFaelltWeg() {
        XCTAssertNil(zerlegt("[[erinnerung: 25:00 | A]]").erinnerung)
        XCTAssertNil(zerlegt("[[erinnerung: 07:60 | A]]").erinnerung)
        XCTAssertNil(zerlegt("[[erinnerung: 0730 | A]]").erinnerung)
        XCTAssertNil(zerlegt("[[erinnerung: 07:30]]").erinnerung)
        XCTAssertNil(zerlegt("[[erinnerung: 07:30 | ]]").erinnerung)
    }

    func testUhrzeit() {
        XCTAssertEqual(CoachMarker.uhrzeit("7:05")?.stunde, 7)
        XCTAssertEqual(CoachMarker.uhrzeit("7:05")?.minute, 5)
        XCTAssertEqual(CoachMarker.uhrzeit("23:59")?.stunde, 23)
        XCTAssertNil(CoachMarker.uhrzeit("24:00"))
        XCTAssertNil(CoachMarker.uhrzeit("12:3x"))
        XCTAssertNil(CoachMarker.uhrzeit("123:00"))
    }

    // MARK: - ziel

    func testZielNurFuerTrainingSchritteProtein() {
        XCTAssertEqual(zerlegt("[[ziel: 3 Mal pro Woche trainieren]]").vorgeschlagenesZiel, "3 Mal pro Woche trainieren")
        XCTAssertNil(zerlegt("[[ziel: 5 kg abnehmen]]").vorgeschlagenesZiel)
        XCTAssertNil(zerlegt("[[ziel: 1800 kcal am Tag]]").vorgeschlagenesZiel)
        XCTAssertNil(zerlegt("[[ziel: ]]").vorgeschlagenesZiel)
    }

    // MARK: - essen

    func testEssenMarkerMitAllenFeldern() {
        let z = zerlegt("Hab ich eingetragen, grob geschätzt.
[[essen: Pizza Spicy | mittag | 1000 | 40 | 120,5 | 38]]")
        XCTAssertEqual(z.text, "Hab ich eingetragen, grob geschätzt.")
        XCTAssertEqual(z.essen.count, 1)
        XCTAssertEqual(z.essen[0].name, "Pizza Spicy")
        XCTAssertEqual(z.essen[0].art, .mittag)
        XCTAssertEqual(z.essen[0].kcal, 1000)
        XCTAssertEqual(z.essen[0].protein, 40)
        XCTAssertEqual(z.essen[0].kohlenhydrate, 120.5)
        XCTAssertEqual(z.essen[0].fett, 38)
    }

    func testEssenMarkerNurNameArtKcal() {
        let e = zerlegt("[[essen: Apfel | snack | 80]]").essen
        XCTAssertEqual(e.first?.kcal, 80)
        XCTAssertNil(e.first?.protein)
        XCTAssertNil(e.first?.fett)
    }

    func testEssenMarkerUnbekannteArtWirdNil() {
        XCTAssertEqual(zerlegt("[[essen: Brot | frühstück | 200]]").essen.first?.art, .fruehstueck)
        XCTAssertNil(zerlegt("[[essen: Brot | irgendwann | 200]]").essen.first?.art)
        XCTAssertEqual(zerlegt("[[essen: Brot | irgendwann | 200]]").essen.count, 1)
    }

    func testEssenMarkerKaputtFaelltWeg() {
        XCTAssertTrue(zerlegt("[[essen: | mittag | 500]]").essen.isEmpty)
        XCTAssertTrue(zerlegt("[[essen: Pizza | mittag | viel]]").essen.isEmpty)
        XCTAssertTrue(zerlegt("[[essen: Pizza | mittag | 0]]").essen.isEmpty)
        XCTAssertTrue(zerlegt("[[essen: Pizza | mittag | 99999]]").essen.isEmpty)
        XCTAssertTrue(zerlegt("[[essen: Pizza | mittag]]").essen.isEmpty)
    }

    func testEssenMarkerHalbAbgeschnittenBleibtNichtImText() {
        XCTAssertEqual(zerlegt("Eingetragen.
[[essen: Pizza | mit").text, "Eingetragen.")
    }
}
