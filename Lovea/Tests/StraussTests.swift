import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// p59: die fünf Sträuße (Vektor) und Annikas Auswahl dafür (bis zu 3 auf dem Schrank, 1 in der Vase).
/// Die Pixel-Tests zählen sichtbare Pixel je Größe und vergleichen die Sträuße untereinander, die
/// Tafeln `p59-blumen` und `p59-strauss-N-*` sind zum Ansehen gegen Ahmeds Fotos.
@MainActor
final class StraussTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private struct Bild {
        let breite: Int
        let hoehe: Int
        let rgba: [UInt8]
    }

    private func bild(_ ansicht: some View) -> Bild? {
        let r = ImageRenderer(content: ansicht)
        r.scale = 2
        guard let cg = r.uiImage?.cgImage else { return nil }
        let b = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: b * h * 4)
        let ok: Bool = px.withUnsafeMutableBytes { roh in
            guard let ctx = CGContext(data: roh.baseAddress, width: b, height: h, bitsPerComponent: 8, bytesPerRow: b * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: b, height: h))
            return true
        }
        return ok ? Bild(breite: b, hoehe: h, rgba: px) : nil
    }

    /// Pixel mit Deckung (alles, was der Strauß selbst malt; der Hintergrund bleibt durchsichtig).
    private func sichtbar(_ b: Bild) -> Int {
        stride(from: 3, to: b.rgba.count, by: 4).filter { b.rgba[$0] > 40 }.count
    }

    private func unterschied(_ a: Bild, _ b: Bild) -> Int {
        var n = 0
        for i in stride(from: 0, to: a.rgba.count, by: 4) {
            let d = max(abs(Int(a.rgba[i]) - Int(b.rgba[i])), abs(Int(a.rgba[i + 1]) - Int(b.rgba[i + 1])), abs(Int(a.rgba[i + 2]) - Int(b.rgba[i + 2])))
            if d > 16 || (a.rgba[i + 3] > 40) != (b.rgba[i + 3] > 40) { n += 1 }
        }
        return n
    }

    // MARK: - Die Sträuße

    func testFuenfStraeusseMitStabilenNamen() {
        XCTAssertEqual(StraussArt.allCases.map(\.rawValue), ["lila", "rotBunt", "rosaGerbera", "pinkCreme", "glitzerRot"])
        XCTAssertEqual(Set(StraussArt.allCases.map(\.name)).count, 5)
    }

    func testJederStraussMaltKleinUndGross() throws {
        for art in StraussArt.allCases {
            let klein = try XCTUnwrap(bild(StraussBild(art: art, breite: 44)), "\(art) klein nicht renderbar")
            let gross = try XCTUnwrap(bild(StraussBild(art: art, breite: 200)), "\(art) gross nicht renderbar")
            XCTAssertGreaterThan(sichtbar(klein), 800, "\(art): bei 44 pt kaum sichtbar")
            XCTAssertGreaterThan(sichtbar(gross), 30_000, "\(art): bei 200 pt kaum sichtbar")
        }
    }

    func testDieStraeusseSehenAndersAus() throws {
        let bilder = try StraussArt.allCases.map { try XCTUnwrap(bild(StraussBild(art: $0, breite: 120)), "\($0) nicht renderbar") }
        for i in bilder.indices {
            for j in bilder.indices where j > i {
                XCTAssertGreaterThan(unterschied(bilder[i], bilder[j]), 4000, "\(StraussArt.allCases[i]) und \(StraussArt.allCases[j]) sehen fast gleich aus")
            }
        }
    }

    func testStraussStehtAufDemUnterenRand() throws {
        // Stiele enden am unteren Rand der Zeichenfläche: die untersten Zeilen haben Farbe.
        for art in StraussArt.allCases {
            let b = try XCTUnwrap(bild(StraussBild(art: art, breite: 100)))
            let letzte = (b.hoehe - 4)..<b.hoehe
            let amBoden = letzte.contains { y in (0..<b.breite).contains { x in b.rgba[(y * b.breite + x) * 4 + 3] > 40 } }
            XCTAssertTrue(amBoden, "\(art): steht nicht auf dem unteren Rand")
        }
    }

    // MARK: - Auswahl

    func testSchrankNimmtDreiUndLaesstDenVierten() {
        var z = ZimmerStraeusse()
        z.schrankUmschalten(.lila)
        z.schrankUmschalten(.rotBunt)
        z.schrankUmschalten(.pinkCreme)
        XCTAssertTrue(z.schrankVoll)
        z.schrankUmschalten(.glitzerRot)
        XCTAssertEqual(z.schrank, [.lila, .rotBunt, .pinkCreme])
        z.schrankUmschalten(.rotBunt)
        XCTAssertEqual(z.schrank, [.lila, .pinkCreme])
        z.schrankUmschalten(.glitzerRot)
        XCTAssertEqual(z.schrank, [.lila, .pinkCreme, .glitzerRot])
    }

    func testVaseTauschtUndLeertSich() {
        var z = ZimmerStraeusse()
        z.vaseUmschalten(.rosaGerbera)
        XCTAssertEqual(z.vase, .rosaGerbera)
        z.vaseUmschalten(.lila)
        XCTAssertEqual(z.vase, .lila)
        z.vaseUmschalten(.lila)
        XCTAssertNil(z.vase)
    }

    func testBuehnenWahlTraegtDieIds() {
        let z = ZimmerStraeusse(schrank: [.lila, .glitzerRot], vase: .pinkCreme)
        XCTAssertEqual(z.fuerBuehne, ZuhauseStraeusse(schrank: ["lila", "glitzerRot"], vase: "pinkCreme"))
        XCTAssertEqual(ZimmerStraeusse().fuerBuehne, ZuhauseStraeusse())
        for art in StraussArt.allCases { XCTAssertNotNil(StraussArt(rawValue: art.rawValue)) }
    }

    func testStraussViewKenntNurEchteIds() throws {
        let echt = try XCTUnwrap(bild(StraussView(id: "rotBunt").frame(width: 60, height: 100)))
        let fremd = try XCTUnwrap(bild(StraussView(id: "gibtEsNicht").frame(width: 60, height: 100)))
        XCTAssertGreaterThan(sichtbar(echt), 500)
        XCTAssertEqual(sichtbar(fremd), 0)
    }

    func testSpeichernUndLesenKommtGleichZurueck() {
        let z = ZimmerStraeusse(schrank: [.glitzerRot, .lila], vase: .pinkCreme)
        XCTAssertEqual(ZimmerStraeusse.lesen(z.json), z)
        XCTAssertEqual(ZimmerStraeusse.lesen(ZimmerStraeusse().json), ZimmerStraeusse())
    }

    func testLesenIstTolerant() {
        XCTAssertEqual(ZimmerStraeusse.lesen(nil), ZimmerStraeusse())
        XCTAssertEqual(ZimmerStraeusse.lesen(.string("kaputt")), ZimmerStraeusse())
        let wirr: JSONValue = .object([
            "schrank": .array([.string("lila"), .string("gibtEsNicht"), .number(3), .string("lila"), .string("rotBunt"), .string("pinkCreme"), .string("glitzerRot")]),
            "vase": .string("auchNicht"),
        ])
        let z = ZimmerStraeusse.lesen(wirr)
        XCTAssertEqual(z.schrank, [.lila, .rotBunt, .pinkCreme])
        XCTAssertNil(z.vase)
        XCTAssertEqual(ZimmerStraeusse.lesen(.object(["vase": .string("rotBunt")])), ZimmerStraeusse(schrank: [], vase: .rotBunt))
    }

    // MARK: - Tafeln

    private func zelle(_ art: StraussArt, breite: CGFloat, titel: String? = nil) -> Zelle {
        let ansicht = StraussBild(art: art, breite: breite)
            .padding(8)
            .background(Color(red: 0.93, green: 0.90, blue: 0.87), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        return (titel ?? art.name, AnyView(ansicht))
    }

    /// Alle fünf in den Größen, in denen sie in der App vorkommen. Je Größe eine Tafel und ein Test:
    /// eine Tafel mit 15 Zellen riss in der CI den Test-Host weg (Lauf 37726648817), so sieht man,
    /// welche Größe es war. Die Tafel `p59-blumen` setzt der Bericht aus den dreien zusammen.
    private func tafelBreite(_ breite: CGFloat, _ name: String) {
        let zellen = StraussArt.allCases.map { zelle($0, breite: breite, titel: "\($0.name) \(Int(breite)) pt") }
        RenderTafel.speichern(name, spalten: 5, zellen: zellen)
    }

    func testTafelGross() { tafelBreite(150, "p59-blumen-gross") }
    func testTafelMittel() { tafelBreite(80, "p59-blumen-mittel") }
    func testTafelKlein() { tafelBreite(44, "p59-blumen-klein") }

    /// Die echte Zuhause-Bühne (p58) mit den Sträußen: drei auf dem Schrank, einer in der Vase.
    private func zimmer(_ zeit: Tageszeit, _ z: ZimmerStraeusse, breite: CGFloat = 390) -> AnyView {
        let stand = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: 2), mitGeste: false)
        let szene = ZuhauseBuehne(straeusse: z.fuerBuehne, fest: stand) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
        } paar: {
            EmptyView()
        }
        return AnyView(szene.frame(width: breite, height: 430).clipped())
    }

    func testTafelZimmerMitStraeussen() {
        let drei = ZimmerStraeusse(schrank: [.lila, .rotBunt, .rosaGerbera], vase: .pinkCreme)
        let andere = ZimmerStraeusse(schrank: [.glitzerRot, .pinkCreme, .lila], vase: .rosaGerbera)
        let zellen: [Zelle] = [
            (titel: "Schrank: Lila, Rot, Rosa. Vase: Pink", ansicht: zimmer(.tag, drei)),
            (titel: "Schrank: Glitzer, Pink, Lila. Vase: Rosa", ansicht: zimmer(.tag, andere)),
            (titel: "Nur ein Strauß, Vase leer", ansicht: zimmer(.morgen, ZimmerStraeusse(schrank: [.rotBunt], vase: nil))),
            (titel: "Nacht, alle Plätze voll", ansicht: zimmer(.nacht, drei)),
        ]
        RenderTafel.speichern("p59-zimmer", spalten: 2, zellen: zellen)
    }

    /// Je Strauß eine große Tafel, zum Vergleichen mit dem Foto.
    func testTafelJederStraussGross() {
        for (n, art) in StraussArt.allCases.enumerated() {
            RenderTafel.speichern("p59-strauss-\(n + 1)-\(art.rawValue)", spalten: 1, zellen: [zelle(art, breite: 360)])
        }
    }
}
