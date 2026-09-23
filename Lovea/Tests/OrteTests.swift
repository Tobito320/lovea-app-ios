import XCTest
@testable import Lovea

final class OrteTests: XCTestCase {

    private let jetzt = Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!

    private func datum(_ tag: Int, _ stunde: Int) -> Date {
        Calendar.berlin.date(from: DateComponents(year: 2026, month: 9, day: tag, hour: stunde))!
    }

    private func besuch(_ tag: Int, lat: Double = 52.5, lon: Double = 13.4, stunde: Int = 12, dauerStunden: Double = 1) -> Besuch {
        let ankunft = datum(tag, stunde)
        return Besuch(lat: lat, lon: lon, ankunft: ankunft, verlassen: ankunft.addingTimeInterval(dauerStunden * 3600))
    }

    // MARK: - Z-8.4 Vorschlagsregel

    func testDreiTageInnerhalb150mErgibtVorschlag() {
        let besuche = [besuch(10), besuch(12), besuch(14)]

        let vorschlaege = Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt)

        XCTAssertEqual(vorschlaege.count, 1)
        XCTAssertEqual(vorschlaege.first?.tage, 3)
    }

    func testZweiTageErgibtKeinenVorschlag() {
        let besuche = [besuch(10), besuch(12)]

        XCTAssertTrue(Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt).isEmpty)
    }

    func testDreiBesucheAmSelbenTagZaehlenAlsEinTag() {
        let besuche = [besuch(10, stunde: 8), besuch(10, stunde: 12), besuch(10, stunde: 18)]

        XCTAssertTrue(Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt).isEmpty)
    }

    func testWeitEntfernteBesucheClusternNicht() {
        // ~270 m auseinander bei dieser Breite - über den 150-m-Radius hinaus.
        let besuche = [besuch(10, lon: 13.400), besuch(12, lon: 13.404), besuch(14, lon: 13.400)]

        XCTAssertTrue(Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt).isEmpty)
    }

    func testBereitsGespeicherterOrtWirdNichtVorgeschlagen() {
        let besuche = [besuch(10), besuch(12), besuch(14)]
        let gespeichert = [Ort(id: "1", person: .ahmed, name: "Zuhause", kategorie: "zuhause", lat: 52.5, lon: 13.4, radius: 100, melden: "beides")]

        XCTAssertTrue(Orte.vorschlaege(besuche: besuche, gespeichert: gespeichert, jetzt: jetzt).isEmpty)
    }

    func testBesucheAelterAls14TageZaehlenNicht() {
        let besuche = [besuch(1), besuch(2), besuch(3)] // 17-19 Tage vor `jetzt`

        XCTAssertTrue(Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt).isEmpty)
    }

    func testNachtBesucheZaehlenAlsNaechteAuchWennSieVorMitternachtBeginnen() {
        // Ankunft 23 Uhr, 8 Stunden - überlappt das Nachtfenster 22-6 Uhr, auch wenn die
        // Ankunft selbst schon "spät" statt "früh" ist.
        let besuche = [
            besuch(10, stunde: 23, dauerStunden: 8),
            besuch(12, stunde: 23, dauerStunden: 8),
            besuch(14, stunde: 23, dauerStunden: 8),
        ]

        let vorschlaege = Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt)

        XCTAssertEqual(vorschlaege.first?.naechte, 3)
    }

    func testTagsueberBesucheSindKeineNaechte() {
        let besuche = [besuch(10, stunde: 10, dauerStunden: 2), besuch(12, stunde: 10, dauerStunden: 2), besuch(14, stunde: 10, dauerStunden: 2)]

        let vorschlaege = Orte.vorschlaege(besuche: besuche, gespeichert: [], jetzt: jetzt)

        XCTAssertEqual(vorschlaege.first?.naechte, 0)
    }
}
