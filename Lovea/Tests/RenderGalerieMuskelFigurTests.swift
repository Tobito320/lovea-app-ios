import SwiftUI
import XCTest
@testable import Lovea

/// Example colors from the draft: legs coral, quads rosé, the rest recovered. Not actor-isolated,
/// so `MuskelFigurBeispiel.farbe` can be passed as the plain `farbe` closure.
private enum MuskelFigurBeispiel {
    static let gruen = FigurFarbe(0x3A3A42).mix(FigurFarbe(0x30D158), 0.72).farbe
    static let koralle = Color(red: 1, green: 0x7A / 255, blue: 0x59 / 255)

    static func farbe(_ teil: MuskelTeil) -> Color {
        switch teil {
        case .beQuads: Color.loveaRose
        case .beAdd, .bePo, .beBeuger, .beWaden: koralle
        default: gruen
        }
    }
}

/// Checks and render board for `MuskelFigur` (Health/Koerper): Ahmed and Annika, front and back.
@MainActor
final class RenderGalerieMuskelFigurTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    func testJedesTeilHatEineFlaeche() {
        for person in Person.allCases {
            let teile = Set(MuskelPfade.figur(person).flaechen.map(\.teil))
            XCTAssertEqual(teile, Set(MuskelTeil.allCases), person.name)
        }
    }

    func testTrefferFindetMuskelAufBeidenHaelften() {
        let ahmed = MuskelPfade.figur(.ahmed)
        XCTAssertEqual(ahmed.teil(bei: CGPoint(x: 102, y: 122), hinten: false), .bOben)
        XCTAssertEqual(ahmed.teil(bei: CGPoint(x: 138, y: 122), hinten: false), .bOben)
        XCTAssertEqual(ahmed.teil(bei: CGPoint(x: 100, y: 212), hinten: true), .rLat)
        XCTAssertNil(ahmed.teil(bei: CGPoint(x: 5, y: 5), hinten: false))
    }

    func testBeinKuerzungUndFrauenBreite() {
        XCTAssertEqual(MuskelPfade.kurz(CGPoint(x: 100, y: 300)).y, 308, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.kurz(CGPoint(x: 100, y: 100)).y, 122, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.faktor(140), 0.86, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.faktor(600), 1, accuracy: 0.001)
    }

    func testMuskelFigurTafel() {
        let hoehe: CGFloat = 400
        let breite = hoehe * MuskelPfade.rahmen.width / MuskelPfade.rahmen.height
        func karte(_ titel: String, _ ansicht: some View) -> Zelle {
            (titel, AnyView(ansicht
                .frame(width: breite, height: hoehe)
                .padding(10)
                .background(Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, .dark)))
        }
        var zellen: [Zelle] = []
        for person in Person.allCases {
            for hinten in [false, true] {
                let seite = MuskelSeite(person: person, hinten: hinten, farbe: MuskelFigurBeispiel.farbe, animiert: false)
                zellen.append(karte("\(person.name) \(hinten ? "hinten" : "vorne")", seite))
            }
        }
        zellen.append(karte("Ahmed, drehbar mit Knopf", MuskelFigur(person: .ahmed, farbe: MuskelFigurBeispiel.farbe, animiert: false)))
        zellen.append(karte("Annika, drehbar mit Knopf", MuskelFigur(person: .annika, farbe: MuskelFigurBeispiel.farbe, animiert: false)))
        zellen.append(karte("Fokus Beine, Quadrizeps markiert", MuskelFigur(person: .ahmed, farbe: MuskelFigurBeispiel.farbe, markiert: .beQuads, fokus: .beine, animiert: false)))
        zellen.append(karte("Fokus Rücken, Latissimus markiert", MuskelFigur(person: .annika, farbe: MuskelFigurBeispiel.farbe, markiert: .rLat, fokus: .ruecken, animiert: false)))
        RenderTafel.speichern("muskel-figur", spalten: 4, zellen: zellen)
    }
}
