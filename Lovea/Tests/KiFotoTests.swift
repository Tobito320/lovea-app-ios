import XCTest
@testable import Lovea

/// Reine Logik hinter "Essen fotografieren". Fasst nie `ErnaehrungModell.shared` an.
@MainActor
final class KiFotoTests: XCTestCase {
    private func reis(_ gramm: Double = 200) -> EssenKomponente {
        EssenKomponente(name: "Reis", gramm: gramm, kcalPro100: 130, proteinPro100: 2.7, kohlenhydratePro100: 28, fettPro100: 0.3, sicherheit: "mittel")
    }

    private func huhn(_ gramm: Double = 150) -> EssenKomponente {
        EssenKomponente(name: "Hähnchen", gramm: gramm, kcalPro100: 165, proteinPro100: 31, kohlenhydratePro100: 0, fettPro100: 3.6, sicherheit: "hoch")
    }

    private func liste(_ k: [EssenKomponente], versteckt: [EssenVersteckt] = [], zaehlen: Bool = true) -> [EssenEintrag] {
        KiFotoLogik.eintraege(komponenten: k, versteckt: versteckt, versteckteZaehlen: zaehlen, mahlzeit: .mittag, datum: "2026-10-10")
    }

    private let oel = EssenVersteckt(name: "Bratöl", gramm: 10, kcal: 88)

    func testKnopfZahlIstGenauDieSummeImTagebuch() {
        let e = liste([reis(), huhn()], versteckt: [oel])
        XCTAssertEqual(e.count, 3)
        XCTAssertEqual(KiFotoLogik.kcal(e), 596)
        XCTAssertEqual(KiFotoLogik.kcal(e), Int(ErnaehrungLogik.summe(e).kcal.rounded()))
        XCTAssertEqual(KiFotoLogik.kcal(liste([reis(), huhn()], versteckt: [oel], zaehlen: false)), 508)
    }

    func testEintragSchreibtGrammMahlzeitUndTag() throws {
        let e = try XCTUnwrap(liste([reis()]).first)
        XCTAssertEqual(e.menge, 200)
        XCTAssertEqual(e.einheit, .g)
        XCTAssertEqual(e.mahlzeit, .mittag)
        XCTAssertEqual(e.datum, "2026-10-10")
        XCTAssertTrue(e.lebensmittel.id.hasPrefix("ki-"))
        XCTAssertTrue(e.lebensmittel.istEinmalig)
        XCTAssertNil(e.geloescht)
        XCTAssertEqual(Set(liste([reis(), reis()]).map(\.id)).count, 2, "jeder Eintrag eine eigene Id")
    }

    func testNullGrammZaehltNichtUndZuVielWirdGekappt() throws {
        XCTAssertTrue(liste([reis(0)]).isEmpty)
        let riesig = try XCTUnwrap(liste([reis(9000)]).first)
        XCTAssertEqual(riesig.menge, KiFotoLogik.maxGramm)
    }

    func testVersteckteAlsFettUndOhneGrammMit100() throws {
        let e = try XCTUnwrap(liste([], versteckt: [oel]).first)
        XCTAssertEqual(e.lebensmittel.name, "Bratöl (nicht sichtbar)")
        XCTAssertEqual(e.naehrwerte.kcal, 88, accuracy: 0.01)
        XCTAssertEqual(e.naehrwerte.fett, 88.0 / 9, accuracy: 0.01)
        let ohneGramm = try XCTUnwrap(liste([], versteckt: [EssenVersteckt(name: "Soße", gramm: 0, kcal: 88)]).first)
        XCTAssertEqual(ohneGramm.menge, 100)
        XCTAssertEqual(ohneGramm.naehrwerte.kcal, 88, accuracy: 0.01)
        XCTAssertTrue(liste([], versteckt: [EssenVersteckt(name: "Nichts", gramm: 5, kcal: 0)]).isEmpty)
    }

    func testFotoEintraegeSindEinmaligAberOffAndEigeneNicht() {
        func l(_ id: String) -> Lebensmittel { Lebensmittel(id: id, name: "x", pro100: Naehrwerte()) }
        XCTAssertTrue(l("ki-1").istEinmalig)
        XCTAssertTrue(l("schnell-1").istEinmalig)
        XCTAssertFalse(l("off-123").istEinmalig)
        XCTAssertFalse(l("eigen-1").istEinmalig)
        XCTAssertFalse(l("rezept-1").istEinmalig)
    }

    func testJederFehlerHatTitelTextUndWeg() {
        let alle: [KiFehler] = [.nichtEingerichtet, .tageslimit("essen"), .guthaben, .zuVieleAnfragen, .bildZuGross, .netz, .ungueltig, .unbekannt]
        for f in alle {
            let a = KiFotoLogik.anzeige(f)
            XCTAssertFalse(a.titel.isEmpty, "\(f)")
            XCTAssertFalse(a.text.isEmpty, "\(f)")
            XCTAssertFalse(a.symbol.isEmpty, "\(f)")
        }
    }

    func testFehlerBietetNurSinnvolleWege() {
        let netz = KiFotoLogik.anzeige(.netz)
        XCTAssertTrue(netz.nochmal)
        XCTAssertFalse(netz.neuesFoto)
        let gross = KiFotoLogik.anzeige(.bildZuGross)
        XCTAssertFalse(gross.nochmal, "dasselbe zu große Foto nochmal schicken hilft nicht")
        XCTAssertTrue(gross.neuesFoto)
        let kaputt = KiFotoLogik.anzeige(.ungueltig)
        XCTAssertTrue(kaputt.nochmal && kaputt.neuesFoto)
        for f in [KiFehler.tageslimit("essen"), .guthaben, .nichtEingerichtet] {
            let a = KiFotoLogik.anzeige(f)
            XCTAssertFalse(a.nochmal || a.neuesFoto, "\(f): ein neuer Versuch ändert nichts")
        }
        XCTAssertTrue(KiFotoLogik.fotoUnlesbar.neuesFoto)
        XCTAssertFalse(KiFotoLogik.fotoUnlesbar.nochmal)
    }

    private func analyse(istEssen: Bool, items: String, bemerkung: String) throws -> EssenAnalyse {
        let json = """
        {"ist_essen":\(istEssen),"items":\(items),"versteckt":[],"gesamt":{"kcal":0,"kcal_min":0,"kcal_max":0},
         "frage":null,"bemerkung":"\(bemerkung)","rest":3}
        """
        return try JSONDecoder().decode(EssenAnalyse.self, from: Data(json.utf8))
    }

    func testKeinEssenAuchBeiLeererListe() throws {
        let hund = try analyse(istEssen: false, items: "[]", bemerkung: "Das ist ein Hund.")
        XCTAssertTrue(KiFotoLogik.keinEssen(hund))
        XCTAssertEqual(KiFotoLogik.keinEssenText(hund), "Das ist ein Hund.")
        let leer = try analyse(istEssen: true, items: "[]", bemerkung: "  ")
        XCTAssertTrue(KiFotoLogik.keinEssen(leer))
        XCTAssertEqual(KiFotoLogik.keinEssenText(leer), "Auf dem Foto ist kein Essen zu erkennen.")
        let item = #"[{"name":"Reis","gramm":200,"kcal_pro_100g":130,"protein_pro_100g":2.7,"kohlenhydrate_pro_100g":28,"fett_pro_100g":0.3,"sicherheit":"mittel"}]"#
        XCTAssertFalse(KiFotoLogik.keinEssen(try analyse(istEssen: true, items: item, bemerkung: "")))
    }

    func testRestTextErstKurzVorSchluss() {
        XCTAssertNil(KiFotoLogik.restText(nil))
        XCTAssertNil(KiFotoLogik.restText(39))
        XCTAssertNil(KiFotoLogik.restText(6))
        XCTAssertEqual(KiFotoLogik.restText(5), "Noch 5 Fotos für heute.")
        XCTAssertEqual(KiFotoLogik.restText(1), "Noch 1 Foto für heute.")
        XCTAssertEqual(KiFotoLogik.restText(0), "Das war dein letztes Foto für heute.")
    }

    func testBereichNurWennSinnvollUndMitVersteckten() {
        // Server: kcal_min nur Zutaten, kcal_max schon mit den versteckten 88 kcal.
        let g = EssenAnalyse.Gesamt(kcal: 508, kcalMin: 406, kcalMax: 698)
        XCTAssertEqual(KiFotoLogik.bereich(g, versteckteKcal: 88, gezaehlt: true), 494...698)
        XCTAssertEqual(KiFotoLogik.bereich(g, versteckteKcal: 88, gezaehlt: false), 406...610)
        XCTAssertNil(KiFotoLogik.bereich(.init(kcal: 500, kcalMin: 0, kcalMax: 0), versteckteKcal: 0, gezaehlt: true))
        XCTAssertNil(KiFotoLogik.bereich(.init(kcal: 500, kcalMin: 500, kcalMax: 500), versteckteKcal: 0, gezaehlt: true))
    }

    func testKorrekturenNurBeiGeaenderterMengeUndNichtBeiEntfernten() {
        let r = reis(250), h = huhn(), x = huhn(100)
        let vorher: [UUID: Double] = [r.id: 200, h.id: 150, x.id: 150]
        let k = KiFotoLogik.korrekturen([r, h, x], urspruenglich: vorher, entfernt: [x.id])
        XCTAssertEqual(k.map(\.name), ["Reis"])
        XCTAssertEqual(k.map(\.gramm), [250])
        XCTAssertTrue(KiFotoLogik.korrekturen([reis(200.4)], urspruenglich: [:], entfernt: []).isEmpty)
    }

    func testHinweisBleibtImServerLimitUndBehaeltDieAntwort() {
        XCTAssertEqual(KiFotoLogik.hinweis(frage: "Welches Öl?", antwort: " Olivenöl "), "Frage: Welches Öl? Antwort: Olivenöl")
        let lang = KiFotoLogik.hinweis(frage: "F", antwort: String(repeating: "x", count: 400))
        XCTAssertEqual(lang.count, 300)
        XCTAssertTrue(lang.hasSuffix("xxx"))
    }

    func testTitelUndSicherheit() {
        XCTAssertEqual(KiFotoLogik.titel([]), "Foto-Mahlzeit")
        XCTAssertEqual(KiFotoLogik.titel([reis()]), "Reis")
        XCTAssertEqual(KiFotoLogik.titel([reis(), huhn()]), "Reis, Hähnchen")
        XCTAssertEqual(KiFotoLogik.titel([reis(), huhn(), reis()]), "Reis, Hähnchen …")
        XCTAssertEqual(KiFotoLogik.sicherheit("hoch").text, "sicher")
        XCTAssertEqual(KiFotoLogik.sicherheit("niedrig").text, "unsicher")
        XCTAssertEqual(KiFotoLogik.sicherheit("mittel").text, "ungefähr")
    }
}
