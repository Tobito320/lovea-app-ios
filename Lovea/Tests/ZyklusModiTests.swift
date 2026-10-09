import SwiftUI
import XCTest
@testable import Lovea

@MainActor
private final class ModiTestSpeicher: ZyklusSpeicher {
    let quelle = ZyklusQuelle.demo
    var tage: [String: ZyklusTag]
    var einstellung: ZyklusEinstellung

    init(tage: [String: ZyklusTag], einstellung: ZyklusEinstellung = ZyklusEinstellung()) {
        self.tage = tage
        self.einstellung = einstellung
    }

    func setze(_ tag: ZyklusTag) {
        if tag.istLeer { tage[tag.id] = nil } else { tage[tag.id] = tag }
    }
}

/// Periode 1. bis 5. September 2026, Zyklus 28 Tage: Eisprung 15.9., fruchtbar 10. bis 16.9., nächste Periode 29.9.
private func periodenTage() -> [String: ZyklusTag] {
    Dictionary(uniqueKeysWithValues: (1...5).map { n in
        let id = String(format: "2026-09-%02d", n)
        return (id, ZyklusTag(id: id, blutung: .mittel))
    })
}

final class ZyklusModiLogikTests: XCTestCase {
    func testWocheUndTag() {
        let s = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-09-01")
        XCTAssertEqual(s.woche, 0)
        XCTAssertEqual(s.tag, 0)
        let t = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-13")
        XCTAssertEqual(t.woche, 6)
        XCTAssertEqual(t.tag, 0)
        let u = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-16")
        XCTAssertEqual(u.woche, 6)
        XCTAssertEqual(u.tag, 3)
    }

    func testTerminIstStartPlus280() {
        let s = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-09-01")
        XCTAssertEqual(s.termin, Datum.addTage("2026-09-01", 280))
        XCTAssertEqual(s.tageBisTermin, 280)
    }

    func testEigenerTerminHatVorrang() {
        let termin = "2027-06-01"
        let s = ZyklusModiLogik.schwangerStand(start: "2026-01-01", termin: termin, heute: Datum.addTage(termin, -280 + 14))
        XCTAssertEqual(s.termin, termin)
        XCTAssertEqual(s.woche, 2)
    }

    func testTerminVorbeiIstNegativ() {
        let s = ZyklusModiLogik.schwangerStand(start: "2026-01-01", heute: Datum.addTage("2026-01-01", 285))
        XCTAssertEqual(s.tageBisTermin, -5)
    }

    func testTrimester() {
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 0), 1)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 13), 1)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 14), 2)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 27), 2)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 28), 3)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 41), 3)
    }

    func testGroessenVergleich() {
        XCTAssertNil(ZyklusModiLogik.groessenVergleich(woche: 3))
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 4), "ein Mohnkorn")
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 14), "eine Zitrone")
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 21), "eine Banane")
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 44), "eine kleine Wassermelone")
    }

    func testWochenText() {
        let a = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-13")
        XCTAssertEqual(ZyklusModiLogik.wochenText(a), "6. Woche")
        let b = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-16")
        XCTAssertEqual(ZyklusModiLogik.wochenText(b), "6. Woche, Tag 3")
    }

    func testPille21Sieben() {
        let start = "2026-09-01"
        let tag1 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: start)!
        XCTAssertEqual(tag1.tagInPackung, 1)
        XCTAssertTrue(tag1.nehmen)
        XCTAssertEqual(tag1.tageBisPause, 21)
        let tag21 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 20))!
        XCTAssertEqual(tag21.tagInPackung, 21)
        XCTAssertTrue(tag21.nehmen)
        XCTAssertEqual(tag21.tageBisPause, 1)
        let tag22 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 21))!
        XCTAssertTrue(tag22.pause)
        XCTAssertFalse(tag22.nehmen)
        XCTAssertEqual(tag22.tageBisPause, 0)
        let tag28 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 27))!
        XCTAssertEqual(tag28.tageBisNeuePackung, 1)
        let neu = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 28))!
        XCTAssertEqual(neu.tagInPackung, 1)
        XCTAssertFalse(neu.pause)
    }

    func testPille28NimmtAuchPlatzhalter() {
        let start = "2026-09-01"
        let platzhalter = ZyklusModiLogik.pillenStand(start: start, packung: .achtundzwanzig, heute: Datum.addTage(start, 24))!
        XCTAssertTrue(platzhalter.pause)
        XCTAssertTrue(platzhalter.nehmen)
        XCTAssertFalse(platzhalter.wirkstoff)
        let wirkstoff = ZyklusModiLogik.pillenStand(start: start, packung: .achtundzwanzig, heute: Datum.addTage(start, 5))!
        XCTAssertTrue(wirkstoff.wirkstoff)
    }

    func testPilleVorStartIstNil() {
        XCTAssertNil(ZyklusModiLogik.pillenStand(start: "2026-09-10", packung: .einundzwanzig, heute: "2026-09-09"))
    }

    func testPillenStartReihenfolge() {
        let logik = ZyklusLogik(tage: Array(periodenTage().values), heute: "2026-09-10")
        XCTAssertEqual(ZyklusModiLogik.pillenStart(gesetzt: "2026-08-20", logik: logik, tage: []), "2026-08-20")
        XCTAssertEqual(ZyklusModiLogik.pillenStart(gesetzt: nil, logik: logik, tage: []), "2026-09-01")
        let ohne = ZyklusLogik(tage: [], heute: "2026-09-10")
        let tage = [ZyklusTag(id: "2026-09-04", pille: true), ZyklusTag(id: "2026-09-03", pille: true)]
        XCTAssertEqual(ZyklusModiLogik.pillenStart(gesetzt: nil, logik: ohne, tage: tage), "2026-09-03")
        XCTAssertNil(ZyklusModiLogik.pillenStart(gesetzt: nil, logik: ohne, tage: []))
    }

    func testPillenSerie() {
        let tage = Dictionary(uniqueKeysWithValues: ["2026-09-06", "2026-09-07", "2026-09-08"].map { ($0, ZyklusTag(id: $0, pille: true)) })
        XCTAssertEqual(ZyklusModiLogik.pillenSerie(tage: tage, heute: "2026-09-08"), 3)
        XCTAssertEqual(ZyklusModiLogik.pillenSerie(tage: tage, heute: "2026-09-09"), 3)
        XCTAssertEqual(ZyklusModiLogik.pillenSerie(tage: tage, heute: "2026-09-10"), 0)
        XCTAssertTrue(ZyklusModiLogik.pilleGenommen(tage: tage, heute: "2026-09-07"))
        XCTAssertFalse(ZyklusModiLogik.pilleGenommen(tage: tage, heute: "2026-09-09"))
    }

    func testKinderwunschLagen() {
        let tage = periodenTage()
        func lage(_ heute: String) -> ZyklusModiLogik.KinderwunschStand {
            let logik = ZyklusLogik(tage: Array(tage.values), heute: heute)
            return ZyklusModiLogik.kinderwunschStand(logik: logik, tage: Array(tage.values), heute: heute)
        }
        XCTAssertEqual(lage("2026-09-07").lage, .bald(tage: 3))
        XCTAssertEqual(lage("2026-09-10").lage, .fruchtbar)
        XCTAssertEqual(lage("2026-09-15").lage, .eisprung)
        XCTAssertEqual(lage("2026-09-20").lage, .vorbei)
        let leer = ZyklusLogik(tage: [], heute: "2026-09-07")
        XCTAssertEqual(ZyklusModiLogik.kinderwunschStand(logik: leer, tage: [], heute: "2026-09-07").lage, .unbekannt)
    }

    func testKinderwunschZaehltTestsImZyklus() {
        var tage = periodenTage()
        tage["2026-09-12"] = ZyklusTag(id: "2026-09-12", eisprungTest: .negativ)
        tage["2026-09-14"] = ZyklusTag(id: "2026-09-14", eisprungTest: .positiv)
        tage["2026-08-10"] = ZyklusTag(id: "2026-08-10", eisprungTest: .positiv)
        let logik = ZyklusLogik(tage: Array(tage.values), heute: "2026-09-14")
        let s = ZyklusModiLogik.kinderwunschStand(logik: logik, tage: Array(tage.values), heute: "2026-09-14")
        XCTAssertEqual(s.positiveTests, 1)
        XCTAssertEqual(s.negativeTests, 1)
    }
}

final class ZyklusErinnerungenPlanTests: XCTestCase {
    private func plan(modus: Modus = .zyklus, aktiv: Set<ErinnerungsArt> = Set(ErinnerungsArt.allCases),
                      heute: String = "2026-09-06", jetzt: Int = 600) -> [GeplanteErinnerung] {
        var e = ZyklusEinstellung()
        e.modus = modus
        let tage = Array(periodenTage().values)
        let logik = ZyklusLogik(tage: tage, einstellung: e, heute: heute)
        return ErinnerungsPlan.plan(logik: logik, einstellung: ErinnerungsEinstellung(aktiv: aktiv), heute: heute, jetztMinute: jetzt)
    }

    private func tage(_ liste: [GeplanteErinnerung], _ art: ErinnerungsArt) -> [String] {
        liste.filter { $0.art == art }.compactMap {
            if case .einmalig(let tag, _) = $0.zeit { return tag }
            return nil
        }.sorted()
    }

    func testNichtsAktivNichtsGeplant() {
        XCTAssertTrue(plan(aktiv: []).isEmpty)
    }

    func testTermineImZyklus() {
        let p = plan()
        XCTAssertEqual(tage(p, .periodeBald), ["2026-09-27", "2026-10-25"])
        XCTAssertEqual(tage(p, .fruchtbar), ["2026-09-10", "2026-10-08"])
        XCTAssertEqual(tage(p, .eisprung), ["2026-09-15", "2026-10-13"])
        XCTAssertEqual(tage(p, .verspaetung), ["2026-10-02"])
    }

    func testTaeglicheArten() {
        let p = plan()
        XCTAssertEqual(p.filter { $0.art == .wasser }.count, 1)
        XCTAssertEqual(p.filter { $0.art == .eintragen }.count, 1)
        XCTAssertTrue(p.contains { $0.art == .wasser && $0.zeit == .taeglich(minute: 15 * 60) })
        XCTAssertTrue(p.filter { $0.art == .pille }.isEmpty)
    }

    func testPilleNurImPillenModus() {
        let p = plan(modus: .pille)
        XCTAssertEqual(p.filter { $0.art == .pille }.count, 1)
        XCTAssertTrue(tage(p, .fruchtbar).isEmpty)
        XCTAssertTrue(tage(p, .periodeBald).isEmpty)
    }

    func testSchwangerNurTaeglichesUndKeineZyklusTermine() {
        let p = plan(modus: .schwanger)
        XCTAssertEqual(Set(p.map(\.art)), [.wasser, .eintragen])
    }

    func testKinderwunschHatFruchtbarUndEisprung() {
        let p = plan(modus: .kinderwunsch)
        XCTAssertFalse(tage(p, .fruchtbar).isEmpty)
        XCTAssertFalse(tage(p, .eisprung).isEmpty)
    }

    func testEinzelnAbschaltbar() {
        var arten = Set(ErinnerungsArt.allCases)
        arten.remove(.eisprung)
        let p = plan(aktiv: arten)
        XCTAssertTrue(tage(p, .eisprung).isEmpty)
        XCTAssertFalse(tage(p, .fruchtbar).isEmpty)
    }

    func testVergangenesEntfaellt() {
        let p = plan(heute: "2026-09-16")
        XCTAssertEqual(tage(p, .fruchtbar), ["2026-10-08"])
        XCTAssertEqual(tage(p, .eisprung), ["2026-10-13"])
    }

    func testHeutigerTermin() {
        XCTAssertEqual(tage(plan(heute: "2026-09-10", jetzt: 500), .fruchtbar).first, "2026-09-10")
        XCTAssertEqual(tage(plan(heute: "2026-09-10", jetzt: 600), .fruchtbar).first, "2026-10-08")
    }

    func testTexteNeutralOhneZyklusWort() {
        let verboten = ["periode", "zyklus", "pille", "eisprung", "fruchtbar", "schwanger", "blutung", "regel"]
        for art in ErinnerungsArt.allCases {
            let e = GeplanteErinnerung(art: art, zeit: .taeglich(minute: 0))
            for text in [e.titel, e.text] {
                XCTAssertFalse(text.isEmpty)
                for wort in verboten { XCTAssertFalse(text.lowercased().contains(wort), "\(art): \(text)") }
            }
        }
    }

    func testIdsEindeutigMitPraefix() {
        let p = plan(modus: .pille)
        XCTAssertEqual(Set(p.map(\.id)).count, p.count)
        XCTAssertTrue(p.allSatisfy { $0.id.hasPrefix(ErinnerungsPlan.praefix) })
    }

    func testEinstellungRoundTrip() throws {
        var e = ErinnerungsEinstellung()
        e.aktiv = [.wasser, .pille]
        e.minuten[.pille] = 7 * 60 + 30
        let neu = try JSONDecoder().decode(ErinnerungsEinstellung.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(neu, e)
        XCTAssertEqual(neu.minute(.pille), 450)
        XCTAssertEqual(neu.minute(.wasser), 15 * 60)
    }
}

/// Render boards for the three modes with fixed data, light and dark.
@MainActor
final class RenderGalerieZyklusModiTests: XCTestCase {
    private func tafel(_ schema: ColorScheme) -> [(titel: String, ansicht: AnyView)] {
        let tage = periodenTage()
        let schwanger = ModiTestSpeicher(tage: tage, einstellung: ZyklusEinstellung(zyklusLaenge: 28, periodenLaenge: 5, modus: .schwanger))
        let kinder = ModiTestSpeicher(tage: tage, einstellung: ZyklusEinstellung(zyklusLaenge: 28, periodenLaenge: 5, modus: .kinderwunsch))
        var pillenTage = tage
        for id in ["2026-09-09", "2026-09-10", "2026-09-11"] { pillenTage[id] = ZyklusTag(id: id, pille: true) }
        let pille = ModiTestSpeicher(tage: pillenTage, einstellung: ZyklusEinstellung(zyklusLaenge: 28, periodenLaenge: 5, modus: .pille))
        func rahmen<V: View>(_ v: V) -> AnyView {
            AnyView(v.frame(width: 390, height: 900).environment(\.colorScheme, schema))
        }
        let art = schema == .light ? "hell" : "dunkel"
        return [
            ("Schwanger, \(art)", rahmen(ZyklusSchwangerView(speicher: schwanger, heute: "2026-10-16", scrollt: false))),
            ("Kinderwunsch, \(art)", rahmen(ZyklusKinderwunschView(speicher: kinder, heute: "2026-09-12", scrollt: false))),
            ("Pille, \(art)", rahmen(ZyklusPilleView(speicher: pille, packungStart: "2026-09-01", heute: "2026-09-12", erinnerungAn: true, scrollt: false)))
        ]
    }

    func testModiHell() {
        RenderTafel.speichern("zyklus-modi-hell", spalten: 3, zellen: tafel(.light))
    }

    func testModiDunkel() {
        RenderTafel.speichern("zyklus-modi-dunkel", spalten: 3, zellen: tafel(.dark))
    }
}
