import SwiftUI
import XCTest
@testable import Lovea

/// Example colors from the draft: legs coral, the rest recovered. Not actor-isolated, so
/// `MuskelFigurBeispiel.farbe` can be passed as the plain `farbe` closure.
private enum MuskelFigurBeispiel {
    static let gruen = FigurFarbe(0x3A3A42).mix(FigurFarbe(0x30D158), 0.72).farbe
    static let koralle = Color(red: 1, green: 0x7A / 255, blue: 0x59 / 255)

    static func farbe(_ gruppe: MuskelGruppe) -> Color { gruppe == .beine ? koralle : gruen }
}

/// Checks and render board for `MuskelFigur` (Health/Koerper): Ahmed and Annika, front and back.
@MainActor
final class RenderGalerieMuskelFigurTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    /// Vorne: Schulter, Unterarme, Brust, Bizeps, Bauch, Beine. Hinten: Nacken, Schulter, Rücken,
    /// Trizeps, Unterarme, Beine. Brust und Bizeps nur vorne, Nacken, Rücken und Trizeps nur hinten.
    func testJedeGruppeHatEineFlaecheAufDerRichtigenSeite() {
        for person in Person.allCases {
            let flaechen = MuskelPfade.figur(person).flaechen
            let vorne = Set(flaechen.filter { $0.seite == .vorne }.map(\.gruppe))
            let hinten = Set(flaechen.filter { $0.seite == .hinten }.map(\.gruppe))
            XCTAssertEqual(vorne, [.schulter, .unterarme, .brust, .bizeps, .bauch, .beine], person.name)
            XCTAssertEqual(hinten, [.nacken, .schulter, .ruecken, .trizeps, .unterarme, .beine], person.name)
        }
    }

    func testTrefferFindetDieGruppeAufBeidenHaelften() {
        let ahmed = MuskelPfade.figur(.ahmed)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 99.7, y: 161.3), hinten: false), .brust)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 140.3, y: 161.3), hinten: false), .brust)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 101.2, y: 207.4), hinten: true), .ruecken)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 97.3, y: 315.5), hinten: false), .beine)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 93.8, y: 364.3), hinten: false), .beine)
        XCTAssertNil(ahmed.gruppe(bei: CGPoint(x: 5, y: 5), hinten: false))
    }

    func testBeinKuerzungUndFrauenBreite() {
        XCTAssertEqual(MuskelPfade.kurz(CGPoint(x: 100, y: 300)).y, 300.6, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.kurz(CGPoint(x: 100, y: 100)).y, 146.6, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.kurz(CGPoint(x: 100, y: 100)).x, 98, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.faktor(140), 0.86, accuracy: 0.001)
        XCTAssertEqual(MuskelPfade.faktor(600), 1, accuracy: 0.001)
    }

    /// Nur hinten sichtbare Gruppen zeigen immer hinten, nur vorn sichtbare immer vorn, und Gruppen auf
    /// beiden Seiten (Schulter, Unterarme, Beine) zeigen vorn.
    func testFokusWaehltDieSeiteMitDerGruppe() {
        let figur = MuskelPfade.figur(.ahmed)
        XCTAssertTrue(figur.hinten(fuer: .ruecken))
        XCTAssertTrue(figur.hinten(fuer: .nacken))
        XCTAssertTrue(figur.hinten(fuer: .trizeps))
        XCTAssertFalse(figur.hinten(fuer: .brust))
        XCTAssertFalse(figur.hinten(fuer: .bizeps))
        XCTAssertFalse(figur.hinten(fuer: .schulter))
        XCTAssertFalse(figur.hinten(fuer: .unterarme))
        XCTAssertFalse(figur.hinten(fuer: .beine))
    }

    /// Konvexe Hülle: mehr als zwei Punkte ergeben ein einfaches, geschlossenes Vieleck ohne die
    /// inneren Punkte eines Quadrats.
    func testHuelleLaesstInnerenPunktWeg() {
        let quadrat = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10), CGPoint(x: 5, y: 5)]
        XCTAssertEqual(Set(MuskelPfade.hulle(quadrat)), Set(quadrat.dropLast()))
    }

    func testMuskelFigurTafeln() {
        for person in Person.allCases { tafel(person) }
    }

    /// One board per person.
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
        let fokusse: [MuskelGruppe] = person == .ahmed ? [.beine, .trizeps] : [.brust, .ruecken]
        var zellen: [Zelle] = [
            karte("\(person.name) vorne", MuskelSeite(person: person, hinten: false, farbe: farbe)),
            karte("\(person.name) hinten", MuskelSeite(person: person, hinten: true, farbe: farbe)),
            karte("drehbar, mit Knopf", MuskelFigur(person: person, farbe: farbe, animiert: false)),
        ]
        for gruppe in fokusse {
            let figur = MuskelFigur(person: person, farbe: farbe, fokus: gruppe, animiert: false)
            zellen.append(karte("Fokus \(gruppe.name)", figur))
        }
        RenderTafel.speichern("muskel-figur-\(person.rawValue)", spalten: 5, zellen: zellen)
    }
}
