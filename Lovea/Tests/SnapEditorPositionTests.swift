import SwiftUI
import XCTest
@testable import Lovea

/// p66: Snap editor, position of text/sticker in the export and the editor's gestures as pure logic.
/// Every test pins one thing that could go wrong between the live preview and the flattened photo.
@MainActor
final class SnapEditorPositionTests: XCTestCase {
    private let flaeche = CGSize(width: 200, height: 300)

    // MARK: - Render helpers (pure SwiftUI, no UIGraphicsImageRenderer)

    private func bild<V: View>(_ inhalt: V) -> UIImage? {
        let renderer = ImageRenderer(content: inhalt)
        renderer.scale = 1
        return renderer.uiImage
    }

    private func rotesRechteck(_ breite: CGFloat, _ hoehe: CGFloat) throws -> UIImage {
        try XCTUnwrap(bild(Color.red.frame(width: breite, height: hoehe)))
    }

    /// Box around all fully red pixels, in pixels from the top left (the same axes as `.position`).
    private func rotUmriss(_ bild: UIImage?) throws -> CGRect {
        let cg = try XCTUnwrap(bild?.cgImage)
        let breite = cg.width, hoehe = cg.height
        var daten = [UInt8](repeating: 0, count: breite * hoehe * 4)
        let umriss: CGRect? = daten.withUnsafeMutableBytes { zeiger in
            guard let kontext = CGContext(
                data: zeiger.baseAddress, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: breite * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            kontext.draw(cg, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
            let bytes = zeiger.bindMemory(to: UInt8.self)
            var minX = breite, minY = hoehe, maxX = -1, maxY = -1
            for y in 0..<hoehe {
                for x in 0..<breite {
                    let i = (y * breite + x) * 4
                    guard bytes[i + 3] > 200, bytes[i] > 200, bytes[i + 1] < 60, bytes[i + 2] < 60 else { continue }
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            guard maxX >= 0 else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        return try XCTUnwrap(umriss, "no red pixels in the render")
    }

    private func export(sticker: [SnapEditor.SnapSticker] = [], text: SnapEditor.SnapText = .init()) -> UIImage? {
        bild(SnapUeberlagerung(linien: [], sticker: sticker, text: text, groesse: flaeche))
    }

    /// The editor's own recipe (`SnapEditor.stickerElement`) inside the live shell.
    private func live(_ sticker: SnapEditor.SnapSticker) -> UIImage? {
        bild(
            ZStack {
                SnapElementHuelle(
                    x: .constant(sticker.x), y: .constant(sticker.y), skala: .constant(sticker.skala), winkel: .constant(sticker.winkel),
                    groesse: flaeche, ausgewaehlt: false, begrenzung: SnapElementRechnung.imBild,
                    onAntippen: {}, onLoeschen: {}
                ) {
                    Image(uiImage: sticker.bild).resizable().scaledToFit().frame(width: flaeche.width * 0.28 * sticker.skala)
                }
            }
            .frame(width: flaeche.width, height: flaeche.height)
        )
    }

    private func sticker(x: CGFloat, y: CGFloat, skala: CGFloat = 1, winkel: Double = 0, breite: CGFloat = 40, hoehe: CGFloat = 20) throws -> SnapEditor.SnapSticker {
        var s = SnapEditor.SnapSticker(bild: try rotesRechteck(breite, hoehe))
        s.x = x; s.y = y; s.skala = skala; s.winkel = winkel
        return s
    }

    // MARK: - Export position = editor position

    func testStickerMitteImExportAmBruchteil() throws {
        let umriss = try rotUmriss(export(sticker: [try sticker(x: 0.25, y: 0.75)]))
        XCTAssertEqual(umriss.midX, 0.25 * flaeche.width, accuracy: 2)
        XCTAssertEqual(umriss.midY, 0.75 * flaeche.height, accuracy: 2)
    }

    func testStickerBreiteIst28ProzentMalSkala() throws {
        let einfach = try rotUmriss(export(sticker: [try sticker(x: 0.5, y: 0.5, skala: 1)]))
        let doppelt = try rotUmriss(export(sticker: [try sticker(x: 0.5, y: 0.5, skala: 2)]))
        XCTAssertEqual(einfach.width, flaeche.width * 0.28, accuracy: 2)
        XCTAssertEqual(doppelt.width, flaeche.width * 0.56, accuracy: 2)
        XCTAssertEqual(doppelt.midX, einfach.midX, accuracy: 2, "scaling keeps the centre")
    }

    func testStickerDrehungUmDieMitte() throws {
        let umriss = try rotUmriss(export(sticker: [try sticker(x: 0.4, y: 0.3, winkel: 90)]))
        XCTAssertEqual(umriss.width, flaeche.width * 0.28 / 2, accuracy: 2, "56 x 28 turned by 90 degrees is 28 x 56")
        XCTAssertEqual(umriss.height, flaeche.width * 0.28, accuracy: 2)
        XCTAssertEqual(umriss.midX, 0.4 * flaeche.width, accuracy: 2)
        XCTAssertEqual(umriss.midY, 0.3 * flaeche.height, accuracy: 2)
    }

    func testLiveUndExportGleichBeiSkalaUndDrehung() throws {
        let element = try sticker(x: 0.3, y: 0.65, skala: 1.5, winkel: 30)
        let imExport = try rotUmriss(export(sticker: [element]))
        let imEditor = try rotUmriss(live(element))
        XCTAssertEqual(imEditor.midX, imExport.midX, accuracy: 1.5)
        XCTAssertEqual(imEditor.midY, imExport.midY, accuracy: 1.5)
        XCTAssertEqual(imEditor.width, imExport.width, accuracy: 1.5)
        XCTAssertEqual(imEditor.height, imExport.height, accuracy: 1.5)
    }

    func testTextMitteImExportAmBruchteil() throws {
        var text = SnapEditor.SnapText()
        text.text = "MMMM"; text.farbe = .red; text.x = 0.3; text.y = 0.6; text.skala = 2
        let umriss = try rotUmriss(export(text: text))
        let schrift = flaeche.width * 0.07 * 2
        XCTAssertEqual(umriss.midX, 0.3 * flaeche.width, accuracy: schrift * 0.5)
        XCTAssertEqual(umriss.midY, 0.6 * flaeche.height, accuracy: schrift * 0.5)
    }

    func testTextSchriftWaechstMitDerBreite() throws {
        var text = SnapEditor.SnapText()
        text.text = "MMMM"; text.farbe = .red
        let schmal = try rotUmriss(bild(SnapTextAnzeige(text: text, breite: 200)))
        let breit = try rotUmriss(bild(SnapTextAnzeige(text: text, breite: 400)))
        XCTAssertEqual(breit.width / schmal.width, 2, accuracy: 0.15, "same fraction of the content width at any export size")
    }

    // MARK: - Shadow is relative too

    func testSchattenWaechstMitDerBreite() {
        let imEditor = SnapElementRechnung.schattenRadius(breite: 390)
        let imExport = SnapElementRechnung.schattenRadius(breite: 2048)
        XCTAssertEqual(imEditor, 3, accuracy: 0.5, "stays close to the old 3 pt in the editor")
        XCTAssertEqual(imExport / imEditor, 2048.0 / 390.0, accuracy: 0.01, "export shadow keeps the editor's look")
    }

    // MARK: - Gestures

    func testZitterndesAntippenAufMarkiertemElementZaehlt() {
        XCTAssertTrue(SnapElementRechnung.zaehltAlsAntippen(verschiebung: CGSize(width: 4, height: -3), warAusgewaehlt: true))
    }

    func testEchtesZiehenZaehltNichtAlsAntippen() {
        XCTAssertFalse(SnapElementRechnung.zaehltAlsAntippen(verschiebung: CGSize(width: 40, height: 2), warAusgewaehlt: true))
    }

    func testErstesAntippenMarkiertNurEinmal() {
        XCTAssertFalse(SnapElementRechnung.zaehltAlsAntippen(verschiebung: CGSize(width: 3, height: 3), warAusgewaehlt: false),
                       "the drag start already selected it, a second tap would open the text editor")
    }

    func testLoeschenZielHatMindestens44() {
        XCTAssertGreaterThanOrEqual(SnapElementRechnung.loeschenZiel, 44)
    }

    // MARK: - Doodle

    private let rot = Color.red

    private func strich(_ doodle: inout SnapDoodle, _ punkte: [CGPoint]) {
        punkte.forEach { doodle.punkt($0) }
        doodle.abschliessen(farbe: rot)
    }

    func testRueckgaengigNimmtNurDieLetzteLinie() {
        var doodle = SnapDoodle()
        strich(&doodle, [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.2, y: 0.2)])
        strich(&doodle, [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.6, y: 0.6)])
        doodle.zurueck()
        XCTAssertEqual(doodle.linien.count, 1)
        XCTAssertEqual(doodle.linien[0].punkte.first, CGPoint(x: 0.1, y: 0.1))
        doodle.zurueck()
        XCTAssertTrue(doodle.linien.isEmpty)
        XCTAssertFalse(doodle.kannZurueck)
        doodle.zurueck()
        XCTAssertTrue(doodle.linien.isEmpty, "undo on an empty list does nothing")
    }

    func testEinzelnerPunktIstKeineLinie() {
        var doodle = SnapDoodle()
        strich(&doodle, [CGPoint(x: 0.3, y: 0.3)])
        XCTAssertTrue(doodle.linien.isEmpty)
        XCTAssertTrue(doodle.laufend.isEmpty)
    }

    func testAbgebrochenerStrichHaengtSichNichtAnDenNaechstenAn() {
        var doodle = SnapDoodle()
        doodle.punkt(CGPoint(x: 0.1, y: 0.1))
        doodle.punkt(CGPoint(x: 0.2, y: 0.2))
        doodle.abbrechen()
        strich(&doodle, [CGPoint(x: 0.8, y: 0.8), CGPoint(x: 0.9, y: 0.9)])
        XCTAssertEqual(doodle.linien.count, 1)
        XCTAssertEqual(doodle.linien[0].punkte, [CGPoint(x: 0.8, y: 0.8), CGPoint(x: 0.9, y: 0.9)])
    }
}
