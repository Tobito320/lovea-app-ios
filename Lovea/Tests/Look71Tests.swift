import SwiftUI
import XCTest
@testable import Lovea

/// p71 Runde B: gespeicherte Looks, Outfit des Tages mit Herz, nur die Kleidung übernehmen, Garderobe-Filter,
/// der Hinweis "hat dein Outfit geändert", und die Bilder dazu (Vorher/Nachher, Looks).
@MainActor
final class Look71Tests: XCTestCase {
    typealias A = FigurAussehen
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func op<T: Encodable>(_ art: String, _ d: T, von: Person, id: String = UUID().uuidString, _ s: Double = 0) -> Op {
        Op(id: id, seq: nil, art: art, von: von, zeit: t0.addingTimeInterval(s), d: Op.neu(art, d, von: von).d)
    }

    private func look(_ person: Person, oberteil: Int) -> A {
        var a = A.standard(for: person)
        a.oberteil = oberteil
        a.person = nil
        return a
    }

    // MARK: - Looks speichern

    func testPlatzGehoertDemSchreiber() {
        var s = LookStand()
        LookLogik.falten(&s, op("look.platz", PlatzD(platz: 2, look: look(.ahmed, oberteil: 5)), von: .ahmed))
        LookLogik.falten(&s, op("look.platz", PlatzD(platz: 2, look: look(.annika, oberteil: 4)), von: .annika))
        XCTAssertEqual(s.plaetze[.ahmed]?[2]?.oberteil, 5)
        XCTAssertEqual(s.plaetze[.annika]?[2]?.oberteil, 4)
    }

    func testPlatzUeberschreibtUndBleibtInDenFuenfPlaetzen() {
        var s = LookStand()
        LookLogik.falten(&s, op("look.platz", PlatzD(platz: 0, look: look(.ahmed, oberteil: 1)), von: .ahmed))
        LookLogik.falten(&s, op("look.platz", PlatzD(platz: 0, look: look(.ahmed, oberteil: 2)), von: .ahmed))
        XCTAssertEqual(s.plaetze[.ahmed]?[0]?.oberteil, 2, "der spätere gewinnt")
        LookLogik.falten(&s, op("look.platz", PlatzD(platz: 5, look: look(.ahmed, oberteil: 3)), von: .ahmed))
        LookLogik.falten(&s, op("look.platz", PlatzD(platz: -1, look: look(.ahmed, oberteil: 3)), von: .ahmed))
        XCTAssertEqual(s.plaetze[.ahmed]?.count, 1, "nur die fünf Plätze 0 bis 4")
    }

    func testKaputteOpWirdIgnoriert() {
        var s = LookStand()
        let kaputt = Op(id: "x", seq: nil, art: "look.platz", von: .ahmed, zeit: t0, d: Data("{\"platz\":1}".utf8))
        LookLogik.falten(&s, kaputt)
        XCTAssertEqual(s, LookStand())
    }

    // MARK: - Outfit des Tages

    func testTagesOutfitJedePersonEinsProTag() {
        var s = LookStand()
        LookLogik.falten(&s, op("outfit.tag", TagesOutfitD(tag: "2026-10-09", look: look(.ahmed, oberteil: 1)), von: .ahmed))
        LookLogik.falten(&s, op("outfit.tag", TagesOutfitD(tag: "2026-10-09", look: look(.ahmed, oberteil: 2)), von: .ahmed, 5))
        LookLogik.falten(&s, op("outfit.tag", TagesOutfitD(tag: "2026-10-09", look: look(.annika, oberteil: 4)), von: .annika))
        XCTAssertEqual(s.tagesLook(.ahmed, tag: "2026-10-09")?.oberteil, 2)
        XCTAssertEqual(s.tagesLook(.annika, tag: "2026-10-09")?.oberteil, 4)
        XCTAssertNil(s.tagesLook(.annika, tag: "2026-10-10"), "ein anderer Tag zeigt nichts")
    }

    func testAelterenTagUeberschreibtKeinenJuengeren() {
        var s = LookStand()
        LookLogik.falten(&s, op("outfit.tag", TagesOutfitD(tag: "2026-10-09", look: look(.ahmed, oberteil: 1)), von: .ahmed))
        LookLogik.falten(&s, op("outfit.tag", TagesOutfitD(tag: "2026-10-08", look: look(.ahmed, oberteil: 2)), von: .ahmed))
        XCTAssertEqual(s.tagesOutfit[.ahmed]?.tag, "2026-10-09")
    }

    func testHerzNurFuerDenAnderen() {
        var s = LookStand()
        LookLogik.falten(&s, op("outfit.herz", OutfitHerzD(fuer: .annika, tag: "2026-10-09"), von: .ahmed))
        LookLogik.falten(&s, op("outfit.herz", OutfitHerzD(fuer: .ahmed, tag: "2026-10-09"), von: .ahmed))
        XCTAssertTrue(s.herz(von: .ahmed, fuer: .annika, tag: "2026-10-09"))
        XCTAssertFalse(s.herz(von: .ahmed, fuer: .ahmed, tag: "2026-10-09"), "kein Herz für das eigene Outfit")
        XCTAssertFalse(s.herz(von: .annika, fuer: .ahmed, tag: "2026-10-09"))
        XCTAssertFalse(s.herz(von: .ahmed, fuer: .annika, tag: "2026-10-10"))
    }

    func testHinweisNurVomPartnerUndFuerMich() {
        let tag = op("outfit.tag", TagesOutfitD(tag: "2026-10-09", look: look(.annika, oberteil: 4)), von: .annika)
        XCTAssertEqual(LookLogik.hinweis(tag, ich: .ahmed), "Annika hat das Outfit für heute gewählt")
        XCTAssertNil(LookLogik.hinweis(tag, ich: .annika), "das eigene Outfit meldet nichts")
        XCTAssertNil(LookLogik.hinweis(tag, ich: nil))
        let herz = op("outfit.herz", OutfitHerzD(fuer: .ahmed, tag: "2026-10-09"), von: .annika)
        XCTAssertEqual(LookLogik.hinweis(herz, ich: .ahmed), "Annika gibt deinem Outfit ein Herz")
        let fremdesHerz = op("outfit.herz", OutfitHerzD(fuer: .annika, tag: "2026-10-09"), von: .annika)
        XCTAssertNil(LookLogik.hinweis(fremdesHerz, ich: .ahmed))
        XCTAssertNil(LookLogik.hinweis(op("look.platz", PlatzD(platz: 0, look: look(.annika, oberteil: 4)), von: .annika), ich: .ahmed))
    }

    // MARK: - Nur die Kleidung

    func testMitKleidungAendertNurKleidung() {
        var ich = A.standard(for: .ahmed)
        ich.tasche = "tasche.guess-tasche"
        ich.uhr = "uhr.rolex"
        ich.schmuck = "juwel.herzkette"
        ich.tier = "tier.hund"
        ich.bauch = 6
        var quelle = A.standard(for: .annika)
        quelle.oberteil = 4; quelle.oberteilfarbeHex = "F7B6C8"
        quelle.jacke = 2; quelle.hose = 7; quelle.schuhe = 3
        quelle.kopfbedeckung = 1; quelle.brille = 1; quelle.airpods = true; quelle.kette = 2
        quelle.frisur = 9; quelle.gesichtsform = 3; quelle.haut = 4; quelle.koerperform = 2
        let neu = ich.mitKleidung(von: quelle)
        // Kleidung kommt von der Quelle.
        XCTAssertEqual(neu.oberteil, 4)
        XCTAssertEqual(neu.oberteilfarbeHex, "F7B6C8")
        XCTAssertEqual(neu.jacke, 2)
        XCTAssertEqual(neu.hose, 7)
        XCTAssertEqual(neu.schuhe, 3)
        XCTAssertEqual(neu.kopfbedeckung, 1)
        XCTAssertEqual(neu.brille, 1)
        XCTAssertTrue(neu.airpods)
        XCTAssertEqual(neu.kette, 2)
        // Gesicht, Haare, Körper, Bauch und gekaufte Teile bleiben.
        XCTAssertEqual(neu.frisur, ich.frisur)
        XCTAssertEqual(neu.gesichtsform, ich.gesichtsform)
        XCTAssertEqual(neu.haut, ich.haut)
        XCTAssertEqual(neu.koerperform, ich.koerperform)
        XCTAssertEqual(neu.bauch, 6)
        XCTAssertEqual(neu.tasche, "tasche.guess-tasche")
        XCTAssertEqual(neu.uhr, "uhr.rolex")
        XCTAssertEqual(neu.schmuck, "juwel.herzkette")
        XCTAssertEqual(neu.tier, "tier.hund")
    }

    func testMitKleidungVonSichSelbstIstGleich() {
        let a = A.standard(for: .annika)
        XCTAssertEqual(a.mitKleidung(von: a), a, "darum markiert ein gespeicherter Look, der gerade getragen wird, sich selbst")
    }

    // MARK: - Garderobe-Filter

    private func stueck(_ id: String, marke: String?, besitzt: Bool) -> GarderobeStueck {
        GarderobeStueck(artikel: ShopArtikel(id: id, name: id, marke: marke, kategorie: "mode", preis: 10, geschlecht: "n", exklusiv: false), besitzt: besitzt)
    }

    func testFilterAlleMeineShopMarke() {
        let a = stueck("a", marke: "Nike", besitzt: true)
        let b = stueck("b", marke: "Adidas", besitzt: false)
        let c = stueck("c", marke: nil, besitzt: false)
        let alle = [a, b, c]
        XCTAssertEqual(alle.filter { GarderobeFilter.alle.laesst($0) }.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(alle.filter { GarderobeFilter.meine.laesst($0) }.map(\.id), ["a"])
        XCTAssertEqual(alle.filter { GarderobeFilter.shop.laesst($0) }.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(alle.filter { GarderobeFilter.marke("Adidas").laesst($0) }.map(\.id), ["b"])
    }

    func testFilterZeigtFreieTeileNurBeiAlleUndMeine() {
        XCTAssertTrue(GarderobeFilter.alle.zeigtFreies)
        XCTAssertTrue(GarderobeFilter.meine.zeigtFreies)
        XCTAssertFalse(GarderobeFilter.shop.zeigtFreies)
        XCTAssertFalse(GarderobeFilter.marke("Nike").zeigtFreies)
    }

    func testMarkenListeSortiertOhneDoppelteUndLeere() {
        let s = [stueck("a", marke: "Nike", besitzt: true), stueck("b", marke: "Adidas", besitzt: false),
                 stueck("c", marke: "Nike", besitzt: false), stueck("d", marke: nil, besitzt: false), stueck("e", marke: "", besitzt: false)]
        XCTAssertEqual(GarderobeFilter.marken(s), ["Adidas", "Nike"])
    }

    // MARK: - Hinweis "hat dein Outfit geändert"

    private func aenderung(_ von: Person, _ ziel: Person, _ a: A, id: String = UUID().uuidString) -> Op {
        op("figur.aussehenFuer", AussehenFuerD(fuer: ziel, aussehen: a), von: von, id: id)
    }

    func testFremdeAenderungMerktSichDenLookDavor() {
        let vorher = look(.annika, oberteil: 4)
        let neu = look(.annika, oberteil: 5)
        let o = aenderung(.ahmed, .annika, neu)
        let f = FigurenModell.fremdeAenderung(o, ziel: .annika, neu: neu, vorher: vorher, ich: .annika, aktuell: nil)
        XCTAssertEqual(f?.von, .ahmed)
        XCTAssertEqual(f?.vorher, vorher)
        XCTAssertEqual(f?.opId, o.id)
    }

    func testFremdeAenderungNurFuerMichUndNurVonAnderen() {
        let a = look(.annika, oberteil: 5)
        // Ahmeds eigene Figur oder Annikas Figur aus Ahmeds Sicht: kein Hinweis für Ahmed.
        XCTAssertNil(FigurenModell.fremdeAenderung(aenderung(.ahmed, .annika, a), ziel: .annika, neu: a, vorher: look(.annika, oberteil: 4), ich: .ahmed, aktuell: nil))
        // Annikas eigener Speicherstand beendet den Hinweis.
        let alt = FremdesOutfit(opId: "x", von: .ahmed, vorher: look(.annika, oberteil: 4), zeit: t0)
        let eigene = op("figur.aussehen", a, von: .annika)
        XCTAssertNil(FigurenModell.fremdeAenderung(eigene, ziel: .annika, neu: a, vorher: look(.annika, oberteil: 5), ich: .annika, aktuell: alt))
    }

    func testFremdeAenderungDoppelteLieferungUndUnveraenderterLookAendernNichts() {
        let vorher = look(.annika, oberteil: 4)
        let neu = look(.annika, oberteil: 5)
        let o = aenderung(.ahmed, .annika, neu)
        let erste = FigurenModell.fremdeAenderung(o, ziel: .annika, neu: neu, vorher: vorher, ich: .annika, aktuell: nil)
        // Dieselbe Op noch einmal (Wiedergabe): vorher ist jetzt schon der neue Look, "Zurück" bliebe ohne Wirkung.
        let zweite = FigurenModell.fremdeAenderung(o, ziel: .annika, neu: neu, vorher: neu, ich: .annika, aktuell: erste)
        XCTAssertEqual(zweite, erste)
        XCTAssertNil(FigurenModell.fremdeAenderung(aenderung(.ahmed, .annika, neu), ziel: .annika, neu: neu, vorher: neu, ich: .annika, aktuell: nil))
    }

    // MARK: - Bilder

    private func zelle(_ a: A, groesse: CGFloat = 170) -> AnyView {
        AnyView(
            FigurView(a, zustand: .ruhig, groesse: groesse, animiert: false, ganzkoerper: true)
                .frame(width: 200, height: 200, alignment: .bottom)
                .background(Color(white: 0.93))
        )
    }

    func testBilderVorherNachherUndLooks() {
        let vorher = A.standard(for: .annika)
        var nachher = vorher
        nachher.anziehen(outfit: A.outfits(fuer: .annika)[1])
        let schieber = { (anteil: CGFloat) in
            AnyView(
                VorherNachherView(vorher: vorher, nachher: nachher, groesse: 200, anteil: anteil)
                    .frame(width: 200, height: 200)
                    .background(Color(white: 0.93))
            )
        }
        var ahmedOben = A.standard(for: .ahmed)
        ahmedOben.anziehen(outfit: A.outfits(fuer: .ahmed)[2])
        let zellen: [(titel: String, ansicht: AnyView)] = [
            ("Vorher", zelle(vorher)),
            ("Nachher", zelle(nachher)),
            ("Schieber 30 %", schieber(0.3)),
            ("Schieber 70 %", schieber(0.7)),
            ("Nur Kleidung auf Ahmed", zelle(A.standard(for: .ahmed).mitKleidung(von: ahmedOben))),
        ]
        RenderTafel.speichern("figur-p71-vorher-nachher-looks", spalten: 5, zellen: zellen)
    }
}
