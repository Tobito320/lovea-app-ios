import AVFoundation
import CoreImage
import SwiftUI
import XCTest
@testable import Lovea

/// Reine Rechnung hinter dem CapCut-Editor: Zeitleiste (Zeit <-> Position, Trim-Grenzen,
/// Abspiel-Sprünge), Element-Grenzen und die Filterstärke.
final class SnapCapCutTests: XCTestCase {
    private let pps = SnapZeitleisteRechnung.punkteProSekunde

    // MARK: Zeitleiste

    func testPositionIstZeitMalPunkteProSekundeUndNieNegativ() {
        XCTAssertEqual(SnapZeitleisteRechnung.x(zeit: 3.5), 3.5 * pps, accuracy: 0.001)
        XCTAssertEqual(SnapZeitleisteRechnung.x(zeit: -2), 0)
    }

    func testStreifenNachRechtsZiehenGehtZurueckInDerZeit() {
        let neu = SnapZeitleisteRechnung.zeit(start: 5, verschiebung: pps, dauer: 10)
        XCTAssertEqual(neu, 4, accuracy: 0.001)
        XCTAssertEqual(SnapZeitleisteRechnung.zeit(start: 1, verschiebung: pps * 9, dauer: 10), 0)
        XCTAssertEqual(SnapZeitleisteRechnung.zeit(start: 9, verschiebung: -pps * 9, dauer: 10), 10)
    }

    func testAnfangsGriffBleibtVorDemEnde() {
        var plan = SnapSchnitt(dauer: 10)
        plan.kuerzen(anfang: 0, ende: 6)
        let weit = SnapZeitleisteRechnung.anfang(start: 0, verschiebung: pps * 20, plan: plan)
        XCTAssertEqual(weit, 6 - SnapSchnitt.mindestdauer, accuracy: 0.001)
        XCTAssertEqual(SnapZeitleisteRechnung.anfang(start: 1, verschiebung: -pps * 5, plan: plan), 0)
    }

    func testEndGriffBleibtHinterDemAnfangUndInDerVideolaenge() {
        var plan = SnapSchnitt(dauer: 10)
        plan.kuerzen(anfang: 4, ende: 10)
        let kurz = SnapZeitleisteRechnung.ende(start: 10, verschiebung: -pps * 20, plan: plan)
        XCTAssertEqual(kurz, 4 + SnapSchnitt.mindestdauer, accuracy: 0.001)
        XCTAssertEqual(SnapZeitleisteRechnung.ende(start: 8, verschiebung: pps * 20, plan: plan), 10)
    }

    func testSprungZielNurAusserhalbDerBleibendenTeile() {
        var plan = SnapSchnitt(dauer: 10)
        plan.kuerzen(anfang: 2, ende: 9)
        plan.entfernen(von: 4, bis: 6)
        XCTAssertNil(SnapZeitleisteRechnung.sprungZiel(plan: plan, zeit: 3))
        XCTAssertEqual(SnapZeitleisteRechnung.sprungZiel(plan: plan, zeit: 1), 2)
        XCTAssertEqual(SnapZeitleisteRechnung.sprungZiel(plan: plan, zeit: 5)!, 6, accuracy: 0.001)
        // Hinter dem letzten Teil: Schleife zurück an den Anfang.
        XCTAssertEqual(SnapZeitleisteRechnung.sprungZiel(plan: plan, zeit: 9.5)!, 2, accuracy: 0.001)
    }

    func testLueckenZeigenGekuerztesUndEntferntes() {
        var plan = SnapSchnitt(dauer: 10)
        plan.kuerzen(anfang: 1, ende: 9)
        plan.entfernen(von: 4, bis: 5)
        let luecken = SnapZeitleisteRechnung.luecken(plan: plan)
        XCTAssertEqual(luecken.count, 3)
        XCTAssertEqual(luecken[0], SnapSchnitt.Bereich(von: 0, bis: 1))
        XCTAssertEqual(luecken[1], SnapSchnitt.Bereich(von: 9, bis: 10))
        XCTAssertEqual(luecken[2], SnapSchnitt.Bereich(von: 4, bis: 5))
        XCTAssertTrue(SnapZeitleisteRechnung.luecken(plan: SnapSchnitt(dauer: 10)).isEmpty)
    }

    func testFilmbilderAnzahlProSekundeMitDeckel() {
        XCTAssertEqual(SnapFilmbilder.anzahl(dauer: 0.2), 1)
        XCTAssertEqual(SnapFilmbilder.anzahl(dauer: 7.4), 8)
        XCTAssertEqual(SnapFilmbilder.anzahl(dauer: 600), 40)
    }

    // MARK: Elemente

    func testElementBleibtImBild() {
        XCTAssertEqual(SnapElementRechnung.imBild(1.4, -0.2), CGPoint(x: 1, y: 0))
        XCTAssertEqual(SnapElementRechnung.imBild(0.3, 0.6), CGPoint(x: 0.3, y: 0.6))
    }

    // MARK: Panel-Leiste

    func testLeisteFuerVideoUndFoto() {
        XCTAssertEqual(SnapPanel.leiste(video: true, filterAn: true), [.bearbeiten, .ton, .text, .sticker, .filter, .zeichnen])
        XCTAssertEqual(SnapPanel.leiste(video: false, filterAn: false), [.text, .sticker, .zeichnen])
    }

    // MARK: Filterstärke

    private let testBild = CIImage(color: CIColor(red: 0.8, green: 0.2, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))

    private func pixel(_ bild: CIImage) -> [UInt8] {
        var daten = [UInt8](repeating: 0, count: 4)
        SnapFilterKontext.shared.context.render(bild, toBitmap: &daten, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                                format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return daten
    }

    func testStaerkeNullIstOriginalUndEinsIstVoll() {
        let filter = SnapFilter.allCases.first { $0 != .original && $0 != .film }!
        XCTAssertEqual(pixel(filter.anwenden(auf: testBild, staerke: 0)), pixel(testBild))
        XCTAssertEqual(pixel(filter.anwenden(auf: testBild, staerke: 1)), pixel(filter.anwenden(auf: testBild)))
    }

    func testStaerkeBehaeltAusdehnung() {
        for filter in SnapFilter.allCases {
            XCTAssertEqual(filter.anwenden(auf: testBild, staerke: 0.5).extent, testBild.extent, "\(filter.rawValue)")
        }
    }

    func testVideoKompositionBeiStaerkeNullGibtNil() async {
        let komposition = await SnapFilter.allCases.first { $0 != .original }!.videoKomposition(fuer: AVMutableComposition(), staerke: 0)
        XCTAssertNil(komposition)
    }
}
