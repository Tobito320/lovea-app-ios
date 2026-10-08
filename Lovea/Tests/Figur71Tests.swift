import SwiftUI
import XCTest
@testable import Lovea

/// p71: Bauch-Stufen (optionales Feld), Ahmeds V-Form, Annika bleibt gleich, und die Bilder dazu (CI lädt `render-galerie` hoch).
@MainActor
final class Figur71Tests: XCTestCase {
    typealias A = FigurAussehen

    private func zeichner(_ a: A, ganz: Bool, _ z: FigurZustand = .ruhig) -> Zeichner {
        Zeichner(a, z, [], t: 0.4, statisch: true, ganz: ganz, extras: [])
    }

    func testBauchFeldAltesJSONUndRundreise() throws {
        let alt = #"{"haut":1,"frisur":7,"haarfarbe":1,"augen":4,"brille":0,"bart":0,"oberteil":4,"oberteilfarbe":12}"#
        let a = try JSONDecoder().decode(A.self, from: Data(alt.utf8))
        XCTAssertNil(a.bauch, "altes JSON ohne bauch bleibt Standard")
        XCTAssertEqual(a.bauchStufe, 0)
        var b = a
        b.bauchStufe = 3 // 6er
        XCTAssertEqual(b.bauch, 6)
        let zurueck = try JSONDecoder().decode(A.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(zurueck.bauch, 6)
        XCTAssertEqual(zurueck.bauchStufe, 3)
        b.bauchStufe = 0
        XCTAssertNil(b.bauch)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(b), as: UTF8.self).contains("bauch"), "nil wird nicht gesendet")
    }

    func testBauchNamenUndWerteGleichLang() {
        XCTAssertEqual(A.bauchNamen.count, A.bauchWerte.count)
        XCTAssertEqual(A.bauchWerte.compactMap { $0 }, [0, 4, 6, 8])
    }

    func testUnbekannterBauchWertWirdIgnoriert() {
        var a = A.standard(for: .ahmed)
        a.bauch = 5
        XCTAssertNil(zeichner(a, ganz: false).bauch)
        a.bauch = 8
        XCTAssertEqual(zeichner(a, ganz: false).bauch, 8)
    }

    /// Annika's figure must not change: her face is not the V-form face, so her measures come straight from the body table.
    func testAnnikaMasseUnveraendert() {
        let a = A.standard(for: .annika)
        XCTAssertNil(a.bauch)
        for ganz in [false, true] {
            let z = zeichner(a, ganz: ganz)
            XCTAssertNotEqual(z.neu, .b)
            let m = z.masse()
            XCTAssertEqual(m.s, z.km.s, accuracy: 0.001)
            XCTAssertEqual(m.t, z.km.t, accuracy: 0.001)
            XCTAssertEqual(m.h, z.km.h, accuracy: 0.001)
        }
    }

    /// Ahmed: V-taper — wide round shoulders, narrow waist, hips not wider than the waist.
    func testAhmedVForm() {
        let z = zeichner(A.standard(for: .ahmed), ganz: true)
        XCTAssertEqual(z.neu, .b)
        let m = z.masse()
        XCTAssertLessThan(m.h, m.t)
        XCTAssertGreaterThanOrEqual(z.vForm.delt, 1.2)
        XCTAssertLessThanOrEqual(z.vForm.sch, 48)
        XCTAssertGreaterThanOrEqual(zeichner(A.standard(for: .ahmed), ganz: false, .gym).vForm.delt, 1.2)
    }

    // MARK: - Bilder

    private func zelle(_ a: A, ganz: Bool, z: FigurZustand = .ruhig) -> AnyView {
        AnyView(
            FigurView(a, zustand: z, groesse: ganz ? 200 : 170, animiert: false, ganzkoerper: ganz)
                .frame(width: 200, height: 200, alignment: .bottom)
                .background(Color(white: 0.93))
        )
    }

    private func oben(_ person: Person, bauch: Int? = nil) -> A {
        var a = A.standard(for: person)
        a.oberteil = 33 // Oben ohne
        a.bauch = bauch
        return a
    }

    func testBilderAhmedVFormUndBauch() {
        let ahmed = A.standard(for: .ahmed)
        var zellen: [(titel: String, ansicht: AnyView)] = [
            ("Ahmed Halbfigur", zelle(ahmed, ganz: false)),
            ("Ahmed Gym", zelle(ahmed, ganz: false, z: .gym)),
            ("Ahmed ganz", zelle(ahmed, ganz: true)),
            ("Annika Halbfigur", zelle(A.standard(for: .annika), ganz: false)),
            ("Annika ganz", zelle(A.standard(for: .annika), ganz: true)),
        ]
        for (name, wert) in [("Standard", nil), ("Glatt", 0), ("4er", 4), ("6er", 6), ("8er", 8)] as [(String, Int?)] {
            zellen.append(("Bauch \(name)", zelle(oben(.ahmed, bauch: wert), ganz: false)))
        }
        RenderTafel.speichern("figur-p71-ahmed-vform-bauch", spalten: 5, zellen: zellen)
    }

    func testBilderSchmuckNah() {
        func feld(_ id: String) -> AnyView {
            AnyView(
                Canvas { g, _ in
                    if let e = schmuckKatalog[id] { zeichneSchmuckGross(g, e.stil, e.farbe) }
                }
                .frame(width: 200, height: 260)
                .background(Color(white: 0.93))
            )
        }
        let ids = ["juwel.herzkette", "juwel.perlenkette", "juwel.cartier-love", "juwel.charm-armband", "juwel.steinring"]
        RenderTafel.speichern("figur-p71-schmuck-nah", spalten: 5, zellen: ids.map { ($0, feld($0)) })
    }
}
