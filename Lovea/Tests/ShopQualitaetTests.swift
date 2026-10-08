import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// p48: Shop-Qualität. Taschen, Haustiere und Mode sind größer und genauer gezeichnet. Die Tests zählen
/// sichtbare Pixel (Tasche in der 44-pt-Leiste braucht eine klare Mindestfläche) und schreiben drei
/// Tafeln `p48-taschen`, `p48-mode`, `p48-tiere`: je Teil auf Annika in Profil, Halbfigur, Leiste 44 pt,
/// Shop-Kachel und Shop-Detail. p56: Mode und Schmuck als `p56-mode` und `p56-schmuck`; Kachel und Detail
/// sind die echten Shop-Ansichten (`ArtikelKachel`, `ArtikelBild` mit Jeans von hinten bzw. Schmuck groß).
@MainActor
final class ShopQualitaetTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    private let taschen = ["tasche.guess-tasche", "tasche.chanel-classic", "tasche.lv-speedy",
                           "tasche.gucci-tasche", "tasche.dior-clutch", "tasche.canvas-tote"]
    private let mode = ["mode.nike-hoodie", "mode.guess-hoodie", "mode.dior-bluse", "mode.blumen-jeans",
                        "mode.satin-camisole", "mode.off-shoulder", "mode.wickelkleid", "mode.cardigan"]
    private let tiere = ["tier.hund-braun", "tier.hund-schwarz", "tier.katze-grau",
                         "tier.katze-orange", "tier.katze-schwarz", "tier.hase-weiss", "tier.vogel-blau"]
    private let schmuck = ["juwel.creolen", "juwel.perlenohrringe", "juwel.herzkette", "juwel.perlenkette",
                           "juwel.cartier-love", "juwel.charm-armband", "juwel.steinring", "juwel.stapelringe"]

    private func annika() -> FigurAussehen { FigurAussehen.standard(for: .annika) }

    private func mitSchmuck(_ id: String) -> FigurAussehen {
        var a = annika()
        a.juwelAnziehen(id)
        return a
    }

    private func mitTasche(_ id: String?) -> FigurAussehen {
        var a = annika()
        a.tasche = id
        return a
    }

    private func mitTier(_ id: String?) -> FigurAussehen {
        var a = annika()
        a.tier = id
        return a
    }

    private func mitMode(_ id: String) -> FigurAussehen {
        var a = annika()
        a.anziehen(id)
        return a
    }

    private func figur(_ a: FigurAussehen, groesse: CGFloat, ganz: Bool) -> AnyView {
        AnyView(FigurView(a, zustand: .ruhig, groesse: groesse, animiert: false, ganzkoerper: ganz))
    }

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

    /// Pixel, die sich zwischen zwei gleich großen Bildern sichtbar unterscheiden.
    private func unterschied(_ a: Bild, _ b: Bild) -> Int {
        var n = 0
        for i in stride(from: 0, to: a.rgba.count, by: 4) {
            let d = max(abs(Int(a.rgba[i]) - Int(b.rgba[i])), abs(Int(a.rgba[i + 1]) - Int(b.rgba[i + 1])), abs(Int(a.rgba[i + 2]) - Int(b.rgba[i + 2])))
            if d > 16 { n += 1 }
        }
        return n
    }

    private func pruefe(_ name: String, mindestens: Int, ohne: AnyView, mit: AnyView) {
        guard let a = bild(ohne), let b = bild(mit), a.breite == b.breite, a.hoehe == b.hoehe else {
            XCTFail("\(name): nicht renderbar oder Größe verschieden")
            return
        }
        let n = unterschied(a, b)
        XCTAssertGreaterThanOrEqual(n, mindestens, "\(name): nur \(n) Pixel sichtbar (mindestens \(mindestens))")
    }

    // MARK: - Mindestfläche

    /// Leiste 44 pt (Halbfigur, Scale 2): jede Tasche muss klar sichtbar sein, nicht nur ein paar Pixel.
    func testTascheInDer44ptLeisteHatMindestflaeche() {
        for id in taschen {
            pruefe("Leiste 44 pt \(id)", mindestens: 250,
                   ohne: figur(mitTasche(nil), groesse: 44, ganz: false),
                   mit: figur(mitTasche(id), groesse: 44, ganz: false))
        }
    }

    func testTascheInProfilUndHalbfigurHatMindestflaeche() {
        for id in taschen {
            pruefe("Halbfigur 140 \(id)", mindestens: 2500,
                   ohne: figur(mitTasche(nil), groesse: 140, ganz: false),
                   mit: figur(mitTasche(id), groesse: 140, ganz: false))
            pruefe("Profil 220 \(id)", mindestens: 2500,
                   ohne: figur(mitTasche(nil), groesse: 220, ganz: true),
                   mit: figur(mitTasche(id), groesse: 220, ganz: true))
        }
    }

    func testHaustierStehtNebenDerFigur() {
        for id in tiere {
            pruefe("Halbfigur 140 \(id)", mindestens: 1500,
                   ohne: figur(mitTier(nil), groesse: 140, ganz: false),
                   mit: figur(mitTier(id), groesse: 140, ganz: false))
            pruefe("Profil 220 \(id)", mindestens: 1500,
                   ohne: figur(mitTier(nil), groesse: 220, ganz: true),
                   mit: figur(mitTier(id), groesse: 220, ganz: true))
        }
    }

    /// Die geänderten Farben der Modeteile bleiben beim "Wird getragen"-Vergleich (Index UND Hex) stimmig.
    func testModeTeileWerdenAlsGetragenErkannt() {
        for id in mode {
            let a = mitMode(id)
            let artikel = ShopArtikel(id: id, name: id, marke: nil, kategorie: "mode", preis: 1, geschlecht: "n", exklusiv: false)
            XCTAssertTrue(a.traegt(artikel), "\(id) wird nach dem Anziehen nicht als getragen erkannt")
        }
    }

    /// p56: jedes Schmuckstück verändert das Bild der Figur (Ohr und Hals schon in der Halbfigur, alles am ganzen Körper).
    func testSchmuckIstAnDerFigurSichtbar() {
        for id in schmuck {
            let ort = schmuckKatalog[id]?.stil.ort
            pruefe("Profil 220 \(id)", mindestens: 6,
                   ohne: figur(annika(), groesse: 220, ganz: true), mit: figur(mitSchmuck(id), groesse: 220, ganz: true))
            if ort == .ohr || ort == .hals {
                pruefe("Halbfigur 140 \(id)", mindestens: 6,
                       ohne: figur(annika(), groesse: 140, ganz: false), mit: figur(mitSchmuck(id), groesse: 140, ganz: false))
            }
        }
    }

    // MARK: - Tafeln

    private func zeilen(_ ids: [String], look: (String) -> FigurAussehen, vorschau: (String) -> FigurAussehen) -> [Zelle] {
        var zellen: [Zelle] = []
        for id in ids {
            let name = id.split(separator: ".").last.map(String.init) ?? id
            let a = look(id)
            zellen.append((titel: "\(name): Profil", ansicht: figur(a, groesse: 220, ganz: true)))
            zellen.append((titel: "\(name): Halbfigur", ansicht: figur(a, groesse: 140, ganz: false)))
            zellen.append((titel: "\(name): Leiste 44 pt", ansicht: figur(a, groesse: 44, ganz: false)))
            let artikel = ShopArtikel(id: id, name: name, marke: nil, kategorie: "", preis: 1, geschlecht: "n", exklusiv: false)
            zellen.append((titel: "\(name): Shop-Kachel", ansicht: AnyView(ArtikelKachel(artikel: artikel, besitzt: false, vorschauAussehen: vorschau(id)))))
            zellen.append((titel: "\(name): Shop-Detail", ansicht: AnyView(ArtikelBild(id: id, aussehen: vorschau(id)))))
        }
        return zellen
    }

    func testTafelTaschen() {
        RenderTafel.speichern("p48-taschen", spalten: 5, zellen: zeilen(taschen, look: { self.mitTasche($0) }, vorschau: { self.mitTasche($0) }))
    }

    func testTafelMode() {
        RenderTafel.speichern("p56-mode", spalten: 5, zellen: zeilen(mode, look: { self.mitMode($0) }, vorschau: { self.mitMode($0) }))
    }

    func testTafelSchmuck() {
        RenderTafel.speichern("p56-schmuck", spalten: 5, zellen: zeilen(schmuck, look: { self.mitSchmuck($0) }, vorschau: { self.mitSchmuck($0) }))
    }

    func testTafelTiere() {
        RenderTafel.speichern("p48-tiere", spalten: 5, zellen: zeilen(tiere, look: { self.mitTier($0) }, vorschau: { self.mitTier($0) }))
    }
}
