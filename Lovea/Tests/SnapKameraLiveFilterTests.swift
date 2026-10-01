import CoreImage
import XCTest
@testable import Lovea

/// Reine Logik hinter dem Live-Filter in der Kamera (R9 LIVE): Filter-Index weiter/zurück mit
/// Klemmen, die Akku-Regel-Entscheidung "Live-Renderer aktiv ja/nein", und die Aspect-Fill-Geometrie
/// hinter "derselbe Ausschnitt wie die Vorschau" — alles ohne Gerät/Kamera/Metal testbar.
final class SnapKameraLiveFilterTests: XCTestCase {
    // MARK: - SnapFilter.benachbart

    func testBenachbartVorwaertsGehtEinenWeiter() {
        let alle = SnapFilter.allCases
        let start = alle[2]
        XCTAssertEqual(SnapFilter.benachbart(zu: start, vorwaerts: true), alle[3])
    }

    func testBenachbartRueckwaertsGehtEinenZurueck() {
        let alle = SnapFilter.allCases
        let start = alle[2]
        XCTAssertEqual(SnapFilter.benachbart(zu: start, vorwaerts: false), alle[1])
    }

    func testBenachbartKlemmtAmEndeFest() {
        let letzter = SnapFilter.allCases.last!
        XCTAssertEqual(SnapFilter.benachbart(zu: letzter, vorwaerts: true), letzter)
    }

    func testBenachbartKlemmtAmAnfangFest() {
        let erster = SnapFilter.allCases.first!
        XCTAssertEqual(SnapFilter.benachbart(zu: erster, vorwaerts: false), erster)
    }

    // MARK: - SnapLiveFilterEntscheidung

    func testLiveRendererLaeuftNurBeiNichtOriginalUndVerfuegbar() {
        XCTAssertTrue(SnapLiveFilterEntscheidung.aktiv(filter: .warm, ausgabeVerfuegbar: true))
    }

    func testLiveRendererLaeuftNichtBeiOriginal() {
        XCTAssertFalse(SnapLiveFilterEntscheidung.aktiv(filter: .warm, ausgabeVerfuegbar: false))
        XCTAssertFalse(SnapLiveFilterEntscheidung.aktiv(filter: .original, ausgabeVerfuegbar: true))
    }

    func testLiveRendererLaeuftNichtOhneOutputAuchMitFilter() {
        XCTAssertFalse(SnapLiveFilterEntscheidung.aktiv(filter: .noir, ausgabeVerfuegbar: false))
    }

    // MARK: - SnapLiveFilterRenderer.aspectFillZugeschnitten

    /// Breiteres Bild als das Ziel: an den Seiten beschnitten, Ergebnis exakt die Zielgröße.
    func testAspectFillSchneidetBreiteresBildAufZielgroesseZu() {
        let bild = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 400, height: 100))
        let ziel = CGSize(width: 100, height: 100)
        let ergebnis = SnapLiveFilterRenderer.aspectFillZugeschnitten(bild, ziel: ziel)
        XCTAssertEqual(ergebnis.extent.width, ziel.width, accuracy: 0.001)
        XCTAssertEqual(ergebnis.extent.height, ziel.height, accuracy: 0.001)
    }

    /// Höheres Bild als das Ziel: oben/unten beschnitten, Ergebnis exakt die Zielgröße.
    func testAspectFillSchneidetHoeheresBildAufZielgroesseZu() {
        let bild = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 400))
        let ziel = CGSize(width: 200, height: 100)
        let ergebnis = SnapLiveFilterRenderer.aspectFillZugeschnitten(bild, ziel: ziel)
        XCTAssertEqual(ergebnis.extent.width, ziel.width, accuracy: 0.001)
        XCTAssertEqual(ergebnis.extent.height, ziel.height, accuracy: 0.001)
    }

    func testAspectFillMitLeererAusdehnungGibtEingabeUnverandertZurueck() {
        let leer = CIImage(color: .red).cropped(to: .zero)
        let ergebnis = SnapLiveFilterRenderer.aspectFillZugeschnitten(leer, ziel: CGSize(width: 100, height: 100))
        XCTAssertEqual(ergebnis.extent, leer.extent)
    }
}
