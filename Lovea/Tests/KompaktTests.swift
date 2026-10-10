import SwiftUI
import XCTest
@testable import Lovea

/// p66 kompaktes Design: Abstands-Raster, Chat-Zeile und Health-Karte. Höhen und Pixel werden
/// gerendert gemessen, nicht aus dem Code gelesen.
@MainActor
final class KompaktTests: XCTestCase {
    private func bild<V: View>(_ ansicht: V) -> CGImage? {
        let renderer = ImageRenderer(content: ansicht)
        renderer.scale = 1
        return renderer.cgImage
    }

    /// RGBA (0...255) des Pixels (x, y), y von oben.
    private func pixel(_ bild: CGImage, _ x: Int, _ y: Int) -> [Int] {
        var daten = [UInt8](repeating: 0, count: 4)
        daten.withUnsafeMutableBytes { zeiger in
            let kontext = CGContext(
                data: zeiger.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            kontext?.draw(bild, in: CGRect(x: -x, y: -(bild.height - 1 - y), width: bild.width, height: bild.height))
        }
        return daten.map(Int.init)
    }

    private func zeilenHoehe(ort: String?) -> Int {
        let zeile = ChatListenZeile(
            partner: .annika, vorschau: "Bis später, hdl", zeit: "vor 5 Minuten",
            ungelesen: 2, ort: ort, online: true, animiert: false
        )
        return bild(zeile.frame(width: 358))?.height ?? 0
    }

    func testAbstandSitztAufDemVierPunktRaster() {
        let werte: [CGFloat] = [Abstand.xs, Abstand.s, Abstand.m, Abstand.l, Abstand.xl]
        XCTAssertEqual(werte, werte.sorted(), "steigend")
        for wert in werte { XCTAssertEqual(wert.truncatingRemainder(dividingBy: 4), 0, "\(wert) ist kein Vielfaches von 4") }
        XCTAssertLessThan(Rundung.klein, Rundung.karte)
    }

    func testChatZeileOhneOrtIstHoechstens80Hoch() {
        let hoehe = zeilenHoehe(ort: nil)
        XCTAssertGreaterThan(hoehe, 50, "gerendert")
        XCTAssertLessThanOrEqual(hoehe, 80, "vorher rund 94 pt")
    }

    func testChatZeileMitOrtIstHoechstens92Hoch() {
        let hoehe = zeilenHoehe(ort: "Schule")
        XCTAssertGreaterThan(hoehe, 50, "gerendert")
        XCTAssertLessThanOrEqual(hoehe, 92, "vorher rund 96 pt")
    }

    func testHealthKarteIstFlachOhneVerlaufUndRand() throws {
        let karte = Color.clear.frame(width: 120, height: 120).healthKarte(.red)
        let aufnahme = try XCTUnwrap(bild(karte))
        let oben = pixel(aufnahme, 60, 20)
        let unten = pixel(aufnahme, 60, 100)
        let rand = pixel(aufnahme, 0, 60)
        let innen = pixel(aufnahme, 8, 60)
        XCTAssertGreaterThan(oben[3], 0, "die Karte zeichnet eine Fläche")
        for kanal in 0..<3 {
            XCTAssertLessThanOrEqual(abs(oben[kanal] - unten[kanal]), 2, "kein Verlauf, Kanal \(kanal)")
            XCTAssertLessThanOrEqual(abs(rand[kanal] - innen[kanal]), 2, "kein Rand, Kanal \(kanal)")
        }
    }
}
