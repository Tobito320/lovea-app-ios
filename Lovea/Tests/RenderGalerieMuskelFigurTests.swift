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

    /// Die Karte (`muskelkarte.json`) ist im Bundle und hat für beide Personen beide Seiten mit Silhouette
    /// und Muskelflächen, vorne und hinten gleich groß.
    func testKarteIstGeladenFuerBeidePersonenUndSeiten() {
        for person in Person.allCases {
            let figur = MuskelPfade.figur(person)
            for hinten in [false, true] {
                let bild = figur.bild(hinten: hinten)
                XCTAssertFalse(bild.still.isEmpty, "\(person.name) Silhouette, hinten \(hinten)")
                XCTAssertGreaterThan(bild.flaechen.count, 20, "\(person.name) Flächen, hinten \(hinten)")
                XCTAssertGreaterThan(bild.rahmen.width, 600, person.name)
                XCTAssertGreaterThan(bild.rahmen.height, 1000, person.name)
            }
            XCTAssertEqual(figur.bildVorne.rahmen.size, figur.bildHinten.rahmen.size, person.name)
            XCTAssertGreaterThan(figur.seitenverhaeltnis, 0.3)
            XCTAssertLessThan(figur.seitenverhaeltnis, 0.8)
        }
        XCTAssertNotEqual(MuskelPfade.ahmed.bildVorne.rahmen, MuskelPfade.annika.bildVorne.rahmen)
    }

    /// Jede Lovea-Gruppe hat mindestens eine Fläche. Vorne: Nacken (Trapez am Hals), Schulter, Brust, Bizeps,
    /// Trizeps, Unterarme, Bauch, Beine. Hinten: Rücken, Schulter, Trizeps, Unterarme, Beine.
    func testJedeGruppeHatEineFlaecheAufDerRichtigenSeite() {
        for person in Person.allCases {
            let flaechen = MuskelPfade.figur(person).flaechen
            let vorne = Set(flaechen.filter { $0.seite == .vorne }.map(\.gruppe))
            let hinten = Set(flaechen.filter { $0.seite == .hinten }.map(\.gruppe))
            XCTAssertEqual(vorne, [.nacken, .schulter, .brust, .bizeps, .trizeps, .unterarme, .bauch, .beine], person.name)
            XCTAssertEqual(hinten, [.ruecken, .schulter, .trizeps, .unterarme, .beine], person.name)
            XCTAssertEqual(vorne.union(hinten), Set(MuskelGruppe.allCases), person.name)
        }
    }

    func testSlugZuGruppe() {
        XCTAssertEqual(MuskelPfade.gruppe(slug: "trapezius", hinten: false), .nacken)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "trapezius", hinten: true), .ruecken)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "upper-back", hinten: true), .ruecken)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "lower-back", hinten: true), .ruecken)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "deltoids", hinten: false), .schulter)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "forearm", hinten: true), .unterarme)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "serratus", hinten: false), .bauch)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "hip-flexors", hinten: false), .bauch)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "gluteal", hinten: true), .beine)
        XCTAssertEqual(MuskelPfade.gruppe(slug: "tibialis", hinten: false), .beine)
        XCTAssertNil(MuskelPfade.gruppe(slug: "head", hinten: false))
        XCTAssertNil(MuskelPfade.gruppe(slug: "neck", hinten: true))
    }

    /// Punkte in der Mitte einer Fläche (mit 6 Einheiten Abstand zum Rand, gegen die Quelle im Browser
    /// gemessen und von keiner später gezeichneten Fläche überdeckt) liefern ihre Gruppe, Punkte außerhalb
    /// des Körpers nichts.
    func testTrefferFindetDieGruppe() {
        let ahmed = MuskelPfade.ahmed
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 311.2, y: 373.2), hinten: false), .brust)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 308.4, y: 303.7), hinten: false), .nacken)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 284.0, y: 803.1), hinten: false), .beine)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 977.8, y: 362.7), hinten: true), .ruecken)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 1042.7, y: 353.3), hinten: true), .ruecken)
        XCTAssertEqual(ahmed.gruppe(bei: CGPoint(x: 1011.5, y: 634.8), hinten: true), .beine)
        XCTAssertNil(ahmed.gruppe(bei: CGPoint(x: 2, y: 97), hinten: false))
        XCTAssertNil(ahmed.gruppe(bei: CGPoint(x: 720, y: 97), hinten: true))

        let annika = MuskelPfade.annika
        XCTAssertEqual(annika.gruppe(bei: CGPoint(x: 287.3, y: 375.2), hinten: false), .brust)
        XCTAssertEqual(annika.gruppe(bei: CGPoint(x: 243.7, y: 782.0), hinten: false), .beine)
        XCTAssertEqual(annika.gruppe(bei: CGPoint(x: 1060.2, y: 346.4), hinten: true), .ruecken)
        XCTAssertEqual(annika.gruppe(bei: CGPoint(x: 1068.1, y: 623.8), hinten: true), .beine)
        XCTAssertNil(annika.gruppe(bei: CGPoint(x: 2, y: 2), hinten: false))
        XCTAssertNil(annika.gruppe(bei: CGPoint(x: 825, y: 2), hinten: true))
    }

    /// Die Karte passt mittig und im Seitenverhältnis in die Fläche; der Rückweg trifft die Kartenmitte.
    func testKartenpunktPasstMittigEin() {
        let bild = MuskelPfade.ahmed.bildVorne
        let r = bild.rahmen
        let breit = CGSize(width: 800, height: 640)
        let s = bild.massstab(in: breit)
        XCTAssertEqual(s, 640 / r.height, accuracy: 0.0001)
        let mitte = bild.kartenpunkt(CGPoint(x: 400, y: 320), in: breit)
        XCTAssertEqual(mitte.x, r.midX, accuracy: 0.001)
        XCTAssertEqual(mitte.y, r.midY, accuracy: 0.001)
        let ecke = bild.kartenpunkt(.zero, in: CGSize(width: r.width / 2, height: r.height / 2))
        XCTAssertEqual(ecke.x, r.minX, accuracy: 0.001)
        XCTAssertEqual(ecke.y, r.minY, accuracy: 0.001)
    }

    func testPfadLeser() {
        let dreieck = MuskelPfade.pfad("M 0 0 L 10 0 L 10 10 Z")
        XCTAssertTrue(dreieck.contains(CGPoint(x: 8, y: 3)))
        XCTAssertFalse(dreieck.contains(CGPoint(x: 2, y: 8)))
        // Bogen von (0,0) nach (10,0), höchster Punkt bei y = 7,5.
        let bogen = MuskelPfade.pfad("M 0 0 C 0 10 10 10 10 0 Z")
        XCTAssertTrue(bogen.contains(CGPoint(x: 5, y: 3)))
        XCTAssertFalse(bogen.contains(CGPoint(x: 5, y: 9)))
        XCTAssertEqual(bogen.boundingRect.maxY, 7.5, accuracy: 0.01)
        XCTAssertTrue(MuskelPfade.pfad("").isEmpty)
    }

    /// Nur hinten sichtbare Gruppen zeigen hinten (der Rücken), alle anderen vorne, auch wenn sie
    /// zusätzlich hinten liegen (Schulter, Trizeps, Unterarme, Beine).
    func testFokusWaehltDieSeiteMitDerGruppe() {
        let figur = MuskelPfade.ahmed
        XCTAssertTrue(figur.hinten(fuer: .ruecken))
        XCTAssertFalse(figur.hinten(fuer: .nacken))
        XCTAssertFalse(figur.hinten(fuer: .trizeps))
        XCTAssertFalse(figur.hinten(fuer: .brust))
        XCTAssertFalse(figur.hinten(fuer: .bizeps))
        XCTAssertFalse(figur.hinten(fuer: .bauch))
        XCTAssertFalse(figur.hinten(fuer: .schulter))
        XCTAssertFalse(figur.hinten(fuer: .unterarme))
        XCTAssertFalse(figur.hinten(fuer: .beine))
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
        let breite = hoehe * MuskelPfade.figur(person).seitenverhaeltnis
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
