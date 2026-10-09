import SwiftUI
import XCTest
@testable import Lovea

/// Teil 4 render board: every gym exercise, full body, static (`wdh` freezes at the middle of the rep).
@MainActor
final class RenderGalerieGymTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    func testGymUebungen() {
        var zellen: [Zelle] = []
        for (p, liste) in [(Person.ahmed, GymGeste.ahmed + [.pause]), (.annika, GymGeste.annika + [.pause])] {
            for g in liste {
                zellen.append((titel: "\(p.name) \(g.rawValue)", ansicht: AnyView(FigurView(.standard(for: p), zustand: .gym, groesse: 260, animiert: false, ganzkoerper: true, gymGeste: g))))
            }
        }
        RenderTafel.speichern("gym-uebungen", spalten: 7, zellen: zellen)
    }
}
