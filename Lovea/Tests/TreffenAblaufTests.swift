import XCTest
@testable import Lovea

/// Treffen mit Ablauf, Teil 1: reine Logik, Faltung und vor allem die Überraschung: Der Inhalt eines
/// versteckten Punkts steht in keiner Op, die der Partner bekommt.
final class TreffenAblaufTests: XCTestCase {

    // MARK: - Helfer

    private func berlin(_ j: Int, _ m: Int, _ t: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = j; c.month = m; c.day = t; c.hour = h; c.minute = min
        return Datum.kalender.date(from: c)!
    }

    private func op<T: Encodable>(_ art: String, _ d: T, von: Person = .ahmed, seq: Int? = nil, zeit: Date = Date(), id: String = UUID().uuidString) -> Op {
        let neu = Op.neu(art, d, von: von)
        return Op(id: id, seq: seq, art: art, von: von, zeit: zeit, d: neu.d)
    }

    private func live(_ lieferungen: [[Op]]) -> KalenderModell.Zustand {
        var faltung = SeqFaltung()
        var zustand = KalenderModell.Zustand()
        for batch in lieferungen { zustand = KalenderModell.einarbeiten(batch, faltung: &faltung, zustand: zustand) }
        return zustand
    }

    private func punkt(_ id: String, start: String? = nil, ende: String? = nil, titel: String? = "Essen", von: Person = .ahmed,
                       versteckt: Bool = false, ab: Date? = nil) -> TreffenPunkt {
        TreffenPunkt(id: id, datum: "2026-10-03", von: von, start: start, ende: ende, titel: titel, notiz: nil, ort: nil, versteckt: versteckt, sichtbarAb: ab)
    }

    private func geheim(_ id: String, ab: Date, titel: String = "Geheim X", geloescht: Bool = false) -> GeheimPunkt {
        GeheimPunkt(
            id: id, datum: "2026-10-03", start: "12:00", ende: nil, titel: titel, notiz: nil, ort: nil, sichtbarAb: ab,
            freigabe: FreigabeWahl(art: .tage, n: 1), geloescht: geloescht, zeit: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func setzenD(_ id: String, titel: String = "Kino", datum: String = "2026-10-03") -> PunktSetzenD {
        PunktSetzenD(datum: datum, id: id, start: "19:00", ende: "21:00", titel: titel, notiz: "n", ort: nil)
    }

    private func platzhalterD(_ id: String, datum: String = "2026-10-03") -> PlatzhalterD {
        PlatzhalterD(datum: datum, id: id, start: "19:00", ende: "21:00", sichtbarAb: "2026-10-03T07:00:00Z")
    }

    // MARK: - zeitraum und zeitText

    func testZeitraumAltesTreffenNurUhrzeit() {
        let z = TreffenLogik.zeitraum(treffen: Treffen(datum: "2026-10-03", uhrzeit: "19:00", wasMachenWir: nil), punkte: [])
        XCTAssertEqual(z.von, "19:00")
        XCTAssertNil(z.bis)
    }

    func testZeitraumNurPunkte() {
        let punkte = [punkt("a", start: "14:00", ende: "15:00"), punkt("b", start: "09:30", ende: "18:45"), punkt("c")]
        let z = TreffenLogik.zeitraum(treffen: Treffen(datum: "2026-10-03"), punkte: punkte)
        XCTAssertEqual(z.von, "09:30")
        XCTAssertEqual(z.bis, "18:45")
    }

    func testZeitraumTreffenSchlaegtPunkte() {
        let punkte = [punkt("a", start: "09:00", ende: "23:00")]
        let z = TreffenLogik.zeitraum(treffen: Treffen(datum: "2026-10-03", uhrzeit: "19:00", wasMachenWir: nil, bis: "22:30"), punkte: punkte)
        XCTAssertEqual(z.von, "19:00")
        XCTAssertEqual(z.bis, "22:30")
    }

    func testZeitText() {
        XCTAssertEqual(TreffenLogik.zeitText(von: "19:00", bis: "22:30"), "19:00–22:30")
        XCTAssertEqual(TreffenLogik.zeitText(von: "19:00", bis: nil), "ab 19:00")
        XCTAssertEqual(TreffenLogik.zeitText(von: nil, bis: "22:30"), "bis 22:30")
        XCTAssertNil(TreffenLogik.zeitText(von: nil, bis: nil))
    }

    // MARK: - sortiert

    func testSortiertNachStartDannEndeDannIdOhneZeitAmEnde() {
        let punkte = [
            punkt("e"), punkt("d", start: "10:00", ende: "12:00"), punkt("c", start: "10:00", ende: "11:00"),
            punkt("b", start: "10:00", ende: "11:00"), punkt("a", start: "09:00"),
        ]
        XCTAssertEqual(TreffenLogik.sortiert(punkte).map(\.id), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(TreffenLogik.sortiert(punkte.reversed()).map(\.id), ["a", "b", "c", "d", "e"], "gleiche Zeit: stabil nach Id")
    }

    // MARK: - ansicht

    func testAnsichtErstellerSiehtAlles() {
        let p = punkt("a", von: .ahmed, versteckt: true, ab: berlin(2026, 10, 3, 9))
        XCTAssertEqual(TreffenLogik.ansicht(p, ich: .ahmed, jetzt: berlin(2026, 10, 1)), .voll)
    }

    func testAnsichtPartnerVorUndNachDerFreigabeOhneInhalt() {
        let ab = berlin(2026, 10, 3, 9)
        let platzhalter = punkt("a", titel: nil, von: .ahmed, versteckt: true, ab: ab)
        XCTAssertEqual(TreffenLogik.ansicht(platzhalter, ich: .annika, jetzt: berlin(2026, 10, 3, 8)), .versteckt(ab: ab, gleich: false))
        XCTAssertEqual(TreffenLogik.ansicht(platzhalter, ich: .annika, jetzt: berlin(2026, 10, 3, 9)), .versteckt(ab: ab, gleich: true))
        XCTAssertEqual(TreffenLogik.ansicht(platzhalter, ich: .annika, jetzt: berlin(2026, 10, 4)), .versteckt(ab: ab, gleich: true))
    }

    func testAnsichtOeffentlicherPunktFuerBeideVoll() {
        let p = punkt("a", von: .ahmed)
        XCTAssertEqual(TreffenLogik.ansicht(p, ich: .annika, jetzt: Date()), .voll)
        XCTAssertEqual(TreffenLogik.ansicht(p, ich: .ahmed, jetzt: Date()), .voll)
    }

    func testAnsichtVersteckterPunktMitInhaltBleibtFuerPartnerVersteckt() {
        let p = punkt("a", von: .ahmed, versteckt: true, ab: berlin(2026, 10, 3, 9))
        guard case .versteckt = TreffenLogik.ansicht(p, ich: .annika, jetzt: Date()) else { return XCTFail("muss versteckt sein") }
    }

    func testAnsichtEigenerPlatzhalterOhneInhaltIstVersteckt() {
        let p = punkt("a", titel: nil, von: .ahmed, versteckt: true, ab: berlin(2026, 10, 3, 9))
        guard case .versteckt = TreffenLogik.ansicht(p, ich: .ahmed, jetzt: berlin(2026, 10, 1)) else { return XCTFail("kein Inhalt, nichts zu zeigen") }
    }

    // MARK: - freigabeZeit

    func testFreigabeZeitTage() {
        let ab = TreffenLogik.freigabeZeit(FreigabeWahl(art: .tage, n: 3), datum: "2026-10-03", start: "12:00")
        XCTAssertEqual(ab, berlin(2026, 9, 30, 12))
    }

    func testFreigabeZeitAmTagUndFruehererBeginn() {
        XCTAssertEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .amTag, n: 0), datum: "2026-10-03", start: "12:00"), berlin(2026, 10, 3, 8))
        XCTAssertEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .amTag, n: 0), datum: "2026-10-03", start: "07:00"), berlin(2026, 10, 3, 7))
    }

    func testFreigabeZeitStunden() {
        XCTAssertEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .stunden, n: 2), datum: "2026-10-03", start: "12:00"), berlin(2026, 10, 3, 10))
        XCTAssertEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .stunden, n: 6), datum: "2026-10-03", start: "19:30"), berlin(2026, 10, 3, 13, 30))
    }

    func testFreigabeZeitOhneStartGilt12UhrUndNieNachDemBeginn() {
        XCTAssertEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .tage, n: 1), datum: "2026-10-03", start: nil), berlin(2026, 10, 2, 12))
        XCTAssertEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .stunden, n: 1), datum: "2026-10-03", start: nil), berlin(2026, 10, 3, 11))
        let beginn = berlin(2026, 10, 3, 6)
        XCTAssertLessThanOrEqual(TreffenLogik.freigabeZeit(FreigabeWahl(art: .stunden, n: -5), datum: "2026-10-03", start: "06:00"), beginn)
    }

    // MARK: - freigabeText

    func testFreigabeText() {
        let ab = berlin(2026, 10, 3, 9)
        XCTAssertEqual(TreffenLogik.freigabeText(ab: ab, jetzt: berlin(2026, 10, 3, 7)), "heute 09:00")
        XCTAssertEqual(TreffenLogik.freigabeText(ab: ab, jetzt: berlin(2026, 10, 2, 22)), "morgen 09:00")
        XCTAssertEqual(TreffenLogik.freigabeText(ab: ab, jetzt: berlin(2026, 9, 30, 10)), "Sa. 3. Okt., 09:00")
    }

    // MARK: - faelligeFreigaben und naechsteFaelligkeit

    func testFaelligeFreigabenNurFaelligeUndEinmalJeId() {
        let jetzt = berlin(2026, 10, 2, 12)
        let faellig = geheim("a", ab: berlin(2026, 10, 2, 11))
        let spaeter = geheim("b", ab: berlin(2026, 10, 3, 9))
        let zweitesGeraet = faellig // doppelt
        let r = TreffenLogik.faelligeFreigaben(geheim: [faellig, spaeter, zweitesGeraet], oeffentlich: [], geloescht: [], jetzt: jetzt)
        XCTAssertEqual(r.map(\.id), ["a"])
    }

    func testFaelligeFreigabenSchonFreigegebenUndGeloescht() {
        let jetzt = berlin(2026, 10, 2, 12)
        let ab = berlin(2026, 10, 2, 11)
        let schonOeffentlich = punkt("a", titel: "Geheim X")
        XCTAssertTrue(TreffenLogik.faelligeFreigaben(geheim: [geheim("a", ab: ab)], oeffentlich: [schonOeffentlich], geloescht: [], jetzt: jetzt).isEmpty)
        XCTAssertTrue(TreffenLogik.faelligeFreigaben(geheim: [geheim("b", ab: ab)], oeffentlich: [], geloescht: ["b"], jetzt: jetzt).isEmpty)
        XCTAssertTrue(TreffenLogik.faelligeFreigaben(geheim: [geheim("c", ab: ab, geloescht: true)], oeffentlich: [], geloescht: [], jetzt: jetzt).isEmpty)
    }

    func testFaelligeFreigabenPlatzhalterAlleinGiltNichtAlsFreigegeben() {
        let jetzt = berlin(2026, 10, 2, 12)
        let platzhalter = punkt("a", titel: nil, versteckt: true, ab: berlin(2026, 10, 2, 11))
        let r = TreffenLogik.faelligeFreigaben(geheim: [geheim("a", ab: berlin(2026, 10, 2, 11))], oeffentlich: [platzhalter], geloescht: [], jetzt: jetzt)
        XCTAssertEqual(r.map(\.id), ["a"])
    }

    func testNaechsteFaelligkeit() {
        let jetzt = berlin(2026, 10, 2, 12)
        let g = [geheim("a", ab: berlin(2026, 10, 5, 9)), geheim("b", ab: berlin(2026, 10, 3, 9)), geheim("c", ab: berlin(2026, 10, 1, 9))]
        XCTAssertEqual(TreffenLogik.naechsteFaelligkeit(geheim: g, oeffentlich: [], geloescht: [], jetzt: jetzt), berlin(2026, 10, 3, 9))
        XCTAssertNil(TreffenLogik.naechsteFaelligkeit(geheim: g, oeffentlich: [], geloescht: ["a", "b", "c"], jetzt: jetzt))
        XCTAssertNil(TreffenLogik.naechsteFaelligkeit(geheim: [], oeffentlich: [], geloescht: [], jetzt: jetzt))
    }

    // MARK: - zusammengefuehrt

    func testZusammengefuehrtFuelltNurEigenePlatzhalterUndBleibtVersteckt() {
        let ab = berlin(2026, 10, 3, 9)
        let eigener = punkt("a", titel: nil, von: .ahmed, versteckt: true, ab: ab)
        let fremder = punkt("b", titel: nil, von: .annika, versteckt: true, ab: ab)
        let offen = punkt("c", titel: "Kino", von: .annika)
        let g = ["a": geheim("a", ab: ab), "b": geheim("b", ab: ab), "c": geheim("c", ab: ab, titel: "Anderes")]
        let r = TreffenLogik.zusammengefuehrt(oeffentlich: [eigener, fremder, offen], geheim: g, ich: .ahmed)
        XCTAssertEqual(r[0].titel, "Geheim X")
        XCTAssertTrue(r[0].versteckt)
        XCTAssertNil(r[1].titel, "Platzhalter des Partners bleibt leer")
        XCTAssertEqual(r[2].titel, "Kino", "öffentlicher Inhalt bleibt")
    }

    func testZusammengefuehrtGeloeschteBleibtLeer() {
        let ab = berlin(2026, 10, 3, 9)
        let eigener = punkt("a", titel: nil, von: .ahmed, versteckt: true, ab: ab)
        let r = TreffenLogik.zusammengefuehrt(oeffentlich: [eigener], geheim: ["a": geheim("a", ab: ab, geloescht: true)], ich: .ahmed)
        XCTAssertNil(r[0].titel)
    }

    // MARK: - Faltung

    func testSetzenAlleine() {
        let z = KalenderModell.anwenden([op("treffen.punkt.setzen", setzenD("p1"))])
        let p = z.punkte["2026-10-03"]?.first
        XCTAssertEqual(p?.titel, "Kino")
        XCTAssertEqual(p?.start, "19:00")
        XCTAssertEqual(p?.von, .ahmed)
        XCTAssertEqual(p?.versteckt, false)
    }

    func testPlatzhalterAlleine() {
        let z = KalenderModell.anwenden([op("treffen.punkt.platzhalter", platzhalterD("p1"))])
        let p = z.punkte["2026-10-03"]?.first
        XCTAssertNil(p?.titel)
        XCTAssertEqual(p?.hatInhalt, false)
        XCTAssertEqual(p?.versteckt, true)
        XCTAssertEqual(p?.sichtbarAb, TreffenZeit.datum("2026-10-03T07:00:00Z"))
    }

    func testLoeschenEntferntUndSetztGrabstein() {
        let z = KalenderModell.anwenden([
            op("treffen.punkt.setzen", setzenD("p1")),
            op("treffen.punkt.loeschen", PunktLoeschenD(datum: "2026-10-03", id: "p1")),
        ])
        XCTAssertEqual(z.punkte["2026-10-03"]?.count ?? 0, 0)
        XCTAssertTrue(z.geloeschtePunkte.contains("p1"))
    }

    func testDoppelteZustellungIstHarmlos() {
        let o = op("treffen.punkt.setzen", setzenD("p1"), seq: 1)
        let z = live([[o], [o]])
        XCTAssertEqual(z.punkte["2026-10-03"]?.count, 1)
        let alt = KalenderModell.anwenden([o, o])
        XCTAssertEqual(alt.punkte["2026-10-03"]?.count, 1)
    }

    func testSetzenSchlaegtPlatzhalterInJederReihenfolge() {
        let platz = op("treffen.punkt.platzhalter", platzhalterD("p1"), seq: 1)
        let voll = op("treffen.punkt.setzen", setzenD("p1"), seq: 2)
        for ops in [[platz, voll], [voll, platz]] {
            let z = KalenderModell.anwenden(ops)
            XCTAssertEqual(z.punkte["2026-10-03"]?.count, 1)
            XCTAssertEqual(z.punkte["2026-10-03"]?.first?.titel, "Kino")
            XCTAssertEqual(z.punkte["2026-10-03"]?.first?.versteckt, false)
        }
        // Live: erst die Freigabe (seq 2), dann der späte Platzhalter (seq 1).
        let z = live([[voll], [platz]])
        XCTAssertEqual(z.punkte["2026-10-03"]?.first?.titel, "Kino")
        XCTAssertEqual(z.punkte["2026-10-03"]?.first?.versteckt, false)
    }

    func testPlatzhalterNachAendernDerZeitErsetztAltenPlatzhalter() {
        let eins = op("treffen.punkt.platzhalter", platzhalterD("p1"), seq: 1)
        var neu = platzhalterD("p1")
        neu.start = "20:00"
        let zwei = op("treffen.punkt.platzhalter", neu, seq: 2)
        let z = KalenderModell.anwenden([eins, zwei])
        XCTAssertEqual(z.punkte["2026-10-03"]?.count, 1)
        XCTAssertEqual(z.punkte["2026-10-03"]?.first?.start, "20:00")
    }

    func testGrabsteinLaesstSpaeteOpsNichtWiederAuferstehen() {
        let weg = op("treffen.punkt.loeschen", PunktLoeschenD(datum: "2026-10-03", id: "p1"), seq: 3)
        let setzen = op("treffen.punkt.setzen", setzenD("p1"), seq: 1)
        let platz = op("treffen.punkt.platzhalter", platzhalterD("p1"), seq: 2)
        for ops in [[setzen, platz, weg], [weg, setzen, platz], [weg, platz, setzen]] {
            let z = KalenderModell.anwenden(ops)
            XCTAssertEqual(z.punkte["2026-10-03"]?.count ?? 0, 0)
        }
    }

    func testDatumsAenderungVerschiebtDenPunkt() {
        let z = KalenderModell.anwenden([
            op("treffen.punkt.setzen", setzenD("p1", datum: "2026-10-03")),
            op("treffen.punkt.setzen", setzenD("p1", datum: "2026-10-04")),
        ])
        XCTAssertEqual(z.punkte["2026-10-03"]?.count ?? 0, 0)
        XCTAssertEqual(z.punkte["2026-10-04"]?.count, 1)
    }

    // MARK: - treffen.setzen mit bis

    func testBuild92OhneBisLoeschtBisNicht() {
        let neu = op("treffen.setzen", TreffenD(datum: "2026-10-03", uhrzeit: "19:00", wasMachenWir: "Essen", bis: "22:30"), seq: 1)
        let alt = op("treffen.setzen", TreffenD(datum: "2026-10-03", uhrzeit: "19:30", wasMachenWir: "Essen gehen"), von: .annika, seq: 2)
        let z = KalenderModell.anwenden([neu, alt])
        XCTAssertEqual(z.treffenText["2026-10-03"]?.bis, "22:30")
        XCTAssertEqual(z.daten.treffen.first?.bis, "22:30")
        XCTAssertEqual(z.daten.treffen.first?.uhrzeit, "19:30")
    }

    func testLeeresBisNimmtBisZurueck() {
        let neu = op("treffen.setzen", TreffenD(datum: "2026-10-03", uhrzeit: "19:00", wasMachenWir: "Essen", bis: "22:30"), seq: 1)
        let leer = op("treffen.setzen", TreffenD(datum: "2026-10-03", uhrzeit: nil, wasMachenWir: "Essen", bis: ""), seq: 2)
        let z = KalenderModell.anwenden([neu, leer])
        XCTAssertNil(z.treffenText["2026-10-03"]?.bis)
        XCTAssertNil(z.daten.treffen.first?.bis)
    }

    func testAltesTreffenNurUhrzeitGehtWieBisher() {
        let z = KalenderModell.anwenden([op("treffen.setzen", TreffenD(datum: "2026-10-03", uhrzeit: "19:00", wasMachenWir: "Kino"))])
        XCTAssertEqual(z.daten.treffen.first, Treffen(datum: "2026-10-03", uhrzeit: "19:00", wasMachenWir: "Kino", bis: nil))
    }

    // MARK: - Überraschung: nichts an den Partner

    private func ueberraschung(titel: String = "Geheim X", notiz: String = "Geheim Notiz", ort: String = "Geheim Ort") -> PunktEntwurf {
        PunktEntwurf(
            id: nil, datum: "2026-10-03", start: "12:00", ende: "14:00", titel: titel, notiz: notiz,
            ort: PunktOrt(name: ort, lat: 51.2, lon: 6.8, adresse: "Geheimweg 1"), ueberraschung: FreigabeWahl(art: .tage, n: 1)
        )
    }

    func testPlatzhalterOpEnthaeltKeinenInhalt() throws {
        let p = punkt("p1", start: "12:00", ende: "14:00", titel: "Geheim X", versteckt: true)
        let data = try JSONEncoder().encode(PlatzhalterD(aus: p, sichtbarAb: berlin(2026, 10, 2, 12)))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("Geheim X"))
        for schluessel in ["titel", "notiz", "ort", "adresse"] { XCTAssertFalse(text.contains("\"\(schluessel)\""), schluessel) }
        let objekt = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(objekt.keys), ["datum", "id", "start", "ende", "sichtbarAb"])
    }

    func testKeineOeffentlicheOpEinesVersteckenPunktsEnthaeltInhalt() throws {
        let jetzt = berlin(2026, 10, 1, 10)
        let sendungen = TreffenOps.speichern(ueberraschung(), id: "p1", jetzt: jetzt, schonOeffentlich: false)
        let fuerPartner = sendungen.filter(\.gehtAnPartner)
        XCTAssertEqual(fuerPartner.map(\.art), ["treffen.punkt.platzhalter"])
        XCTAssertEqual(sendungen.filter { !$0.gehtAnPartner }.map(\.art), ["entwurf.setzen"])
        for s in fuerPartner {
            let text = String(decoding: s.op(von: .ahmed).d, as: UTF8.self)
            for geheim in ["Geheim X", "Geheim Notiz", "Geheim Ort", "Geheimweg", "\"titel\"", "\"notiz\"", "\"ort\""] {
                XCTAssertFalse(text.contains(geheim), "\(s.art) enthält \(geheim)")
            }
        }
    }

    func testPartnerSichtVorDerFreigabeIstImmerVersteckt() throws {
        let jetzt = berlin(2026, 10, 1, 10)
        let sendungen = TreffenOps.speichern(ueberraschung(), id: "p1", jetzt: jetzt, schonOeffentlich: false)
        // Der Partner bekommt nur die öffentlichen Ops.
        let oeffentlich = sendungen.filter(\.gehtAnPartner).map { $0.op(von: .ahmed) }
        let z = KalenderModell.anwenden(oeffentlich)
        let p = try XCTUnwrap(z.punkte["2026-10-03"]?.first)
        XCTAssertFalse(p.hatInhalt)
        for zeit in [jetzt, berlin(2026, 10, 2, 11, 59), berlin(2026, 10, 3, 12), berlin(2026, 10, 9)] {
            guard case .versteckt = TreffenLogik.ansicht(p, ich: .annika, jetzt: zeit) else { return XCTFail("Partner sieht Inhalt um \(zeit)") }
        }
    }

    func testErstellerSiehtInhaltUeberDieEigeneOp() throws {
        let jetzt = berlin(2026, 10, 1, 10)
        let sendungen = TreffenOps.speichern(ueberraschung(), id: "p1", jetzt: jetzt, schonOeffentlich: false)
        let ops = sendungen.map { $0.op(von: .ahmed) }
        let z = KalenderModell.anwenden(ops.filter { $0.art != "entwurf.setzen" })
        var g: [String: GeheimPunkt] = [:]
        TreffenGeheimModell.falten(ops, ich: .ahmed, in: &g)
        let punkte = TreffenLogik.zusammengefuehrt(oeffentlich: z.punkte["2026-10-03"] ?? [], geheim: g, ich: .ahmed)
        let erster = try XCTUnwrap(punkte.first)
        XCTAssertEqual(erster.titel, "Geheim X")
        XCTAssertEqual(erster.notiz, "Geheim Notiz")
        XCTAssertEqual(erster.ort?.name, "Geheim Ort")
        XCTAssertTrue(erster.versteckt)
        XCTAssertEqual(TreffenLogik.ansicht(erster, ich: .ahmed, jetzt: jetzt), PunktAnsicht.voll)
        XCTAssertEqual(g["p1"]?.sichtbarAb, berlin(2026, 10, 2, 12))
    }

    func testFreigabeSendetVollenInhaltMitDerselbenId() {
        let jetzt = berlin(2026, 10, 1, 10)
        let sendungen = TreffenOps.speichern(ueberraschung(), id: "p1", jetzt: jetzt, schonOeffentlich: false)
        var g: [String: GeheimPunkt] = [:]
        TreffenGeheimModell.falten(sendungen.map { $0.op(von: .ahmed) }, ich: .ahmed, in: &g)
        let freigabe = TreffenOps.freigeben(g["p1"]!).op(von: .ahmed)
        XCTAssertEqual(freigabe.art, "treffen.punkt.setzen")
        // Platzhalter, dann Freigabe: beim Partner steht danach der Inhalt, öffentlich.
        let z = KalenderModell.anwenden(sendungen.filter(\.gehtAnPartner).map { $0.op(von: .ahmed) } + [freigabe])
        XCTAssertEqual(z.punkte["2026-10-03"]?.first?.titel, "Geheim X")
        XCTAssertEqual(z.punkte["2026-10-03"]?.first?.versteckt, false)
        XCTAssertEqual(z.punkte["2026-10-03"]?.count, 1)
    }

    func testSchonOeffentlichWirdNieWiederVersteckt() {
        let sendungen = TreffenOps.speichern(ueberraschung(), id: "p1", jetzt: berlin(2026, 10, 1, 10), schonOeffentlich: true)
        XCTAssertEqual(sendungen.map(\.art), ["treffen.punkt.setzen"])
    }

    func testFreigabeZeitSchonVorbeiSendetDirektOeffentlich() {
        let sendungen = TreffenOps.speichern(ueberraschung(), id: "p1", jetzt: berlin(2026, 10, 3, 0, 30), schonOeffentlich: false)
        XCTAssertEqual(sendungen.map(\.art), ["treffen.punkt.setzen"])
    }

    func testOhneUeberraschungNurOeffentlichUndEndeNieVorStart() throws {
        var p = ueberraschung()
        p.ueberraschung = nil
        p.start = "14:00"
        p.ende = "13:00"
        p.notiz = ""
        let sendungen = TreffenOps.speichern(p, id: "p1", jetzt: berlin(2026, 10, 1), schonOeffentlich: false)
        XCTAssertEqual(sendungen.map(\.art), ["treffen.punkt.setzen"])
        guard case .setzen(let d) = sendungen[0] else { return XCTFail("setzen erwartet") }
        XCTAssertEqual(d.ende, "14:00")
        XCTAssertNil(d.notiz)
    }

    func testLoeschenGehtAnBeideUndGrabsteinAnEigeneGeraete() {
        let g = geheim("p1", ab: berlin(2026, 10, 2, 12))
        let sendungen = TreffenOps.loeschen(datum: "2026-10-03", id: "p1", geheim: g)
        XCTAssertEqual(sendungen.map(\.art), ["treffen.punkt.loeschen", "entwurf.setzen"])
        var map = ["p1": g]
        TreffenGeheimModell.falten([sendungen[1].op(von: .ahmed)], ich: .ahmed, in: &map)
        XCTAssertEqual(map["p1"]?.geloescht, true)
        XCTAssertEqual(TreffenOps.loeschen(datum: "2026-10-03", id: "p1", geheim: nil).map(\.art), ["treffen.punkt.loeschen"])
    }

    // MARK: - TreffenGeheimModell.falten

    func testGeheimFaltenNeuereFassungGewinntUndGrabsteinBleibt() {
        let ab = berlin(2026, 10, 2, 12)
        func geheimOp(_ titel: String, zeit: Date, geloescht: Bool = false) -> Op {
            var g = geheim("p1", ab: ab, titel: titel)
            g.geloescht = geloescht
            return op("entwurf.setzen", g.wire, zeit: zeit)
        }
        let alt = geheimOp("alt", zeit: Date(timeIntervalSince1970: 1_000))
        let neu = geheimOp("neu", zeit: Date(timeIntervalSince1970: 2_000))
        var map: [String: GeheimPunkt] = [:]
        TreffenGeheimModell.falten([neu, alt, neu], ich: .ahmed, in: &map)
        XCTAssertEqual(map["p1"]?.titel, "neu")
        let weg = geheimOp("neu", zeit: Date(timeIntervalSince1970: 3_000), geloescht: true)
        TreffenGeheimModell.falten([weg], ich: .ahmed, in: &map)
        XCTAssertEqual(map["p1"]?.geloescht, true)
        TreffenGeheimModell.falten([geheimOp("neuer", zeit: Date(timeIntervalSince1970: 4_000))], ich: .ahmed, in: &map)
        XCTAssertEqual(map["p1"]?.geloescht, true, "Löschen bleibt gelöscht")
    }

    func testGeheimFaltenIgnoriertFremdeOpsUndChatEntwuerfe() {
        var map: [String: GeheimPunkt] = [:]
        let fremd = op("entwurf.setzen", geheim("p1", ab: berlin(2026, 10, 2, 12)).wire, von: .annika)
        let chat = op("entwurf.setzen", ["text": "Hallo"])
        TreffenGeheimModell.falten([fremd, chat], ich: .ahmed, in: &map)
        XCTAssertTrue(map.isEmpty)
    }
}

/// Der Chat-Entwurf darf durch die neue Nutzlast nicht geleert werden.
@MainActor
final class TreffenChatEntwurfTests: XCTestCase {
    func testTreffenGeheimLeertDenChatEntwurfNicht() {
        let modell = ChatModell(registrieren: false)
        let text = Op.neu("entwurf.setzen", ["text": "Hallo Annika"], von: .ahmed)
        modell.anwenden([Op(id: text.id, seq: 1, art: text.art, von: .ahmed, zeit: text.zeit, d: text.d)])
        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "Hallo Annika")

        let g = GeheimPunkt(
            id: "p1", datum: "2026-10-03", start: nil, ende: nil, titel: "Geheim X", notiz: nil, ort: nil,
            sichtbarAb: Date(timeIntervalSince1970: 2_000_000_000), freigabe: FreigabeWahl(art: .tage, n: 1), geloescht: false, zeit: Date()
        )
        let neu = Op.neu("entwurf.setzen", g.wire, von: .ahmed)
        modell.anwenden([Op(id: neu.id, seq: 2, art: neu.art, von: .ahmed, zeit: neu.zeit, d: neu.d)])
        XCTAssertEqual(modell.entwurf(fuer: .ahmed).text, "Hallo Annika")
    }
}
