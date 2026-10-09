import SwiftUI
import XCTest
@testable import Lovea

/// Z-31.3: render boards for a visual check without Xcode (CI artifact `render-galerie`).
/// Other areas add their own boards in `RenderGalerie<Area>Tests.swift`.
@MainActor
final class RenderGalerieTests: XCTestCase {
    func testStandardFiguresHalfBody() {
        RenderTafel.speichern("figuren-standard-halb", spalten: 13, zellen: standardFigures(fullBody: false))
    }

    func testStandardFiguresFullBody() {
        RenderTafel.speichern("figuren-standard-ganz", spalten: 13, zellen: standardFigures(fullBody: true))
    }

    /// Both default figures in every state: Ahmed first, then Annika (13 columns = 3 rows per person today).
    private func standardFigures(fullBody: Bool) -> [(titel: String, ansicht: AnyView)] {
        var cells: [(titel: String, ansicht: AnyView)] = []
        for person in Person.allCases {
            for state in FigurZustand.allCases {
                let figure = FigurView(.standard(for: person), zustand: state, groesse: 120, animiert: false, ganzkoerper: fullBody)
                cells.append((titel: state.titel, ansicht: AnyView(figure)))
            }
        }
        return cells
    }
}
