import XCTest
@testable import Lovea

/// Mahlzeiten und Rezepte, geteilt zwischen Ahmed und Annika: Ersteller aus `op.von`, Kopieren, Favoriten folgen der Fassung.
final class ErnaehrungTeilenTests: XCTestCase {
    private func op(_ art: String, _ von: Person, _ wert: some Encodable, _ sek: Double) -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(timeIntervalSince1970: sek), d: try! JSONEncoder().encode(wert))
    }
    private let quark = Lebensmittel(id: "eigen-q", name: "Quark", pro100: Naehrwerte(kcal: 67, protein: 12, kohlenhydrate: 4, fett: 0.3))

    func testErstellerBleibtBeimAendern() {
        var f = ErnaehrungFaltung()
        f.anwenden(op("rezept.setzen", .annika, Rezept(id: "r1", name: "Bowl", portionen: 1, zutaten: [], art: .mahlzeit), 1))
        f.anwenden(op("rezept.setzen", .ahmed, Rezept(id: "r1", name: "Bowl groß", portionen: 1, zutaten: [], art: .mahlzeit), 2))
        XCTAssertEqual(f.ersteller(rezept: "r1"), .annika)
        XCTAssertEqual(f.rezepte.first?.name, "Bowl groß")
        XCTAssertEqual(f.rezepte.first?.istMahlzeit, true)
    }

    func testAltesRezeptOhneArtIstRezept() throws {
        let json = #"{"id":"r2","name":"Suppe","portionen":2,"zutaten":[]}"#
        let r = try JSONDecoder().decode(Rezept.self, from: Data(json.utf8))
        XCTAssertFalse(r.istMahlzeit)
        XCTAssertNil(r.anleitung)
    }

    func testFavoritSiehtNeueFassungKopieNicht() {
        var f = ErnaehrungFaltung()
        let alt = Rezept(id: "r3", name: "Porridge", portionen: 1, zutaten: [Zutat(id: "z", lebensmittel: quark, menge: 100, einheit: .g)])
        f.anwenden(op("rezept.setzen", .annika, alt, 1))
        var kopie = alt; kopie.id = "r3-kopie"
        f.anwenden(op("rezept.setzen", .ahmed, kopie, 2))
        var neu = alt; neu.zutaten[0].menge = 200
        f.anwenden(op("rezept.setzen", .annika, neu, 3))
        XCTAssertEqual(f.rezepte.first { $0.id == "r3" }?.zutaten[0].menge, 200)
        XCTAssertEqual(f.rezepte.first { $0.id == "r3-kopie" }?.zutaten[0].menge, 100)
        XCTAssertEqual(f.ersteller(rezept: "r3-kopie"), .ahmed)
    }

    func testEigenesLebensmittelErsteller() {
        var f = ErnaehrungFaltung()
        f.anwenden(op("lebensmittel.setzen", .annika, LebensmittelD(lebensmittel: quark, geloescht: nil), 1))
        XCTAssertEqual(f.ersteller(lebensmittel: "eigen-q"), .annika)
    }
}
