import AVFoundation
import CoreImage
import SwiftUI
import XCTest
@testable import Lovea

/// Reine Rechnung hinter dem CapCut-Editor: Zeitleiste (Zeit <-> Position, Trim-Grenzen,
/// Abspiel-Sprünge), Eck-Griff der Elemente und die Filterstärke.
final class SnapCapCutTests: XCTestCase {
    private let pps = SnapZeitleisteRechnung.punkteProSekunde

    // MARK: Zeitleiste

    func testZeitUndPositionSindUmkehrbar() {
        let x = SnapZeitleisteRechnung.x(zeit: 3.5)
        XCTAssertEqual(x, 3.5 * pps, accuracy: 0.001)
        XCTAssertEqual(SnapZeitleisteRechnung.zeit(x: x, dauer: 10), 3.5, accuracy: 0.001)
    }

    func testZeitWirdAufDauerGeklammert() {
        XCTAssertEqual(SnapZeitleisteRechnung.zeit(x: -50, dauer: 10), 0)
        XCTAssertEqual(SnapZeitleisteRechnung.zeit(x: 100_000, dauer: 10), 10)
        XCTAssertEqual(SnapZeitleisteRechnung.x(zeit: -2), 0)
    }

    func testStreifenLiegtUnterDerMitteLinie() {
        // Bei Zeit t liegt der Punkt x(t) genau auf der Mitte.
        let versatz = SnapZeitleisteRechnung.versatz(zeit: 4, mitte: 195)
        XCTAssertEqual(versatz + SnapZeitleisteRechnung.x(zeit: 4), 195, accuracy: 0.001)
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

    func testAnzeigeFormat() {
        XCTAssertEqual(SnapZeitleisteRechnung.anzeige(zeit: 3, dauer: 12), "0:03 / 0:12")
        XCTAssertEqual(SnapZeitleisteRechnung.anzeige(zeit: 65, dauer: 125), "1:05 / 2:05")
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

    // MARK: Element-Griff

    func testGriffZiehtWeiterWegVergroessert() {
        let mitte = CGPoint(x: 100, y: 100)
        let ergebnis = SnapElementRechnung.griff(mitte: mitte, start: CGPoint(x: 150, y: 100), aktuell: CGPoint(x: 200, y: 100),
                                                 startSkala: 1, startWinkel: 0)
        XCTAssertEqual(ergebnis.skala, 2, accuracy: 0.001)
        XCTAssertEqual(ergebnis.winkel, 0, accuracy: 0.001)
    }

    func testGriffDrehtUmDieMitte() {
        let mitte = CGPoint(x: 0, y: 0)
        let ergebnis = SnapElementRechnung.griff(mitte: mitte, start: CGPoint(x: 10, y: 0), aktuell: CGPoint(x: 0, y: 10),
                                                 startSkala: 1, startWinkel: 30)
        XCTAssertEqual(ergebnis.skala, 1, accuracy: 0.001)
        XCTAssertEqual(ergebnis.winkel, 120, accuracy: 0.001)
    }

    func testGriffKlammertDieSkala() {
        let mitte = CGPoint.zero
        let klein = SnapElementRechnung.griff(mitte: mitte, start: CGPoint(x: 100, y: 0), aktuell: CGPoint(x: 1, y: 0), startSkala: 1, startWinkel: 0)
        XCTAssertEqual(klein.skala, SnapElementRechnung.skalaGrenzen.lowerBound, accuracy: 0.001)
        let gross = SnapElementRechnung.griff(mitte: mitte, start: CGPoint(x: 10, y: 0), aktuell: CGPoint(x: 1000, y: 0), startSkala: 1, startWinkel: 0)
        XCTAssertEqual(gross.skala, SnapElementRechnung.skalaGrenzen.upperBound, accuracy: 0.001)
    }

    func testGriffAufDerMitteBleibtUnveraendert() {
        let ergebnis = SnapElementRechnung.griff(mitte: .zero, start: .zero, aktuell: CGPoint(x: 50, y: 50), startSkala: 2, startWinkel: 15)
        XCTAssertEqual(ergebnis.skala, 2)
        XCTAssertEqual(ergebnis.winkel, 15)
    }

    func testVerschiebenRechnetInBruchteilenUndBegrenzt() {
        let ziel = SnapElementRechnung.verschoben(start: CGPoint(x: 0.5, y: 0.5), verschiebung: CGSize(width: 50, height: -100),
                                                  groesse: CGSize(width: 200, height: 400), begrenzung: SnapElementRechnung.imBild)
        XCTAssertEqual(ziel.x, 0.75, accuracy: 0.001)
        XCTAssertEqual(ziel.y, 0.25, accuracy: 0.001)
        let raus = SnapElementRechnung.verschoben(start: CGPoint(x: 0.9, y: 0.1), verschiebung: CGSize(width: 1000, height: -1000),
                                                  groesse: CGSize(width: 200, height: 400), begrenzung: SnapElementRechnung.imBild)
        XCTAssertEqual(raus, CGPoint(x: 1, y: 0))
    }

    func testHelleFarbeBekommtDunkleBalkenSchrift() {
        XCTAssertTrue(SnapElementRechnung.istHell(.white))
        XCTAssertFalse(SnapElementRechnung.istHell(.black))
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
