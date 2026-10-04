import XCTest
@testable import Lovea

final class DatesAnsichtTests: XCTestCase {
    private let alle = DateStartdaten.ideen
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func idee(_ id: String, _ kategorie: DateKategorie, erledigt: Bool = false, geloescht: Bool = false, ort: String? = nil) -> DateIdee {
        DateIdee(
            id: id, titel: id, kategorie: kategorie, erledigt: erledigt, erledigtAm: erledigt ? "2026-10-01" : nil,
            ort: ort.map { PunktOrt(name: $0, lat: 0, lon: 0, adresse: nil) }, geloescht: geloescht, geaendert: t0, von: .ahmed
        )
    }

    func testAbschnitteInKategorieReihenfolgeMitZaehler() {
        let abschnitte = DatesAnsichtLogik.abschnitte(alle, filter: DateFilter())
        XCTAssertEqual(abschnitte.map(\.kategorie), DateKategorie.allCases)
        XCTAssertEqual(abschnitte.map(\.gesamt).reduce(0, +), alle.count)
        XCTAssertEqual(abschnitte.map(\.erledigt).reduce(0, +), 1)
        let draussen = abschnitte.first { $0.kategorie == .draussen }
        XCTAssertEqual(draussen?.erledigt, 1)
        XCTAssertEqual(draussen?.zaehler, "1/\(draussen?.gesamt ?? -1)")
    }

    func testLeereAbschnitteFallenWeg() {
        let ideen = [idee("a", .essen), idee("b", .reisen)]
        XCTAssertEqual(DatesAnsichtLogik.abschnitte(ideen, filter: DateFilter()).map(\.kategorie), [.essen, .reisen])
    }

    func testZaehlerBleibtBeiFilterBeiDerGanzenKategorie() {
        let ideen = [idee("a", .essen, erledigt: true), idee("b", .essen), idee("c", .essen)]
        var filter = DateFilter()
        filter.status = .offen
        let abschnitt = DatesAnsichtLogik.abschnitte(ideen, filter: filter).first
        XCTAssertEqual(abschnitt?.ideen.map(\.id), ["b", "c"])
        XCTAssertEqual(abschnitt?.zaehler, "1/3")
    }

    func testGeloeschteZaehlenNicht() {
        let ideen = [idee("a", .essen), idee("b", .essen, geloescht: true)]
        let abschnitt = DatesAnsichtLogik.abschnitte(ideen, filter: DateFilter()).first
        XCTAssertEqual(abschnitt?.ideen.map(\.id), ["a"])
        XCTAssertEqual(abschnitt?.gesamt, 1)
    }

    func testKategorieUndOrtFilter() {
        let ideen = [idee("a", .essen, ort: "Café Classic Remise"), idee("b", .essen), idee("c", .reisen, ort: "Paris")]
        var filter = DateFilter()
        filter.kategorie = .essen
        XCTAssertEqual(DatesAnsichtLogik.abschnitte(ideen, filter: filter).flatMap(\.ideen).map(\.id), ["a", "b"])
        filter.kategorie = nil
        filter.ort = "paris"
        XCTAssertEqual(DatesAnsichtLogik.abschnitte(ideen, filter: filter).flatMap(\.ideen).map(\.id), ["c"])
    }

    func testStatusChipSchaltetUmUndZurueck() {
        let offen = DatesAnsichtLogik.umschalten(DateFilter(), status: .offen)
        XCTAssertEqual(offen.status, .offen)
        XCTAssertEqual(DatesAnsichtLogik.umschalten(offen, status: .offen).status, .alle)
        XCTAssertEqual(DatesAnsichtLogik.umschalten(offen, status: .erledigt).status, .erledigt)
    }

    func testIstGefiltert() {
        XCTAssertFalse(DatesAnsichtLogik.istGefiltert(DateFilter()))
        XCTAssertTrue(DatesAnsichtLogik.istGefiltert(DateFilter(kategorie: .essen)))
        XCTAssertTrue(DatesAnsichtLogik.istGefiltert(DateFilter(ort: "Paris")))
    }

    func testUndoFensterFuenfSekunden() {
        let undo = DatesUndo(ideeID: "a", titel: "Bowling", beginn: t0)
        XCTAssertEqual(DatesUndo.dauer, 5)
        XCTAssertEqual(undo.rest(t0), 1, accuracy: 0.0001)
        XCTAssertEqual(undo.rest(t0.addingTimeInterval(2.5)), 0.5, accuracy: 0.0001)
        XCTAssertTrue(undo.istOffen(t0.addingTimeInterval(4.9)))
        XCTAssertFalse(undo.istOffen(t0.addingTimeInterval(5)))
        XCTAssertFalse(undo.istOffen(t0.addingTimeInterval(60)))
        XCTAssertEqual(undo.rest(t0.addingTimeInterval(-3)), 1, accuracy: 0.0001)
    }

    func testOrtZeileUndSprechtext() {
        let mit = DateIdee(id: "x", titel: "Frühstücken", kategorie: .essen, ort: PunktOrt(name: " Café ", lat: 0, lon: 0, adresse: nil),
                           links: [DateLink(id: "l", url: "https://maps.app.goo.gl/x", titel: nil)], geaendert: t0, von: .ahmed)
        XCTAssertEqual(DatesAnsichtLogik.ortZeile(mit), "Café")
        XCTAssertEqual(DatesAnsichtLogik.sprechtext(mit), "Frühstücken, offen, Café, 1 Link")
        XCTAssertNil(DatesAnsichtLogik.ortZeile(idee("o", .essen)))
        XCTAssertEqual(DatesAnsichtLogik.sprechtext(idee("o", .essen, erledigt: true)), "o, erledigt")
    }
}
