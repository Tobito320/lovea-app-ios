import XCTest
@testable import Lovea

/// p69 (50): a saved look with a number outside its list is made valid on open (`mitGueltigenIndizes`), so the
/// figure shows the person's default instead of the last entry of the list and the editor does not save the
/// bad number again.
final class FigurIndizesTests: XCTestCase {
    typealias A = FigurAussehen

    /// The chain the app runs on open (`FigurenModell.aussehen(_:)`).
    private func beimOeffnen(_ a: A, _ p: Person) -> A {
        A.mitGueltigenIndizes(A.mitGueltigerKleidung(A.mitNeuemGesicht(a, p), p), p)
    }

    /// Names of all whole-number fields of a look, read from the struct itself so a new field is found too.
    private func intFelder(_ a: A) -> [(name: String, wert: Int)] {
        Mirror(reflecting: a).children.compactMap { kind in
            guard let name = kind.label, let wert = kind.value as? Int else { return nil }
            return (name, wert)
        }
    }

    /// A look whose every whole-number field is `wert`, made through the same JSON the sync uses.
    private func mitWert(_ wert: Int) throws -> A {
        let roh = try JSONEncoder().encode(A())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: roh) as? [String: Any])
        for feld in intFelder(A()) { json[feld.name] = wert }
        return try JSONDecoder().decode(A.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func testStandardLooksBleiben() {
        for p in Person.allCases {
            let a = A.standard(for: p)
            XCTAssertEqual(A.mitGueltigenIndizes(a, p), a, "\(p)")
        }
    }

    func testGueltigeAndereWerteBleiben() {
        var a = A.standard(for: .annika)
        a.haut = 3
        a.frisur = 57
        a.haarfarbe = 2
        a.nase = 1
        a.mund = 4
        a.hosenfarbe = 5
        a.uhrAlltag = 1
        XCTAssertEqual(A.mitGueltigenIndizes(a, .annika), a)
    }

    func testZahlAusserhalbDerListeWirdZumStandard() {
        for p in Person.allCases {
            let basis = A.standard(for: p)
            var a = basis
            a.haut = 999
            a.frisur = -1
            a.augenform = A.augenformen.count
            a.mund = A.muender.count
            a.jackenfarbe = A.farben.count
            a.muetzenfarbe = -4
            a.koerperform = 50
            a.groesse = A.groessen.count
            a.uhrAlltag = A.uhrenAlltag.count
            let neu = A.mitGueltigenIndizes(a, p)
            XCTAssertEqual(neu, basis, "\(p)")
        }
    }

    func testLetzterEintragBleibtErlaubt() {
        var a = A.standard(for: .ahmed)
        a.haarfarbe = A.haarfarben.count - 1
        a.setzeAlleFarben(A.farben.count - 1)
        XCTAssertEqual(A.mitGueltigenIndizes(a, .ahmed), a)
    }

    /// Drift guard: a whole-number field that nobody checks would keep 9999 or -5. Fails when a new field
    /// of `FigurAussehen` is added without a rule in one of the three repair functions.
    func testKeinIntFeldBleibtUngeprueft() throws {
        XCTAssertGreaterThanOrEqual(intFelder(A()).count, 25, "Die Felder wurden nicht gefunden: der Test ist kaputt")
        for wert in [9999, -5] {
            let schlecht = try mitWert(wert)
            for feld in intFelder(schlecht) {
                XCTAssertEqual(feld.wert, wert, "\(feld.name) kam nicht an: der Test prueft nichts")
            }
            for p in Person.allCases {
                for feld in intFelder(beimOeffnen(schlecht, p)) {
                    XCTAssertTrue((0..<200).contains(feld.wert), "\(p).\(feld.name) = \(feld.wert) wird beim Oeffnen nicht repariert")
                }
            }
        }
    }
}

private extension FigurAussehen {
    /// Sets all five clothing color slots at once.
    mutating func setzeAlleFarben(_ i: Int) {
        oberteilfarbe = i; jackenfarbe = i; hosenfarbe = i; schuhfarbe = i; muetzenfarbe = i
    }
}
