import SwiftUI
import XCTest
@testable import Lovea

/// Render board for Plan Task 5: `FormKachel` mit allen neun Formen bei 0, 45 und 100 %, das Gesicht in drei Stimmungen.
@MainActor
final class RenderGalerieTagesFormenTests: XCTestCase {
    private let titel: [TagesForm: String] = [
        .schritte: "Schritte", .wasser: "Wasser", .schlaf: "Schlaf", .habits: "Habits", .stimmung: "Stimmung",
        .koffein: "Koffein", .protein: "Protein", .gewicht: "Gewicht", .training: "Training",
    ]

    private func zelle(_ beschriftung: String, _ kachel: FormKachel) -> (titel: String, ansicht: AnyView) {
        (beschriftung, AnyView(kachel.frame(width: 110).padding(8).background(Color.black).environment(\.colorScheme, .dark)))
    }

    private func kachel(_ form: TagesForm, _ anteil: Double, stimmung: Int? = nil) -> FormKachel {
        FormKachel(
            form: form, titel: titel[form] ?? "", wert: "\(Int(anteil * 100))", einheit: "%",
            fuellung: anteil, stimmung: stimmung
        )
    }

    func testSVGPfadGrenzen() {
        let pfad = SVGPfad(d: "M2 4H10V20l-2 0Z")
        XCTAssertEqual(pfad.path(in: CGRect(x: 0, y: 0, width: 64, height: 64)).boundingRect, CGRect(x: 2, y: 4, width: 8, height: 16))
        XCTAssertEqual(pfad.path(in: CGRect(x: 0, y: 0, width: 32, height: 32)).boundingRect, CGRect(x: 1, y: 2, width: 4, height: 8))
        // Implizite Wiederholung und Vorzeichen ohne Trenner: "l2 2 4-4" sind zwei Striche.
        let haken = SVGPfad(d: "M0 10l2 2 4-4").path(in: CGRect(x: 0, y: 0, width: 64, height: 64)).boundingRect
        XCTAssertEqual(haken, CGRect(x: 0, y: 8, width: 6, height: 4))
    }

    func testTagesFormenTafel() {
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for form in TagesForm.allCases {
            for anteil in [0.0, 0.45, 1.0] {
                zellen.append(zelle("\(form.rawValue) \(Int(anteil * 100)) %", kachel(form, anteil)))
            }
        }
        for stufe in 1...3 {
            zellen.append(zelle("stimmung \(stufe) von 3", kachel(.stimmung, 0.6, stimmung: stufe)))
        }
        RenderTafel.speichern("tagesformen", spalten: 3, zellen: zellen)
    }
}
