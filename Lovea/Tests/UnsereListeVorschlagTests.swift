import XCTest
@testable import Lovea

final class UnsereListeVorschlagTests: XCTestCase {
    func testHaeufigsterGewinnt() {
        let jetzt = Date()
        let eintraege: [(text: String, zeit: Date)] = [
            ("Kino", jetzt.addingTimeInterval(-300)),
            ("Picknick", jetzt.addingTimeInterval(-200)),
            ("Kino", jetzt.addingTimeInterval(-100)),
        ]
        XCTAssertEqual(UnsereListeVorschlag.haeufigste(eintraege), "Kino")
    }

    func testGleichstandZuletztEingetragenGewinnt() {
        let jetzt = Date()
        let eintraege: [(text: String, zeit: Date)] = [
            ("Kino", jetzt.addingTimeInterval(-300)),
            ("Picknick", jetzt.addingTimeInterval(-100)),
        ]
        XCTAssertEqual(UnsereListeVorschlag.haeufigste(eintraege), "Picknick")
    }

    func testLeerGibtNilZurueck() {
        XCTAssertNil(UnsereListeVorschlag.haeufigste([]))
    }

    func testLeereTexteZaehlenNicht() {
        let jetzt = Date()
        let eintraege: [(text: String, zeit: Date)] = [
            ("", jetzt.addingTimeInterval(-300)),
            ("  ", jetzt.addingTimeInterval(-200)),
            ("Kino", jetzt.addingTimeInterval(-100)),
        ]
        XCTAssertEqual(UnsereListeVorschlag.haeufigste(eintraege), "Kino")
    }
}
