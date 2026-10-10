import UIKit
import XCTest
@testable import Lovea

@MainActor
final class EssenModelleTests: XCTestCase {
    private func reis(gramm: Double = 200) -> EssenKomponente {
        EssenKomponente(name: "Reis", gramm: gramm, kcalPro100: 130, proteinPro100: 2.7, kohlenhydratePro100: 28, fettPro100: 0.3, sicherheit: "mittel")
    }

    func testKomponenteRechnetAusGrammUndWertenProHundert() {
        XCTAssertEqual(reis().kcal, 260)
        XCTAssertEqual(reis().protein, 5.4, accuracy: 0.001)
        XCTAssertEqual(reis(gramm: 100).kcal, 130)
    }

    func testMahlzeitSummeMitUndOhneVersteckte() {
        var m = EssenMahlzeit(tag: "2026-10-08", zeit: Date(), art: .mittag, komponenten: [reis()])
        m.versteckt = [EssenVersteckt(name: "Öl", gramm: 10, kcal: 88)]
        m.versteckteZaehlen = true
        XCTAssertEqual(m.kcal, 348)
        m.versteckteZaehlen = false
        XCTAssertEqual(m.kcal, 260)
    }

    func testTitelNenntDieErstenZweiZutaten() {
        var m = EssenMahlzeit(tag: "2026-10-08", zeit: Date(), art: .abend, komponenten: [])
        XCTAssertEqual(m.titel, "Abendessen")
        m.komponenten = [reis(), reis(), reis()]
        XCTAssertEqual(m.titel, "Reis, Reis …")
    }

    func testAnalyseDekodiertServerAntwort() throws {
        let json = """
        {"ok":true,"ist_essen":true,
         "items":[{"name":"Reis","gramm":200,"kcal_pro_100g":130,"protein_pro_100g":2.7,"kohlenhydrate_pro_100g":28,"fett_pro_100g":0.3,"sicherheit":"mittel","kcal":260,"protein":5.4,"kohlenhydrate":56,"fett":0.6},
                  {"name":"Hähnchen","gramm":150,"kcal_pro_100g":165,"protein_pro_100g":31,"kohlenhydrate_pro_100g":0,"fett_pro_100g":3.6,"sicherheit":"hoch","kcal":248,"protein":46.5,"kohlenhydrate":0,"fett":5.4}],
         "versteckt":[{"name":"Bratöl","gramm":10,"kcal":88}],
         "gesamt":{"kcal":508,"kcal_min":450,"kcal_max":610,"protein":51.9,"kohlenhydrate":56,"fett":6,"versteckt_kcal":88,"kcal_mit_versteckt":596},
         "frage":null,"bemerkung":"Reis mit Hähnchen","rest":39,"modell":"gpt-6-luna"}
        """
        let a = try JSONDecoder().decode(EssenAnalyse.self, from: Data(json.utf8))
        XCTAssertTrue(a.istEssen)
        XCTAssertEqual(a.komponenten.count, 2)
        XCTAssertEqual(a.komponenten[0].kcalPro100, 130)
        XCTAssertEqual(a.versteckteListe.first?.kcal, 88)
        XCTAssertEqual(a.gesamt.kcalMax, 610)
        XCTAssertNil(a.frage)
        XCTAssertEqual(a.rest, 39)
        XCTAssertEqual(a.bemerkung, "Reis mit Hähnchen")
    }

    func testBerichtDekodiert() throws {
        let json = #"{"ok":true,"titel":"Guter Tag","kurzfassung":"Kurz.","was_gut":["a"],"was_besser":["b"],"morgen":["c"],"rest":5}"#
        let b = try JSONDecoder().decode(KiBericht.self, from: Data(json.utf8))
        XCTAssertEqual(b.wasGut, ["a"])
        XCTAssertEqual(b.morgen, ["c"])
    }

    func testStoreSpeichertLaedtUndLoescht() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("essen-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let prefix = "lovea.essen.test.\(UUID().uuidString)."
        let store = EssenStore(datei: url, zielPrefix: prefix)
        let m = EssenMahlzeit(tag: "2026-10-08", zeit: Date(), art: .mittag, komponenten: [reis()])
        store.speichern(m, fuer: .ahmed)
        XCTAssertEqual(store.summe(.ahmed, tag: "2026-10-08").kcal, 260)
        XCTAssertTrue(store.liste(.annika, tag: "2026-10-08").isEmpty, "Annika sieht Ahmeds Essen nicht")
        XCTAssertEqual(EssenStore(datei: url, zielPrefix: prefix).liste(.ahmed, tag: "2026-10-08").count, 1)
        store.loeschen(m.id, fuer: .ahmed)
        XCTAssertEqual(EssenStore(datei: url, zielPrefix: prefix).liste(.ahmed, tag: "2026-10-08").count, 0)
    }

    func testZieleHabenUntergrenzeUndWerdenProPersonGemerkt() {
        let prefix = "lovea.essen.test.\(UUID().uuidString)."
        defer {
            UserDefaults.standard.removeObject(forKey: prefix + "ahmed")
            UserDefaults.standard.removeObject(forKey: prefix + "annika")
        }
        let store = EssenStore(datei: FileManager.default.temporaryDirectory.appendingPathComponent("z-\(UUID().uuidString).json"), zielPrefix: prefix)
        store.setzeZiele(EssenZiele(ziel: "cut", kcal: 800, protein: 150), fuer: .ahmed)
        XCTAssertEqual(store.ziele(.ahmed).kcal, EssenZiele.mindestKcal)
        XCTAssertEqual(store.ziele(.ahmed).protein, 150)
        XCTAssertEqual(store.ziele(.annika), EssenZiele(), "ohne Eintrag gelten die Standardwerte")
    }

    func testFehlerAbbildung() {
        XCTAssertEqual(KiClient.fehler(status: 429, daten: Data(#"{"fehler":"tageslimit","art":"essen"}"#.utf8)), .tageslimit("essen"))
        XCTAssertEqual(KiClient.fehler(status: 429, daten: Data(#"{"fehler":"zu viele anfragen"}"#.utf8)), .zuVieleAnfragen)
        XCTAssertEqual(KiClient.fehler(status: 503, daten: Data(#"{"fehler":"guthaben"}"#.utf8)), .guthaben)
        XCTAssertEqual(KiClient.fehler(status: 503, daten: Data(#"{"fehler":"nicht eingerichtet"}"#.utf8)), .nichtEingerichtet)
        XCTAssertEqual(KiClient.fehler(status: 413, daten: Data()), .bildZuGross)
        XCTAssertEqual(KiClient.fehler(status: 500, daten: Data()), .unbekannt)
        XCTAssertNotNil(KiFehler.tageslimit("coach").errorDescription)
    }

    func testBildWirdVerkleinertUndIstJpeg() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        let png = renderer.pngData { kontext in
            UIColor.orange.setFill()
            kontext.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        let klein = try XCTUnwrap(EssenBild.verkleinern(png))
        XCTAssertEqual(Array(klein.prefix(2)), [0xFF, 0xD8], "JPEG beginnt mit FFD8")
        let bild = try XCTUnwrap(UIImage(data: klein))
        XCTAssertLessThanOrEqual(max(bild.size.width, bild.size.height), 1024)
        XCTAssertGreaterThan(bild.size.width, bild.size.height)
        XCTAssertNil(EssenBild.verkleinern(Data("kein bild".utf8)))
    }

    func testMahlzeitArtVorschlagNachUhrzeit() throws {
        func um(_ stunde: Int) throws -> Date {
            try XCTUnwrap(Datum.kalender.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: stunde)))
        }
        XCTAssertEqual(MahlzeitArt.vorschlag(um: try um(8)), .fruehstueck)
        XCTAssertEqual(MahlzeitArt.vorschlag(um: try um(12)), .mittag)
        XCTAssertEqual(MahlzeitArt.vorschlag(um: try um(19)), .abend)
        XCTAssertEqual(MahlzeitArt.vorschlag(um: try um(23)), .snack)
    }

    func testCoachEintragRechnetAufGesamtwerte() {
        let e = CoachMarker.Essen(name: "Pizza Spicy", art: .mittag, kcal: 1000, protein: 40, kohlenhydrate: 120, fett: 38)
        let m = EssenMahlzeit.vomCoach(e, tag: "2026-10-09", zeit: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(m.kcal, 1000)
        XCTAssertEqual(m.protein, 40, accuracy: 0.01)
        XCTAssertEqual(m.kohlenhydrate, 120, accuracy: 0.01)
        XCTAssertEqual(m.fett, 38, accuracy: 0.01)
        XCTAssertEqual(m.art, .mittag)
        XCTAssertEqual(m.tag, "2026-10-09")
        XCTAssertEqual(m.titel, "Pizza Spicy")
    }

    func testCoachEintragOhneMakrosUndArtNimmtVorschlag() {
        let zeit = Datum.kalender.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 19))!
        let m = EssenMahlzeit.vomCoach(CoachMarker.Essen(name: "Apfel", art: nil, kcal: 80, protein: nil, kohlenhydrate: nil, fett: nil), tag: "2026-10-09", zeit: zeit)
        XCTAssertEqual(m.kcal, 80)
        XCTAssertEqual(m.protein, 0)
        XCTAssertEqual(m.art, .abend)
    }
}
