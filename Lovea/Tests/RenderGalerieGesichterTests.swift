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

    func testGesichterMimik() {
        let zustaende: [FigurZustand] = [.ruhig, .lacht, .gut, .kuss, .schmollt, .verlegen, .sauer, .schockiert,
                                         .ueberrascht, .muede, .schlaeft, .weint, .denkt, .zwinkert, .verliebt, .sprache]
        var zellen: [Zelle] = []
        for p in Person.allCases {
            for z in zustaende { zellen.append((titel: "\(p.name) \(z.rawValue)", ansicht: figur(p, z, groesse: 150))) }
        }
        RenderTafel.speichern("gesichter-mimik", spalten: 8, zellen: zellen)
    }

    func testGesichterZubehoer() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            var brille = FigurAussehen.standard(for: p)
            brille.brille = 1
            var muetze = FigurAussehen.standard(for: p)
            muetze.kopfbedeckung = 1
            var andereFrisur = FigurAussehen.standard(for: p)
            andereFrisur.frisur = p == .ahmed ? 3 : 7
            var altesGesicht = FigurAussehen.standard(for: p)
            altesGesicht.gesichtsform = 0
            for (titel, a) in [("Brille", brille), ("Mütze", muetze), ("andere Frisur", andereFrisur), ("altes Gesicht", altesGesicht)] {
                zellen.append((titel: "\(p.name) \(titel)", ansicht: AnyView(FigurView(a, zustand: .ruhig, groesse: 150, animiert: false, ganzkoerper: false))))
            }
        }
        RenderTafel.speichern("gesichter-zubehoer", spalten: 4, zellen: zellen)
    }

    func testKoerperV() {
        var zellen: [Zelle] = []
        let ahmed = FigurAussehen.standard(for: .ahmed)
        for z in [FigurZustand.ruhig, .gym, .imChat, .kamera, .liest, .sprache] {
            zellen.append((titel: "halb \(z.rawValue)", ansicht: AnyView(FigurView(ahmed, zustand: z, groesse: 180, animiert: false))))
        }
        var jacke = ahmed
        jacke.jacke = 1
        var langarm = ahmed
        langarm.oberteil = 1
        var alt = ahmed
        alt.gesichtsform = 0
        for (titel, a) in [("Jacke", jacke), ("Langarm", langarm), ("altes Gesicht", alt)] {
            zellen.append((titel: titel, ansicht: AnyView(FigurView(a, zustand: .ruhig, groesse: 180, animiert: false))))
        }
        for z in [FigurZustand.ruhig, .gym, .laeuft, .scooter] {
            zellen.append((titel: "ganz \(z.rawValue)", ansicht: AnyView(FigurView(ahmed, zustand: z, groesse: 280, animiert: false, ganzkoerper: true))))
        }
        RenderTafel.speichern("koerper-v", spalten: 7, zellen: zellen)
    }

    func testHalbfigurSchultern() {
        var zellen: [Zelle] = []
        for p in Person.allCases {
            for z in [FigurZustand.ruhig, .imChat, .kamera, .liest, .gym] {
                zellen.append((titel: "\(p.name) \(z.rawValue)", ansicht: AnyView(FigurView(.standard(for: p), zustand: z, groesse: 180, animiert: false))))
            }
        }
        RenderTafel.speichern("halbfigur-schultern", spalten: 5, zellen: zellen)
    }
}
