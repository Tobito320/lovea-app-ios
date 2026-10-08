import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// p46: Annikas angezogene Guess-Handtasche fehlte an der Figur, obwohl p5 (PR 62) schon zwei Ursachen
/// behoben hat. Diese Tests zählen sichtbare Pixel der Tasche je Ansicht (nicht nur "PNG ungleich",
/// das schon ein paar Antialiasing-Pixel erfüllen) und schreiben die Tafel `guess-tasche.png`.
@MainActor
final class GuessTascheTests: XCTestCase {
    private let guess = "tasche.guess-tasche"
    private typealias Zelle = (titel: String, ansicht: AnyView)

    /// `ShopKatalog.alle` liest `Bundle.main` und ist im XCTest leer (siehe ShopKatalogTests). Der
    /// Artikel hier ist der Katalogeintrag; `testKatalogEintragPasstZumTest` prüft ihn gegen die JSON.
    private let artikel = ShopArtikel(id: "tasche.guess-tasche", name: "Guess Handtasche", marke: "Guess", kategorie: "tasche", preis: 500, geschlecht: "w", exklusiv: false)

    private func annika(_ mitTasche: Bool) -> FigurAussehen {
        var a = FigurAussehen.standard(for: .annika)
        a.tasche = mitTasche ? guess : nil
        return a
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

    /// Eine Ansicht ohne und mit Tasche rendern, die Tasche muss mindestens `mindestens` Pixel ändern.
    private func pruefe(_ name: String, mindestens: Int = 30, ohne: AnyView, mit: AnyView) {
        guard let a = bild(ohne), let b = bild(mit), a.breite == b.breite, a.hoehe == b.hoehe else {
            XCTFail("\(name): nicht renderbar oder Größe verschieden")
            return
        }
        let n = unterschied(a, b)
        XCTAssertGreaterThanOrEqual(n, mindestens, "\(name): Guess-Tasche nur \(n) Pixel sichtbar (mindestens \(mindestens))")
    }

    private func pruefeFigur(_ name: String, _ zustand: FigurZustand, groesse: CGFloat, ganz: Bool, mindestens: Int = 30) {
        func figur(_ a: FigurAussehen) -> AnyView {
            AnyView(FigurView(a, zustand: zustand, groesse: groesse, animiert: false, ganzkoerper: ganz))
        }
        pruefe("\(name) \(zustand.rawValue)", mindestens: mindestens, ohne: figur(annika(false)), mit: figur(annika(true)))
    }

    // MARK: - Weg: Kaufen, Anziehen, Sync

    func testKatalogEintragPasstZumTest() throws {
        let bundle = Bundle(for: FigurenModell.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "katalog", withExtension: "json")
                ?? bundle.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop")
        )
        let katalog = try JSONDecoder().decode([ShopArtikel].self, from: try Data(contentsOf: url))
        let eintrag = try XCTUnwrap(katalog.first { $0.id == guess }, "Guess-Tasche fehlt im Katalog")
        XCTAssertEqual(eintrag.kategorie, "tasche")
        XCTAssertTrue(eintrag.sichtbar(fuer: .annika))
        XCTAssertNotNil(taschenKatalog[eintrag.id], "Katalog-ID ohne Zeichen-Eintrag in taschenKatalog")
    }

    func testAnziehenUndSyncWegBehaltenDieTasche() throws {
        XCTAssertTrue(artikel.sichtbar(fuer: .annika))
        var a = annika(false)
        a.anziehen(artikel)
        XCTAssertTrue(a.traegt(artikel))
        let op = Op.neu("figur.aussehen", a, von: .annika)
        XCTAssertEqual(op.daten(FigurAussehen.self)?.tasche, guess, "Tasche überlebt Codieren und Decodieren der Op")
        // FigurenModell wirft alles Neue weg, wenn `augenform` in der Op fehlt (v1-Erkennung).
        struct Kennung: Decodable { let augenform: Int? }
        XCTAssertNotNil(op.daten(Kennung.self)?.augenform, "Op gilt sonst als v1 und verliert die Tasche")
    }

    // MARK: - Zeichnen je Ansicht

    /// Profil-Figur (ganzer Körper, 340 pt) in den Zuständen, in denen Annika wach ist.
    func testProfilFigurZeigtTascheInJedemWachenZustand() {
        for z in [FigurZustand.ruhig, .zuhause, .arbeit, .schule, .imChat, .tippt, .liest, .laeuft, .supermarkt] {
            pruefeFigur("Profil", z, groesse: 340, ganz: true)
        }
    }

    /// Halbfigur (Home-Karte, Chat-Kopf, Reaktionen) mit 140 pt.
    func testHalbfigurZeigtTasche() {
        for z in [FigurZustand.ruhig, .zuhause, .arbeit, .schule, .imChat, .tippt, .liest] {
            pruefeFigur("Halbfigur", z, groesse: 140, ganz: false)
        }
    }

    /// Chat-Partnerleiste: Halbfigur nur 44 pt hoch (PartnerFigurLeiste).
    func testChatPartnerLeisteZeigtTasche() {
        for z in [FigurZustand.ruhig, .zuhause, .arbeit, .imChat, .tippt] {
            pruefeFigur("Chat-Leiste", z, groesse: 44, ganz: false)
        }
    }

    /// Karten-Figur (KartenFigur 130 pt, Profilkarte 86 pt): ganzer Körper.
    func testKartenFigurZeigtTasche() {
        for z in [FigurZustand.ruhig, .laeuft, .zuhause, .arbeit] {
            pruefeFigur("Karte 130", z, groesse: 130, ganz: true)
            pruefeFigur("Profilkarte 86", z, groesse: 86, ganz: true, mindestens: 20)
        }
    }

    /// Shop: Kachel (118 pt) und Detailblatt (260 pt) zeigen die Tasche als Vorschau auf Annikas Figur.
    func testShopVorschauZeigtTasche() {
        for g: CGFloat in [118, 260] {
            func figur(_ a: FigurAussehen) -> AnyView {
                AnyView(FigurView(a, zustand: .ruhig, groesse: g, animiert: false, ganzkoerper: true))
            }
            pruefe("Shop \(Int(g))", ohne: figur(annika(false)), mit: figur(annika(false).mitVorschau(artikel)))
        }
    }

    /// "Figur anpassen": die Vorschau im Editor hält eine ältere Kopie. Zieht Annika im Shop (Sheet im
    /// Editor) die Tasche an, muss die Editor-Vorschau sie sofort zeigen, nicht erst nach dem Sichern.
    /// Reiner Look-Vergleich: ein Pixelvergleich des ganzen Editors ist unbrauchbar, weil die Vorschau
    /// animiert (Atmen, Blinzeln) und zwei Renderings sich auch ohne Tasche unterscheiden.
    func testEditorVorschauZeigtImShopAngezogeneTasche() {
        let look = FigurEditor.vorschauLook(annika(false), modell: annika(true))
        XCTAssertEqual(look.tasche, guess)
    }

    func testEditorVorschauBehaeltFreieFelderDesEditors() {
        var start = annika(false)
        start.frisur = 7
        XCTAssertEqual(FigurEditor.vorschauLook(start, modell: annika(true)).frisur, 7)
        XCTAssertEqual(FigurEditor.vorschauLook(start, modell: nil), start)
    }

    // MARK: - Tafel

    /// `render-galerie/guess-tasche.png`: Annika mit Guess-Tasche in den Ansichten, auch dort, wo
    /// die Tasche zu klein oder verdeckt sein könnte.
    func testTafelGuessTasche() {
        var zellen: [Zelle] = []
        func ansicht(_ titel: String, _ zustand: FigurZustand, groesse: CGFloat, ganz: Bool) {
            zellen.append((titel: titel, ansicht: AnyView(FigurView(annika(true), zustand: zustand, groesse: groesse, animiert: false, ganzkoerper: ganz))))
        }
        for z in [FigurZustand.ruhig, .zuhause, .arbeit, .schule, .imChat, .tippt, .laeuft, .supermarkt] {
            ansicht("Profil \(z.rawValue)", z, groesse: 220, ganz: true)
        }
        for z in [FigurZustand.ruhig, .zuhause, .arbeit, .schule, .imChat, .tippt, .liest, .gut] {
            ansicht("Halb \(z.rawValue)", z, groesse: 140, ganz: false)
        }
        ansicht("Leiste 44 pt", .ruhig, groesse: 44, ganz: false)
        ansicht("Leiste 44 pt x3", .ruhig, groesse: 132, ganz: false)
        ansicht("Leiste imChat x3", .imChat, groesse: 132, ganz: false)
        ansicht("Karte 130", .ruhig, groesse: 130, ganz: true)
        ansicht("Karte laeuft", .laeuft, groesse: 130, ganz: true)
        ansicht("Profilkarte 86", .ruhig, groesse: 86, ganz: true)
        zellen.append((titel: "Shop-Kachel", ansicht: AnyView(FigurView(annika(false).mitVorschau(artikel), zustand: .ruhig, groesse: 118, animiert: false, ganzkoerper: true))))
        zellen.append((titel: "Shop-Detail", ansicht: AnyView(FigurView(annika(false).mitVorschau(artikel), zustand: .ruhig, groesse: 260, animiert: false, ganzkoerper: true))))
        zellen.append((titel: "Editor-Vorschau", ansicht: AnyView(
            FigurEditor(start: annika(false), modell: annika(true)) { _ in }.frame(width: 390, height: 420).clipped()
        )))
        RenderTafel.speichern("guess-tasche", spalten: 8, zellen: zellen)
    }
}
