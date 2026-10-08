import XCTest
@testable import Lovea

/// p63: Globus und Wunschliste.
final class ZimmerGlobusTests: XCTestCase {
    private func idee(_ id: String, _ kategorie: DateKategorie = .essen, ort: PunktOrt? = nil, erledigt: Bool = false, geloescht: Bool = false) -> DateIdee {
        DateIdee(id: id, titel: id, kategorie: kategorie, erledigt: erledigt, ort: ort, geloescht: geloescht, geaendert: Date(timeIntervalSince1970: 0), von: .ahmed)
    }

    private let paris = PunktOrt(name: "Paris", lat: 48.85, lon: 2.35, adresse: nil)
    private let namenlos = PunktOrt(name: "Irgendwo", lat: 0, lon: 0, adresse: nil)

    func testWunschlisteSindOrteUndReisenOffeneZuerstGeloeschteNie() {
        let liste = ZimmerGlobus.wunschliste([
            idee("hat-ort", ort: paris, erledigt: true), idee("reise", .reisen), idee("nur-essen"),
            idee("offen-ort", ort: paris), idee("weg", .reisen, ort: paris, geloescht: true),
        ])
        XCTAssertEqual(liste.map(\.id), ["reise", "offen-ort", "hat-ort"])
    }

    func testPinsBrauchenEineKoordinateUndTragenDenBesuchtStand() {
        let pins = ZimmerGlobus.pins([idee("a", ort: paris, erledigt: true), idee("b", ort: namenlos), idee("c", .reisen)])
        XCTAssertEqual(pins.map(\.id), ["a"])
        XCTAssertEqual(pins.first?.besucht, true)
        XCTAssertEqual(pins.first?.name, "Paris")
    }

    func testMitteOhnePinsIstEuropa() {
        XCTAssertEqual(ZimmerGlobus.mitte([]).lat, ZimmerGlobus.europa.lat)
        XCTAssertEqual(ZimmerGlobus.mitte([]).lon, ZimmerGlobus.europa.lon)
    }

    func testMitteEinesPinsIstDerPin() {
        let m = ZimmerGlobus.mitte([GlobusPin(id: "a", name: "A", lat: 35.7, lon: 139.7, besucht: false)])
        XCTAssertEqual(m.lat, 35.7, accuracy: 1e-6)
        XCTAssertEqual(m.lon, 139.7, accuracy: 1e-6)
    }

    func testMitteUeberDieDatumsgrenze() {
        let m = ZimmerGlobus.mitte([GlobusPin(id: "a", name: "", lat: 0, lon: 170, besucht: false), GlobusPin(id: "b", name: "", lat: 0, lon: -170, besucht: false)])
        XCTAssertEqual(abs(m.lon), 180, accuracy: 1e-6)
    }

    func testProjektionMitteUndRand() {
        let mitte = ZimmerGlobus.projiziere(lat: 50, lon: 10, mitte: (lat: 50, lon: 10))
        XCTAssertEqual(mitte.x, 0, accuracy: 1e-9)
        XCTAssertEqual(mitte.y, 0, accuracy: 1e-9)
        XCTAssertTrue(mitte.vorn)
        let ost = ZimmerGlobus.projiziere(lat: 0, lon: 60, mitte: (lat: 0, lon: 0))
        XCTAssertEqual(ost.x, sin(60 * Double.pi / 180), accuracy: 1e-9)
        XCTAssertTrue(ost.vorn)
        let nord = ZimmerGlobus.projiziere(lat: 60, lon: 0, mitte: (lat: 0, lon: 0))
        XCTAssertEqual(nord.y, sin(60 * Double.pi / 180), accuracy: 1e-9)
    }

    func testRueckseiteIstNichtVorn() {
        XCTAssertFalse(ZimmerGlobus.projiziere(lat: 0, lon: 180, mitte: (lat: 0, lon: 0)).vorn)
        XCTAssertFalse(ZimmerGlobus.projiziere(lat: -50, lon: -170, mitte: (lat: 50, lon: 10)).vorn)
    }

    func testAlleProjektionenLiegenInnerhalbDerKugel() {
        for lat in stride(from: -90.0, through: 90, by: 30) {
            for lon in stride(from: -180.0, through: 180, by: 45) {
                let q = ZimmerGlobus.projiziere(lat: lat, lon: lon, mitte: (lat: 20, lon: 30))
                XCTAssertLessThanOrEqual(hypot(q.x, q.y), 1 + 1e-9)
            }
        }
    }

    func testUmrisseSindGueltigeKoordinaten() {
        for umriss in ZimmerGlobus.kontinente {
            XCTAssertGreaterThanOrEqual(umriss.count, 6)
            for (lat, lon) in umriss {
                XCTAssertTrue((-90.0...90).contains(lat) && (-180.0...180).contains(lon))
            }
        }
    }
}
