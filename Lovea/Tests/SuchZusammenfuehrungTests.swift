import XCTest
@testable import Lovea

/// Zusammenführen lokaler und Server-Suche (keine Sprünge, alte Antworten verworfen) und `haeufig`.
final class SuchZusammenfuehrungTests: XCTestCase {
    private func l(_ id: String, barcode: String? = nil) -> Lebensmittel {
        Lebensmittel(id: id, name: id, barcode: barcode, pro100: Naehrwerte(kcal: 1, protein: 0, kohlenhydrate: 0, fett: 0))
    }

    private func op(_ art: String, _ von: Person, _ wert: some Encodable, _ sek: Double) -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(timeIntervalSince1970: sek), d: try! JSONEncoder().encode(wert))
    }

    func testAlteAntwortWirdVerworfen() {
        let s = SuchStand(nummer: 5, lokal: [l("a")], server: [], sichtbar: [l("a")])
        XCTAssertEqual(SuchZusammenfuehrung.server(s, antwort: [l("x")], nummer: 4), s)
    }

    func testAnhaengenOhneDoppelteUndOhneSpringen() {
        let s = SuchStand(nummer: 1, lokal: [l("bls-1"), l("off-2", barcode: "2")], server: [], sichtbar: [l("bls-1"), l("off-2", barcode: "2")])
        let neu = SuchZusammenfuehrung.server(s, antwort: [l("off-2", barcode: "2"), l("off-3", barcode: "3")], nummer: 1)
        XCTAssertEqual(neu.sichtbar.map(\.id), ["bls-1", "off-2", "off-3"])
    }

    func testHaeufigZaehlt() {
        var f = ErnaehrungFaltung()
        let kaffee = l("bls-k"), ei = l("bls-e")
        let heute = Datum.text(Date())
        for (i, x) in [kaffee, ei, kaffee, kaffee].enumerated() {
            let e = EssenEintrag(id: "e\(i)", datum: heute, mahlzeit: .fruehstueck, menge: 1, einheit: .g, lebensmittel: x, geloescht: nil)
            f.anwenden(op("essen.setzen", .ahmed, e, Double(i)))
        }
        XCTAssertEqual(f.haeufig(.ahmed).map(\.id), ["bls-k", "bls-e"])
    }
}
