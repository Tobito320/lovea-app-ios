import SwiftUI
import XCTest
@testable import Lovea

/// Brief F2 render board: the redesigned faces (Ahmed B, Annika 3) in the half figure, the avatar size,
/// the full body and the hug turn. Static figures only.
@MainActor
final class RenderGalerieGesichterTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private func figur(_ p: Person, _ z: FigurZustand = .ruhig, groesse: CGFloat = 200, ganz: Bool = false, umarmung: Umarmung? = nil) -> AnyView {
        AnyView(FigurView(.standard(for: p), zustand: z, groesse: groesse, animiert: false, ganzkoerper: ganz, umarmung: umarmung))
    }

    func testGesichterNeu() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            zellen.append((titel: "\(p.name) ruhig", ansicht: figur(p)))
            zellen.append((titel: "\(p.name) mittel", ansicht: figur(p, .mittel)))
            zellen.append((titel: "\(p.name) 48 pt", ansicht: AnyView(figur(p, groesse: 48).frame(width: 60, height: 60))))
            zellen.append((titel: "\(p.name) ganz", ansicht: figur(p, groesse: 260, ganz: true)))
            zellen.append((titel: "\(p.name) Kuss-Drehung", ansicht: figur(p, .kuss, groesse: 260, ganz: true, umarmung: Umarmung(seite: p == .ahmed ? 1 : -1, abstand: 0, arme: 1, kuss: 1))))
        }
        RenderTafel.speichern("gesichter-neu", spalten: 5, zellen: zellen)
    }
}
