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

    func testFokusWaehltDieSeiteMitDemMuskel() {
        let figur = MuskelPfade.figur(.ahmed)
        XCTAssertTrue(figur.hinten(fuer: .ruecken, teil: nil))
        XCTAssertTrue(figur.hinten(fuer: .ruecken, teil: .rLat))
        XCTAssertFalse(figur.hinten(fuer: .ruecken, teil: .rTrapezOben))
        XCTAssertFalse(figur.hinten(fuer: .beine, teil: nil))
        XCTAssertTrue(figur.hinten(fuer: .beine, teil: .bePo))
        XCTAssertTrue(figur.hinten(fuer: .trizeps, teil: nil))
        XCTAssertFalse(figur.hinten(fuer: .brust, teil: .bUnten))
    }

    func testMuskelFigurTafeln() {
        for person in Person.allCases { tafel(person) }
    }

    /// One board per person: `KopfFigur` draws everyone but `Raum.shared.ich` washed out (offline).
    private func tafel(_ person: Person) {
        let vorher = Raum.shared.ich
        Raum.shared.ich = person
        defer { Raum.shared.ich = vorher }

        let hoehe: CGFloat = 400
        let breite = hoehe * MuskelPfade.rahmen.width / MuskelPfade.rahmen.height
        func karte(_ titel: String, _ ansicht: some View) -> Zelle {
            (titel, AnyView(ansicht
                .frame(width: breite, height: hoehe)
                .padding(10)
                .background(Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, .dark)))
        }
        let farbe = MuskelFigurBeispiel.farbe
        let fokusse: [(MuskelGruppe, MuskelTeil)] = person == .ahmed ? [(.beine, .beQuads), (.trizeps, .triLang)] : [(.brust, .bUnten), (.ruecken, .rLat)]
        var zellen: [Zelle] = [
            karte("\(person.name) vorne", MuskelSeite(person: person, hinten: false, farbe: farbe, animiert: false)),
            karte("\(person.name) hinten", MuskelSeite(person: person, hinten: true, farbe: farbe, animiert: false)),
            karte("drehbar, mit Knopf", MuskelFigur(person: person, farbe: farbe, animiert: false)),
        ]
        for (gruppe, teil) in fokusse {
            let figur = MuskelFigur(person: person, farbe: farbe, markiert: teil, fokus: gruppe, animiert: false)
            zellen.append(karte("Fokus \(gruppe.name), \(teil.name) weiß", figur))
        }
        RenderTafel.speichern("muskel-figur-\(person.rawValue)", spalten: 5, zellen: zellen)
    }
}
