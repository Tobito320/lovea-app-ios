import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// p57: Haustiere. Schwarze Kuschelkatze im Katalog und gezeichnet, alle Tiere größer und detailreicher, zweite
/// Ansicht "liegt". Die Tests messen die sichtbare Pixelbox jedes Tiers (Scale 1, Maßeinheit = Figurenpunkte) und
/// schreiben die Tafeln `p57-tiere` (neben Annika: Profil, Halbfigur, Leiste 44 pt, Shop-Kachel, Shop-Detail)
/// und `p57-posen` (steht und liegt groß, auf dunklem und hellem Grund).
@MainActor
final class HaustierTests: XCTestCase {
    private let tiere = ["tier.hund-braun", "tier.hund-schwarz", "tier.katze-grau", "tier.katze-orange",
                         "tier.katze-schwarz", "tier.hase-weiss", "tier.vogel-blau"]

    private struct Box {
        let breite: Int
        let hoehe: Int
        let sichtbar: Int
        let amRand: Bool
    }

    /// Zeichnet das Tier allein auf 240 x 200 (Boden unten Mitte) und misst die Box der sichtbaren Pixel.
    private func vermesse(_ id: String, pose: HaustierPose, groesse: CGFloat = 1) -> Box? {
        let ansicht = Canvas { ctx, _ in
            zeichneHaustier(ctx, id: id, boden: P(120, 190), groesse: groesse, nachLinks: false, pose: pose)
        }
        .frame(width: 240, height: 200)
        let r = ImageRenderer(content: ansicht)
        r.scale = 1
        guard let cg = r.uiImage?.cgImage else { return nil }
        let b = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: b * h * 4)
        let ok: Bool = px.withUnsafeMutableBytes { roh in
            guard let ctx = CGContext(data: roh.baseAddress, width: b, height: h, bitsPerComponent: 8, bytesPerRow: b * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: b, height: h))
            return true
        }
        guard ok else { return nil }
        var minX = b, maxX = -1, minY = h, maxY = -1, n = 0
        for y in 0..<h {
            for x in 0..<b where px[(y * b + x) * 4 + 3] > 40 {
                n += 1
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return Box(breite: 0, hoehe: 0, sichtbar: 0, amRand: false) }
        return Box(breite: maxX - minX + 1, hoehe: maxY - minY + 1, sichtbar: n,
                   amRand: minX <= 0 || minY <= 0 || maxX >= b - 1 || maxY >= h - 1)
    }

    // MARK: - Katalog

    func testSchwarzeKatzeIstImKatalogUndGezeichnet() throws {
        let bundle = Bundle(for: FigurenModell.self)
        let url = try XCTUnwrap(bundle.url(forResource: "katalog", withExtension: "json")
                                ?? bundle.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop"))
        let alle = try JSONDecoder().decode([ShopArtikel].self, from: try Data(contentsOf: url))
        let katze = try XCTUnwrap(alle.first { $0.id == "tier.katze-schwarz" })
        XCTAssertEqual(katze.kategorie, "tier")
        XCTAssertTrue((3000...6000).contains(katze.preis))
        XCTAssertEqual(haustierKatalog["tier.katze-schwarz"]?.art, .kuschelkatze)
    }

    // MARK: - Größe und Sichtbarkeit

    /// Mindesthöhe je Tier in Figurenpunkten bei Größe 1 (Hase und Vogel waren im Profil zu klein).
    func testTiereSindGrossGenugUndNichtAmRand() throws {
        let minHoehe: [String: Int] = ["tier.hund-braun": 55, "tier.hund-schwarz": 55, "tier.katze-grau": 80,
                                       "tier.katze-orange": 80, "tier.katze-schwarz": 85, "tier.hase-weiss": 100,
                                       "tier.vogel-blau": 85]
        for id in tiere {
            let box = try XCTUnwrap(vermesse(id, pose: .steht), id)
            XCTAssertGreaterThanOrEqual(box.hoehe, minHoehe[id] ?? 0, "\(id): nur \(box.hoehe) hoch")
            XCTAssertLessThanOrEqual(box.breite, 125, "\(id): \(box.breite) breit, stößt an die Figur")
            XCTAssertGreaterThanOrEqual(box.sichtbar, 1000, "\(id): zu wenig sichtbare Fläche")
            XCTAssertFalse(box.amRand, "\(id): ragt aus der Zeichenfläche")
        }
    }

    func testLiegendeAnsichtIstNiedrigerUndSichtbar() throws {
        for id in tiere {
            let steht = try XCTUnwrap(vermesse(id, pose: .steht), id)
            let liegt = try XCTUnwrap(vermesse(id, pose: .liegt), id)
            XCTAssertGreaterThanOrEqual(liegt.sichtbar, 900, "\(id) liegt: zu wenig sichtbar")
            XCTAssertFalse(liegt.amRand, "\(id) liegt: ragt aus der Zeichenfläche")
            XCTAssertLessThanOrEqual(liegt.breite, 125, "\(id) liegt: \(liegt.breite) breit")
            XCTAssertNotEqual(liegt.hoehe, steht.hoehe, "\(id): liegt sieht aus wie steht")
        }
    }

    /// Die Standard-Pose bleibt die alte Signatur: ohne `pose` wird gestanden.
    func testStandardPoseIstSteht() throws {
        let ohne = Canvas { ctx, _ in zeichneHaustier(ctx, id: "tier.katze-schwarz", boden: P(120, 190)) }.frame(width: 240, height: 200)
        let mit = Canvas { ctx, _ in zeichneHaustier(ctx, id: "tier.katze-schwarz", boden: P(120, 190), pose: .steht) }.frame(width: 240, height: 200)
        let a = ImageRenderer(content: ohne)
        let b = ImageRenderer(content: mit)
        a.scale = 1
        b.scale = 1
        XCTAssertEqual(a.uiImage?.pngData(), b.uiImage?.pngData())
    }

    // MARK: - Tafeln

    private func annika(_ id: String?) -> FigurAussehen {
        var a = FigurAussehen.standard(for: .annika)
        a.tier = id
        return a
    }

    private func figur(_ a: FigurAussehen, groesse: CGFloat, ganz: Bool) -> AnyView {
        AnyView(FigurView(a, zustand: .ruhig, groesse: groesse, animiert: false, ganzkoerper: ganz))
    }

    func testTafelTiere() {
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for id in tiere {
            let name = id.split(separator: ".").last.map(String.init) ?? id
            let a = annika(id)
            zellen.append((titel: "\(name): Profil", ansicht: figur(a, groesse: 220, ganz: true)))
            zellen.append((titel: "\(name): Halbfigur", ansicht: figur(a, groesse: 140, ganz: false)))
            zellen.append((titel: "\(name): Leiste 44 pt", ansicht: figur(a, groesse: 44, ganz: false)))
            zellen.append((titel: "\(name): Shop-Kachel", ansicht: figur(a, groesse: 118, ganz: true)))
            zellen.append((titel: "\(name): Shop-Detail", ansicht: figur(a, groesse: 260, ganz: true)))
        }
        RenderTafel.speichern("p57-tiere", spalten: 5, zellen: zellen)
    }

    /// Jedes Tier allein, groß: steht auf dunklem Grund, liegt auf dunklem Grund, steht auf hellem Grund.
    func testTafelPosen() {
        func zelle(_ id: String, _ pose: HaustierPose, dunkel: Bool) -> AnyView {
            AnyView(
                Canvas { ctx, _ in
                    zeichneHaustier(ctx, id: id, boden: P(130, 205), groesse: 1.7, nachLinks: false, pose: pose)
                }
                .frame(width: 260, height: 225)
                .background(dunkel ? Color(white: 0.14) : Color(white: 0.95))
            )
        }
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for id in tiere {
            let name = id.split(separator: ".").last.map(String.init) ?? id
            zellen.append((titel: "\(name): steht", ansicht: zelle(id, .steht, dunkel: true)))
            zellen.append((titel: "\(name): liegt", ansicht: zelle(id, .liegt, dunkel: true)))
            zellen.append((titel: "\(name): steht hell", ansicht: zelle(id, .steht, dunkel: false)))
        }
        RenderTafel.speichern("p57-posen", spalten: 3, zellen: zellen)
    }
}
