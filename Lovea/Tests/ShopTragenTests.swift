import SwiftUI
import XCTest
@testable import Lovea

/// Z-23.2: wear/unwear toggle and the gender filter (Shop/ShopTragen.swift), plus the "missing
/// points" number the detail sheet shows.
final class ShopTragenTests: XCTestCase {
    private func artikel(_ id: String, kategorie: String, geschlecht: String = "n", preis: Int = 500, exklusiv: Bool = false) -> ShopArtikel {
        ShopArtikel(id: id, name: id, marke: nil, kategorie: kategorie, preis: preis, geschlecht: geschlecht, exklusiv: exklusiv)
    }

    func testDirektfeldKategorienTragenUndAusziehen() {
        var a = FigurAussehen.standard(for: .ahmed)
        let tasche = artikel("tasche.gucci-tasche", kategorie: "tasche")
        XCTAssertFalse(a.traegt(tasche))
        a.anziehen(tasche)
        XCTAssertEqual(a.tasche, "tasche.gucci-tasche")
        XCTAssertTrue(a.traegt(tasche))
        a.ausziehen(tasche, person: .ahmed)
        XCTAssertNil(a.tasche)
        XCTAssertFalse(a.traegt(tasche))
    }

    /// Mehrere Mode-Artikel teilen sich denselben (Feld, Index) mit unterschiedlichem Hex
    /// (z. B. `.oberteil` 14) — nach dem Wechsel darf nur der zuletzt angezogene als getragen gelten.
    func testModeArtikelMitGleichemIndexUnterschiedlichesTragenErgebnis() {
        var a = FigurAussehen.standard(for: .ahmed)
        let hoodie = artikel("mode.guess-hoodie", kategorie: "mode")
        let logoShirt = artikel("mode.tshirt-logo", kategorie: "mode")
        a.anziehen(hoodie)
        XCTAssertTrue(a.traegt(hoodie))
        a.anziehen(logoShirt)
        XCTAssertTrue(a.traegt(logoShirt))
        XCTAssertFalse(a.traegt(hoodie), "Hoodie ist nicht mehr an, auch wenn der Index (14) gleich bleibt")
    }

    func testAusziehenVonModeSetztStandardZurueck() {
        var a = FigurAussehen.standard(for: .ahmed)
        let jacke = artikel("mode.moncler-jacke", kategorie: "mode")
        a.anziehen(jacke)
        XCTAssertTrue(a.traegt(jacke))
        a.ausziehen(jacke, person: .ahmed)
        XCTAssertFalse(a.traegt(jacke))
        XCTAssertEqual(a.jacke, FigurAussehen.standard(for: .ahmed).jacke)
    }

    func testAusziehenOhneAnzuhabenTutNichts() {
        var a = FigurAussehen.standard(for: .ahmed)
        let vorher = a
        a.ausziehen(artikel("tasche.gucci-tasche", kategorie: "tasche"), person: .ahmed)
        XCTAssertEqual(a, vorher)
    }

    func testGeschlechtsFilter() {
        let neutral = artikel("mode.tshirt-logo", kategorie: "mode", geschlecht: "n")
        let weiblich = artikel("mode.seidenbluse", kategorie: "mode", geschlecht: "w")
        let maennlich = artikel("mode.trikot", kategorie: "mode", geschlecht: "m")
        XCTAssertTrue(neutral.sichtbar(fuer: .ahmed))
        XCTAssertTrue(neutral.sichtbar(fuer: .annika))
        XCTAssertFalse(weiblich.sichtbar(fuer: .ahmed))
        XCTAssertTrue(weiblich.sichtbar(fuer: .annika))
        XCTAssertTrue(maennlich.sichtbar(fuer: .ahmed))
        XCTAssertFalse(maennlich.sichtbar(fuer: .annika))
    }

    func testFehlendePunkteFuerNichtGenugPunkteText() {
        let preis = 1200
        XCTAssertEqual(max(0, preis - 950), 250, "\"dir fehlen N\" rechnet Preis minus verfügbar")
        XCTAssertEqual(max(0, preis - 5000), 0, "genug Punkte -> nichts fehlt")
    }
}

/// p5: Guess-Handtasche fehlte im Profil. Der Editor hielt eine alte Kopie und überschrieb beim
/// Sichern die im Shop (Sheet im Editor) angezogene Tasche.
@MainActor
final class TascheProfilTests: XCTestCase {
    private let guess = "tasche.guess-tasche"

    func testEditorSichernBehaeltImShopAngezogeneTasche() {
        let editorKopie = FigurAussehen.standard(for: .annika)
        var modell = editorKopie
        modell.tasche = guess
        modell.uhr = "uhr.x"
        let gesichert = editorKopie.mitShopTeilen(von: modell)
        XCTAssertEqual(gesichert.tasche, guess)
        XCTAssertEqual(gesichert.uhr, "uhr.x")
    }

    func testEditorSichernAendertFreieFelderNichtAusDemModell() {
        var editorKopie = FigurAussehen.standard(for: .annika)
        editorKopie.frisur = 7
        var modell = FigurAussehen.standard(for: .annika)
        modell.tasche = guess
        XCTAssertEqual(editorKopie.mitShopTeilen(von: modell).frisur, 7)
    }

    private func bild(_ a: FigurAussehen, _ z: FigurZustand) -> Data? {
        let r = ImageRenderer(content: FigurView(a, zustand: z, groesse: 400, animiert: false, ganzkoerper: true))
        r.scale = 1
        return r.uiImage?.pngData()
    }

    /// p5 (Runde 5): die Guess-Tasche war am Standard-Annika-Look (schwarze Lederjacke, schwarze
    /// Schuhe, alles `0x2B2830`) unsichtbar — gleiche Farbe wie die Tasche, kein Muster, keine
    /// Kontur, die sich abhebt. `testGetrageneTascheWirdImProfilGezeichnet` unten erkennt das nicht,
    /// weil ein paar Antialiasing-Pixel schon reichen, um die PNGs ungleich zu machen.
    func testGuessTascheHebtSichVonSchwarzerKleidungAb() {
        let annika = FigurAussehen.standard(for: .annika)
        let jackenfarbe = FigurAussehen.farben[annika.jackenfarbe].farbe
        let eintrag = taschenKatalog["tasche.guess-tasche"]!
        let gleicheFarbe = eintrag.farbe == jackenfarbe
        XCTAssertTrue(gleicheFarbe, "Testannahme: Tasche und Annikas Jacke sind dieselbe Farbe")
        // Bei identischer Farbe MUSS ein eigenes Muster/Logo die Tasche sichtbar machen.
        XCTAssertNotEqual(eintrag.muster, .keins, "Guess-Tasche braucht ein Muster/Logo, sonst verschwindet sie vor Annikas schwarzer Jacke")
    }

    /// Profil-Figur (ganzkoerper) zeichnet die angezogene Tasche, für den eigenen und den Partner-Zustand.
    func testGetrageneTascheWirdImProfilGezeichnet() {
        for p in Person.allCases {
            for z in [FigurZustand.ruhig, .zuhause, .arbeit] {
                var ohne = FigurAussehen.standard(for: p)
                ohne.tasche = nil
                var mit = ohne
                mit.tasche = guess
                let a = bild(ohne, z), b = bild(mit, z)
                XCTAssertNotNil(a)
                XCTAssertNotNil(b)
                XCTAssertNotEqual(a, b, "\(p) \(z): Tasche fehlt im Bild")
            }
        }
    }
}
