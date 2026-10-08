import XCTest
@testable import Lovea

final class ErinnerungLogikTests: XCTestCase {
    // MARK: 3 Pfoten

    func testPfotenGemeinsamIstSchnittmenge() {
        XCTAssertEqual(PfotenLogik.gemeinsam(["b", "a", "c"], ["c", "a", "x"]), ["a", "c"])
        XCTAssertEqual(PfotenLogik.gemeinsam([], ["a"]), [])
    }

    func testPfotenMerkenNeuerTagBeginntLeer() {
        let alt = PfotenLogik.TippTag(tag: "2026-10-08", dinge: ["kugel"])
        let neu = PfotenLogik.merken(alt, ding: "garten", heute: "2026-10-09")
        XCTAssertEqual(neu.dinge, ["garten"])
        XCTAssertEqual(PfotenLogik.menge(alt, heute: "2026-10-09"), [])
    }

    func testPfotenMerkenDoppeltAendertNichts() {
        let alt = PfotenLogik.TippTag(tag: "2026-10-09", dinge: ["kugel"])
        XCTAssertEqual(PfotenLogik.merken(alt, ding: "kugel", heute: "2026-10-09"), alt)
        XCTAssertEqual(PfotenLogik.merken(alt, ding: "garten", heute: "2026-10-09").dinge, ["kugel", "garten"])
    }

    // MARK: 4 Liebesschloesser

    func testSchloesserEinsProVollemMonat() {
        let l = LiebesSchloesserLogik.alle(start: "2026-08-26", heute: "2026-10-26")
        XCTAssertEqual(l.map(\.tag), ["2026-09-26", "2026-10-26"])
        XCTAssertEqual(LiebesSchloesserLogik.alle(start: "2026-08-26", heute: "2026-09-25").count, 0)
    }

    func testSchloesserSichtbarDeckelt() {
        let l = LiebesSchloesserLogik.alle(start: "2020-01-01", heute: "2026-01-01")
        let (s, aeltere) = LiebesSchloesserLogik.sichtbar(l)
        XCTAssertEqual(s.count, LiebesSchloesserLogik.hoechstens)
        XCTAssertEqual(aeltere, l.count - 12)
        XCTAssertEqual(s.last?.nummer, l.last?.nummer)
    }

    func testGravur() {
        XCTAssertEqual(LiebesSchloesserLogik.gravur("2026-09-26"), "26.09.2026")
        XCTAssertEqual(LiebesSchloesserLogik.gravur("kaputt"), "kaputt")
    }

    // MARK: 5 Schneekugel

    func testSchneekugelBereinigtFaelltAufStandard() {
        let k = SchneekugelLogik.bereinigt(SchneekugelKarte(ort: "  ", tag: "", text: " hi "), start: "2026-08-26")
        XCTAssertEqual(k.ort, SchneekugelKarte.standard(start: "2026-08-26").ort)
        XCTAssertEqual(k.tag, "2026-08-26")
        XCTAssertEqual(k.text, "hi")
    }

    func testSchneekugelLaengenBegrenzt() {
        let k = SchneekugelLogik.bereinigt(SchneekugelKarte(ort: String(repeating: "a", count: 100), tag: "2026-01-01", text: String(repeating: "b", count: 500)), start: "x")
        XCTAssertEqual(k.ort.count, 60)
        XCTAssertEqual(k.text.count, 240)
    }

    func testFlockenMitBewegungsreduzierung() {
        XCTAssertEqual(SchneekugelLogik.flocken(geschuettelt: false, reduzieren: false), 0)
        XCTAssertEqual(SchneekugelLogik.flocken(geschuettelt: true, reduzieren: true), 6)
        XCTAssertEqual(SchneekugelLogik.flocken(geschuettelt: true, reduzieren: false), 28)
    }

    // MARK: 7 Balkon-Garten

    func testGartenZaehltGemeinsameEinmalProTagUndArt() {
        let e: [(datum: String, grund: String)] = [
            ("2026-10-05", "Gemeinsam Woche"), ("2026-10-05", "Gemeinsam Woche"),
            ("2026-10-05", "Gemeinsam Monat"), ("2026-10-06", "Sonstiges")
        ]
        XCTAssertEqual(BalkonGartenLogik.anzahl(eintraege: e), 2)
    }

    func testGartenLayoutGedeckeltUndStabil() {
        XCTAssertEqual(BalkonGartenLogik.layout(anzahl: 99).count, BalkonGartenLogik.hoechstens)
        XCTAssertEqual(BalkonGartenLogik.layout(anzahl: -3).count, 0)
        XCTAssertEqual(BalkonGartenLogik.layout(anzahl: 5), BalkonGartenLogik.layout(anzahl: 5))
        XCTAssertTrue(BalkonGartenLogik.layout(anzahl: 12).allSatisfy { (0...1).contains($0.x) && $0.hoehe >= 0.45 && $0.hoehe <= 1 && (0..<4).contains($0.farbe) })
    }

    // MARK: 9 Polaroid

    private func foto(_ id: String, _ tag: String) -> ZimmerPolaroid {
        ZimmerPolaroid(id: id, medienId: id, zeit: Datum.datum(tag).addingTimeInterval(12 * 3600))
    }

    func testPolaroidWahlBevorzugtDieseWoche() {
        let fotos = [foto("alt", "2026-09-01"), foto("neu", "2026-10-07"), foto("neuer", "2026-10-08")]
        XCTAssertEqual(PolaroidWandLogik.wahl(fotos, heute: "2026-10-09")?.id, "neuer")
    }

    func testPolaroidWahlSonstNeuestes() {
        let fotos = [foto("a", "2026-09-01"), foto("b", "2026-09-10")]
        XCTAssertEqual(PolaroidWandLogik.wahl(fotos, heute: "2026-10-09")?.id, "b")
        XCTAssertNil(PolaroidWandLogik.wahl([], heute: "2026-10-09"))
    }

    func testPolaroidEntwicklungNurEinmal() {
        XCTAssertTrue(PolaroidWandLogik.entwickelt(foto: "a", gesehen: []))
        XCTAssertFalse(PolaroidWandLogik.entwickelt(foto: "a", gesehen: ["a"]))
        XCTAssertEqual(PolaroidWandLogik.fortschritt(vergangen: -1), 0)
        XCTAssertEqual(PolaroidWandLogik.fortschritt(vergangen: 99), 1)
        XCTAssertEqual(PolaroidWandLogik.fortschritt(vergangen: PolaroidWandLogik.entwicklung / 2), 0.5, accuracy: 0.001)
    }

    // MARK: 16 Katze

    func testKatzenStufen() {
        XCTAssertEqual(KatzenWachstumLogik.stufe(serie: 0), 0)
        XCTAssertEqual(KatzenWachstumLogik.stufe(serie: 7), 1)
        XCTAssertEqual(KatzenWachstumLogik.stufe(serie: 29), 1)
        XCTAssertEqual(KatzenWachstumLogik.stufe(serie: 30), 2)
        XCTAssertEqual(KatzenWachstumLogik.stufenName(serie: 500), "Große Katze")
    }

    func testKatzenKuenste() {
        XCTAssertEqual(KatzenWachstumLogik.kunststuecke(serie: 2), [])
        XCTAssertEqual(KatzenWachstumLogik.kunststuecke(serie: 14), ["Sitz", "Pfötchen"])
        XCTAssertEqual(KatzenWachstumLogik.naechste(serie: 14)?.name, "Rolle")
        XCTAssertEqual(KatzenWachstumLogik.naechste(serie: 14)?.fehlen, 16)
        XCTAssertNil(KatzenWachstumLogik.naechste(serie: 100))
    }

    func testKatzenSerieIstDieLaengere() {
        XCTAssertEqual(KatzenWachstumLogik.serie([.ahmed: 3, .annika: 9]), 9)
        XCTAssertEqual(KatzenWachstumLogik.serie([:]), 0)
    }

    func testKatzenNameBegrenzt() {
        XCTAssertEqual(KatzenWachstumLogik.name("  Luna  "), "Luna")
        XCTAssertEqual(KatzenWachstumLogik.name(String(repeating: "x", count: 40)).count, KatzenWachstumLogik.namensGrenze)
    }

    // MARK: 19 Kisten

    func testKisteGesperrtBisZumTag() {
        let k = ErinnerungsKiste(id: "1", titel: "t", tag: "2026-12-24", notiz: "", von: "ahmed")
        XCTAssertTrue(ErinnerungsKistenLogik.gesperrt(k, heute: "2026-12-23"))
        XCTAssertFalse(ErinnerungsKistenLogik.gesperrt(k, heute: "2026-12-24"))
        XCTAssertEqual(ErinnerungsKistenLogik.tageBis(k, heute: "2026-12-20"), 4)
        XCTAssertEqual(ErinnerungsKistenLogik.tageBis(k, heute: "2027-01-01"), 0)
    }

    func testKisteHinzufuegenPruefung() {
        let a = ErinnerungsKistenLogik.hinzufuegen([], titel: "  Reise ", tag: "2027-01-01", notiz: "x", von: .ahmed, id: "1")
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a[0].titel, "Reise")
        XCTAssertEqual(ErinnerungsKistenLogik.hinzufuegen(a, titel: "Neu", tag: "2027-01-01", notiz: "", von: .annika, id: "1"), a)
        XCTAssertEqual(ErinnerungsKistenLogik.hinzufuegen(a, titel: "   ", tag: "2027-01-01", notiz: "", von: .annika, id: "2"), a)
    }

    func testKisteHoechstens() {
        var l: [ErinnerungsKiste] = []
        for i in 0..<12 { l = ErinnerungsKistenLogik.hinzufuegen(l, titel: "k\(i)", tag: "2027-01-01", notiz: "", von: .ahmed, id: "\(i)") }
        XCTAssertEqual(l.count, ErinnerungsKistenLogik.hoechstens)
    }

    func testKisteNeuOffenUndSortierung() {
        let a = ErinnerungsKiste(id: "a", titel: "a", tag: "2026-10-01", notiz: "", von: "ahmed")
        let b = ErinnerungsKiste(id: "b", titel: "b", tag: "2026-09-01", notiz: "", von: "ahmed")
        let c = ErinnerungsKiste(id: "c", titel: "c", tag: "2027-01-01", notiz: "", von: "ahmed")
        let neu = ErinnerungsKistenLogik.neuOffen([a, b, c], gesehen: ["b"], heute: "2026-10-09")
        XCTAssertEqual(neu.map(\.id), ["a"])
        XCTAssertEqual(ErinnerungsKistenLogik.sortiert([c, a, b]).map(\.id), ["b", "a", "c"])
    }
}
