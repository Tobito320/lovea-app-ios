import XCTest
@testable import Lovea

/// p62: the pure rules behind the room's living objects.
@MainActor
final class ZimmerLebenLogikTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Kalenderblatt

    func testKalenderNimmtDenNaechstenGemeinsamenTermin() {
        var daten = KalenderDaten()
        daten.treffen = [Treffen(datum: "2026-10-20", uhrzeit: nil, wasMachenWir: "Kino"), Treffen(datum: "2026-10-12", uhrzeit: "18:00", wasMachenWir: nil)]
        daten.termine = [
            Termin(id: "a", fuer: ["ahmed"], titel: "Zahnarzt", typ: "sonstiges", datum: "2026-10-10", start: nil, ende: nil),
            Termin(id: "b", fuer: ["ahmed", "annika"], titel: "Essen", typ: "sonstiges", datum: "2026-10-15", start: "19:00", ende: nil),
        ]
        let t = ZimmerKalenderblatt.naechster(daten, heute: "2026-10-09")
        XCTAssertEqual(t, ZimmerTermin(titel: "Treffen", tag: "2026-10-12", uhrzeit: "18:00"), "Zahnarzt gehört nur Ahmed")
    }

    func testKalenderIgnoriertVergangenesUndLeereListe() {
        var daten = KalenderDaten()
        daten.treffen = [Treffen(datum: "2026-10-01", uhrzeit: nil, wasMachenWir: "Kino")]
        XCTAssertNil(ZimmerKalenderblatt.naechster(daten, heute: "2026-10-09"))
    }

    func testKalenderBlattMonatUndTag() {
        XCTAssertEqual(ZimmerKalenderblatt.blatt("2026-10-04").monat, "OKT")
        XCTAssertEqual(ZimmerKalenderblatt.blatt("2026-10-04").tag, "4")
        XCTAssertEqual(ZimmerKalenderblatt.blatt("2026-03-14").monat, "MÄR")
        XCTAssertEqual(ZimmerKalenderblatt.blatt("kaputt").monat, "")
    }

    // MARK: Fenster

    func testHimmelAusWetterCode() {
        XCTAssertEqual(ZimmerHimmel(code: 0, tag: true, stunde: 12), ZimmerHimmel(wetter: .sonne, nacht: false))
        XCTAssertEqual(ZimmerHimmel(code: 63, tag: true, stunde: 12).wetter, .regen)
        XCTAssertEqual(ZimmerHimmel(code: 73, tag: true, stunde: 12).wetter, .schnee)
        XCTAssertEqual(ZimmerHimmel(code: 3, tag: true, stunde: 12).wetter, .wolken)
        XCTAssertTrue(ZimmerHimmel(code: 0, tag: false, stunde: 12).nacht, "die Sonne der API schlägt die Uhr")
        XCTAssertEqual(ZimmerHimmel(wetter: .sonne, nacht: true).text, "Klare Nacht")
    }

    // MARK: Pokale

    func testPokaleNurMitSiegenUndMeisteZuerst() {
        let bilanz: [SpielArt: SpielPunkte] = [
            .xo: SpielPunkte(ahmed: 2, annika: 1),
            .memory: SpielPunkte(ahmed: 0, annika: 9),
            .ssp: SpielPunkte(ahmed: 0, annika: 0),
        ]
        let pokale = ZimmerPokale.aus(bilanz)
        XCTAssertEqual(pokale.map(\.art), [.memory, .xo])
        XCTAssertEqual(pokale[0].fuehrt, .annika)
        XCTAssertEqual(pokale[0].stufe, .silber)
        XCTAssertEqual(pokale[1].stufe, .bronze)
    }

    func testPokalStufenUndGleichstand() {
        XCTAssertEqual(ZimmerPokal.stufe(4), .bronze)
        XCTAssertEqual(ZimmerPokal.stufe(5), .silber)
        XCTAssertEqual(ZimmerPokal.stufe(15), .gold)
        XCTAssertNil(ZimmerPokal(art: .xo, ahmed: 3, annika: 3).fuehrt)
        XCTAssertTrue(ZimmerPokale.aus([:]).isEmpty)
    }

    // MARK: Pflanze

    func testPflanzeWaechstMitDerGemeinsamenSerie() {
        XCTAssertEqual(ZimmerPflanzenStand.stufe(serie: 0), 0)
        XCTAssertEqual(ZimmerPflanzenStand.stufe(serie: 2), 1)
        XCTAssertEqual(ZimmerPflanzenStand.stufe(serie: 3), 2)
        XCTAssertEqual(ZimmerPflanzenStand.stufe(serie: 7), 3)
        XCTAssertEqual(ZimmerPflanzenStand.stufe(serie: 14), 4)
    }

    func testPflanzeZaehltDenSchwaechererenPartnerUndDasBesteHabit() {
        let s = ZimmerPflanzenStand.aus([(ahmed: 20, annika: 3), (ahmed: 8, annika: 9)])
        XCTAssertEqual(s, ZimmerPflanzenStand(stufe: 3, haengt: false, serie: 8))
    }

    func testPflanzeHaengtWennNurEinerDranIst() {
        let s = ZimmerPflanzenStand.aus([(ahmed: 30, annika: 0)])
        XCTAssertTrue(s.haengt)
        XCTAssertEqual(s.stufe, 3, "hängend höchstens Stufe 3")
        XCTAssertFalse(ZimmerPflanzenStand.aus([]).haengt)
        XCTAssertEqual(ZimmerPflanzenStand.aus([]).stufe, 0)
    }

    // MARK: Pinnwand

    private func snap(_ id: String, nach sekunden: TimeInterval, gespeichert: Bool = true, foto: Bool = true) -> ChatModell.Nachricht {
        var n = ChatModell.Nachricht(
            id: id, von: .ahmed, zeit: t0.addingTimeInterval(sekunden),
            medien: foto ? [ChatModell.MedienEintrag(id: "m-\(id)", typ: "foto", breite: 3, hoehe: 4, dauer: nil, pegel: nil)] : []
        )
        n.snap = ChatModell.SnapInfo(bleibt: false)
        n.snapGespeichert = gespeichert
        return n
    }

    func testPinnwandLetzteDreiGespeicherteSnapsNeuesteZuerst() {
        let alle = [snap("a", nach: 0), snap("b", nach: 10), snap("c", nach: 20), snap("d", nach: 30), snap("x", nach: 40, gespeichert: false)]
        XCTAssertEqual(ZimmerFotos.letzte(alle).map(\.id), ["d", "c", "b"])
        XCTAssertEqual(ZimmerFotos.letzte(alle).first?.medienId, "m-d")
    }

    func testPinnwandOhneFotoOderGeloeschtLeer() {
        var geloescht = snap("g", nach: 0)
        geloescht.geloescht = true
        XCTAssertTrue(ZimmerFotos.letzte([snap("t", nach: 0, foto: false), geloescht]).isEmpty)
        XCTAssertTrue(ZimmerFotos.letzte([]).isEmpty)
    }

    // MARK: Fernseher

    func testFilmeHinzufuegenOhneDoppelteUndLeere() {
        var liste = ZimmerFilme.hinzufuegen([], titel: "  Up  ", serie: false, id: "1")
        liste = ZimmerFilme.hinzufuegen(liste, titel: "up", serie: true, id: "2")
        liste = ZimmerFilme.hinzufuegen(liste, titel: "   ", serie: false, id: "3")
        liste = ZimmerFilme.hinzufuegen(liste, titel: "Dark", serie: true, id: "4")
        XCTAssertEqual(liste.map(\.titel), ["Up", "Dark"])
    }

    func testFernseherZeigtDenErstenUngesehenen() {
        var liste = ZimmerFilme.hinzufuegen([], titel: "Up", serie: false, id: "1")
        liste = ZimmerFilme.hinzufuegen(liste, titel: "Dark", serie: true, id: "2")
        XCTAssertEqual(ZimmerFilme.laeuft(liste)?.titel, "Up")
        liste = ZimmerFilme.umschalten(liste, id: "1")
        XCTAssertEqual(ZimmerFilme.laeuft(liste)?.titel, "Dark")
        liste = ZimmerFilme.umschalten(ZimmerFilme.umschalten(liste, id: "2"), id: "1")
        XCTAssertEqual(ZimmerFilme.laeuft(liste)?.titel, "Up", "wieder ungesehen")
        XCTAssertNil(ZimmerFilme.laeuft(ZimmerFilme.entfernen(ZimmerFilme.entfernen(liste, id: "1"), id: "2")))
    }

    // MARK: Ziel

    func testZielAnteilUndText() {
        let z = ZimmerZiel(titel: "Rom", koffer: true, ziel: 500, gespart: 120)
        XCTAssertEqual(z.anteil, 0.24, accuracy: 0.0001)
        XCTAssertEqual(z.text, "120 von 500 €")
        XCTAssertFalse(z.geschafft)
    }

    func testZielGrenzen() {
        XCTAssertEqual(ZimmerZiel(titel: "a", koffer: false, ziel: 100, gespart: 250).anteil, 1)
        XCTAssertTrue(ZimmerZiel(titel: "a", koffer: false, ziel: 100, gespart: 100).geschafft)
        XCTAssertEqual(ZimmerZiel(titel: "a", koffer: false, ziel: 0, gespart: 5).anteil, 0)
        XCTAssertFalse(ZimmerZiel(titel: "a", koffer: false, ziel: 0, gespart: 5).geschafft)
        XCTAssertEqual(ZimmerZiel(titel: "a", koffer: false, ziel: 99.5, gespart: 10.25).text, "10,25 von 99,50 €")
    }

    func testZielUndFilmeRundlaufDurchJSON() throws {
        let z = ZimmerZiel(titel: "Rom", koffer: true, ziel: 500, gespart: 120)
        XCTAssertEqual(try JSONDecoder().decode(ZimmerZiel.self, from: JSONEncoder().encode(z)), z)
        let f = ZimmerFilme.hinzufuegen([], titel: "Up", serie: false, id: "1")
        XCTAssertEqual(try JSONDecoder().decode([ZimmerFilm].self, from: JSONEncoder().encode(f)), f)
    }
}

/// Where the other one is: bed, gym, home.
final class ZimmerAndereTests: XCTestCase {
    func testBettSchlaegtAllesAndere() {
        XCTAssertEqual(ZimmerAndere.bestimmen(schlaf: .schlaeft, ort: "gym", gymHeute: true, stunde: 23), .bett)
        XCTAssertEqual(ZimmerAndere.bestimmen(schlaf: .sitzt, ort: nil, gymHeute: false, stunde: 22), .bett)
    }

    func testGymImMomentUndHeuteBisZweiundzwanzigUhr() {
        XCTAssertEqual(ZimmerAndere.bestimmen(schlaf: .wach, ort: "gym", gymHeute: false, stunde: 18), .sport)
        XCTAssertEqual(ZimmerAndere.bestimmen(schlaf: .wach, ort: nil, gymHeute: true, stunde: 21), .sport)
        XCTAssertEqual(ZimmerAndere.bestimmen(schlaf: .wach, ort: "zuhause", gymHeute: true, stunde: 22), .zuhause)
    }

    func testSonstZuhauseUndFigurZustand() {
        XCTAssertEqual(ZimmerAndere.bestimmen(schlaf: .wach, ort: nil, gymHeute: false, stunde: 10), .zuhause)
        XCTAssertEqual(ZimmerAndere.Wo.sport.figur, .gym)
        XCTAssertEqual(ZimmerAndere.Wo.bett.figur, .schlaeft)
        XCTAssertEqual(ZimmerAndere.Wo.zuhause.figur, .ruhig)
    }
}
