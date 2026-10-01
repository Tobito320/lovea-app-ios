import UIKit
import XCTest
@testable import Lovea

/// Pure rect math behind the WYSIWYG photo crop (Z-R7): the preview's visible unit rect
/// (`metadataOutputRectConverted`, origin top-left, 0...1) converted to pixel bounds on the full
/// captured image.
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
    /// lassen (das gibt nil zurück und `zugeschnitten(auf:)` fiele aufs unbeschnittene Bild zurück).
    func testUeberstandWirdGeklemmt() {
        let einheit = CGRect(x: 0.9, y: 0, width: 0.3, height: 1)
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: einheit, bildGroesse: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(rechteck, CGRect(x: 900, y: 0, width: 100, height: 1000))
    }

    func testNullGrossesBildGibtLeeresRechteckZurueck() {
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: CGRect(x: 0, y: 0, width: 1, height: 1), bildGroesse: .zero)
        XCTAssertEqual(rechteck, .zero)
    }
}
