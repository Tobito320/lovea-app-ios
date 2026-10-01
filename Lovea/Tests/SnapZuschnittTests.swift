import AVFoundation
import UIKit
import XCTest
@testable import Lovea

/// Pure rect math behind the WYSIWYG photo crop (Z-R7): the preview's visible unit rect
/// (`metadataOutputRectConverted`, origin top-left, 0...1, SENSOR-native space) converted to pixel
/// bounds on the sensor-native captured image (`AVCapturePhoto.cgImageRepresentation()`).
final class SnapZuschnittTests: XCTestCase {
    func testVolleFlaecheBleibtUnveraendert() {
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: CGRect(x: 0, y: 0, width: 1, height: 1), bildGroesse: CGSize(width: 1000, height: 2000))
        XCTAssertEqual(rechteck, CGRect(x: 0, y: 0, width: 1000, height: 2000))
    }

    /// Bildformat (4:3, von `.high`) breiter als der Bildschirm (9:19.5) → aspectFill schneidet
    /// oben/unten weg, genau wie ein Preview-Rechteck mit y > 0 das ausdrückt.
    func testObenUndUntenAbgeschnitten() {
        let einheit = CGRect(x: 0, y: 0.1, width: 1, height: 0.8)
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: einheit, bildGroesse: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(rechteck, CGRect(x: 0, y: 100, width: 1000, height: 800))
    }

    func testLinksUndRechtsAbgeschnitten() {
        let einheit = CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: einheit, bildGroesse: CGSize(width: 2000, height: 1000))
        XCTAssertEqual(rechteck, CGRect(x: 500, y: 0, width: 1000, height: 1000))
    }

    /// Ein Rechteck, das (durch Rundung oder einen falschen Aufruf) über den Bildrand hinausragt,
    /// wird auf das Bild geklemmt statt `CGImage.cropping` mit einem ungültigen Rect scheitern zu
    /// lassen (das gibt nil zurück und `zugeschnittenesBild` fiele aufs unbeschnittene Bild zurück).
    func testUeberstandWirdGeklemmt() {
        let einheit = CGRect(x: 0.9, y: 0, width: 0.3, height: 1)
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: einheit, bildGroesse: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(rechteck, CGRect(x: 900, y: 0, width: 100, height: 1000))
    }

    func testNullGrossesBildGibtLeeresRechteckZurueck() {
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: CGRect(x: 0, y: 0, width: 1, height: 1), bildGroesse: .zero)
        XCTAssertEqual(rechteck, .zero)
    }

    /// Konkreter Portrait-Fall mit einem Sensor-Querformat (4000×3000, wie `.high`s 4:3). Vorder-
    /// und Rückkamera liefern für dasselbe Vorschau-Rechteck dasselbe Zuschnitt-Rechteck — das
    /// Rechteck beschreibt nur WAS sichtbar war (Position/Größe im Sensorbild), nicht WIE herum es
    /// gedreht/gespiegelt angezeigt wird. Letzteres regelt allein `SnapBildAusrichtung`
    /// (`testAusrichtungHintenUndVorne` unten) — die Kamera-Seite fließt absichtlich nirgends in
    /// `pixelRechteck` ein.
    func testPortraitRueckkameraUndFrontkameraTeilenDasselbeRechteck() {
        let sensor = CGSize(width: 4000, height: 3000) // Sensor-natives Querformat, beide Kameras
        // Schmaler Bildschirm schneidet seitlich vom (im Sensor-Koordinatensystem weiterhin
        // querformatigen) Bild ab — 20% links, 20% rechts.
        let einheit = CGRect(x: 0.2, y: 0, width: 0.6, height: 1)

        let hinten = SnapZuschnitt.pixelRechteck(einheitsRechteck: einheit, bildGroesse: sensor)
        let vorne = SnapZuschnitt.pixelRechteck(einheitsRechteck: einheit, bildGroesse: sensor)
        XCTAssertEqual(hinten, vorne)
        XCTAssertEqual(hinten, CGRect(x: 800, y: 0, width: 2400, height: 3000))
    }

    /// Schalter "Selfie spiegeln": AUS (Standard) = vorne wie hinten aufrecht und ungespiegelt,
    /// AN = das alte Verhalten (vorne spiegelverkehrt wie die Vorschau). Hinten ändert der Schalter nichts.
    func testAusrichtungJeKameraUndSchalter() {
        XCTAssertEqual(SnapBildAusrichtung.fuer(position: .front, spiegeln: false), .right)
        XCTAssertEqual(SnapBildAusrichtung.fuer(position: .front, spiegeln: true), .leftMirrored)
        XCTAssertEqual(SnapBildAusrichtung.fuer(position: .back, spiegeln: false), .right)
        XCTAssertEqual(SnapBildAusrichtung.fuer(position: .back, spiegeln: true), .right)
    }

    /// Standard ohne gesetzten Wert ist AUS: das Foto kommt ungespiegelt.
    func testSchalterStandardIstAus() {
        let suite = UserDefaults(suiteName: "SnapZuschnittTests.\(UUID().uuidString)")!
        XCTAssertFalse(SnapBildAusrichtung.spiegeln(suite))
        suite.set(true, forKey: SnapBildAusrichtung.schluessel)
        XCTAssertTrue(SnapBildAusrichtung.spiegeln(suite))
    }
}
