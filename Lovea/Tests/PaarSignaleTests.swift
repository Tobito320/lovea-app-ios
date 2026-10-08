import XCTest
@testable import Lovea

/// p60: Stimmung, Geschenkbox, Gute-Nacht-Zeitfenster, Lampenpause und der Liebesbrief als Brief.
@MainActor
final class PaarSignaleTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_791_500_000)

    private final class Ziel { var ops: [Op] = [] }

    private func op<T: Encodable>(_ art: String, _ d: T, von: Person, id: String, zeit: Date) -> Op {
        Op(id: id, seq: nil, art: art, von: von, zeit: zeit, d: Op.neu(art, d, von: von).d)
    }

    private func stimmung(_ art: String?, von: Person = .ahmed, id: String, nach s: TimeInterval = 0) -> Op {
        op(SignaleLogik.artStimmung, SignaleLogik.StimmungD(art: art), von: von, id: id, zeit: t0.addingTimeInterval(s))
    }

    private func geschenk(_ id: String, _ text: String, erledigt: Bool? = nil, von: Person = .ahmed, opId: String, nach s: TimeInterval = 0) -> Op {
        op(SignaleLogik.artGeschenk, SignaleLogik.GeschenkD(id: id, text: text, erledigt: erledigt), von: von, id: opId, zeit: t0.addingTimeInterval(s))
    }

    // MARK: - Stimmung

    func testStimmungenSindDieSechsVomDraht() {
        XCTAssertEqual(Stimmung.allCases.map(\.rawValue), ["muede", "verliebt", "gestresst", "gluecklich", "krank", "vermisse"])
        XCTAssertEqual(Set(Stimmung.allCases.map(\.name)).count, 6)
        XCTAssertEqual(SignaleLogik.arten, ["stimmung.setzen", "geschenkbox.setzen", "geschenkbox.loeschen"])
    }

    func testNeuesteStimmungGewinntReihenfolgeEgalUndIdempotent() {
        let a = stimmung("muede", id: "o1")
        let b = stimmung("verliebt", id: "o2", nach: 60)
        let stand = SignaleLogik.anwenden([b, a, b, a])
        XCTAssertEqual(SignaleLogik.stimmung(stand, von: .ahmed, jetzt: t0.addingTimeInterval(120)), .verliebt)
        XCTAssertNil(SignaleLogik.stimmung(stand, von: .annika, jetzt: t0.addingTimeInterval(120)), "jede Person hat ihre eigene")
        XCTAssertEqual(stand, SignaleLogik.anwenden([a, b]))
    }

    func testGleicheZeitEntscheidetDieOpId() {
        let a = stimmung("muede", id: "a")
        let b = stimmung("krank", id: "b")
        XCTAssertEqual(SignaleLogik.stimmung(SignaleLogik.anwenden([a, b]), von: .ahmed, jetzt: t0), .krank)
        XCTAssertEqual(SignaleLogik.stimmung(SignaleLogik.anwenden([b, a]), von: .ahmed, jetzt: t0), .krank)
    }

    func testLoeschenNimmtDieBlaseWegAelteresLoeschenNicht() {
        let setzen = stimmung("gluecklich", id: "o1", nach: 10)
        let weg = stimmung(nil, id: "o2", nach: 20)
        let altesWeg = stimmung(nil, id: "o0", nach: 5)
        let jetzt = t0.addingTimeInterval(30)
        XCTAssertNil(SignaleLogik.stimmung(SignaleLogik.anwenden([setzen, weg]), von: .ahmed, jetzt: jetzt))
        XCTAssertNil(SignaleLogik.stimmung(SignaleLogik.anwenden([weg, setzen]), von: .ahmed, jetzt: jetzt))
        XCTAssertEqual(SignaleLogik.stimmung(SignaleLogik.anwenden([altesWeg, setzen]), von: .ahmed, jetzt: jetzt), .gluecklich)
    }

    func testStimmungLaeuftNachEinemTagAb() {
        let stand = SignaleLogik.anwenden([stimmung("vermisse", id: "o1")])
        XCTAssertEqual(SignaleLogik.stimmung(stand, von: .ahmed, jetzt: t0.addingTimeInterval(24 * 3600 - 1)), .vermisse)
        XCTAssertNil(SignaleLogik.stimmung(stand, von: .ahmed, jetzt: t0.addingTimeInterval(24 * 3600)))
    }

    func testUnbekannteStimmungUndKaputteDatenWerdenIgnoriert() {
        let alt = stimmung("verliebt", id: "o1")
        let zukunft = stimmung("zukunft", id: "o2", nach: 10)
        let kaputt = Op(id: "o3", seq: nil, art: SignaleLogik.artStimmung, von: .ahmed, zeit: t0.addingTimeInterval(20), d: Data("[]".utf8))
        let stand = SignaleLogik.anwenden([alt, zukunft, kaputt])
        XCTAssertEqual(SignaleLogik.stimmung(stand, von: .ahmed, jetzt: t0.addingTimeInterval(30)), .verliebt)
    }

    func testLoeschenUeberDenDrahtBleibtEinEintragMitNilArt() throws {
        let setzen = stimmung("krank", id: "o1")
        let weg = stimmung(nil, id: "o2", nach: 5)
        let zurueck = try JSONDecoder().decode(Op.self, from: JSONEncoder().encode(weg))
        let stand = SignaleLogik.anwenden([setzen, zurueck])
        XCTAssertNotNil(stand.stimmung[.ahmed])
        XCTAssertNil(SignaleLogik.stimmung(stand, von: .ahmed, jetzt: t0.addingTimeInterval(10)))
    }

    // MARK: - Geschenkbox

    func testGeschenkeFaltenAbhakenUndLoeschenMitGrabstein() {
        let ring = geschenk("g1", "Ring", opId: "o1")
        let buch = geschenk("g2", "Buch", erledigt: false, opId: "o2", nach: 10)
        let haken = geschenk("g1", "Ring", erledigt: true, opId: "o3", nach: 20)
        var stand = SignaleLogik.anwenden([buch, haken, ring, ring])
        XCTAssertEqual(SignaleLogik.geschenke(stand, von: .ahmed).map(\.text), ["Buch", "Ring"], "offene zuerst, erledigte danach")
        XCTAssertEqual(SignaleLogik.geschenke(stand, von: .ahmed).map(\.erledigt), [false, true])

        let weg = op(SignaleLogik.artGeschenkWeg, SignaleLogik.GeschenkWegD(id: "g1"), von: .ahmed, id: "o4", zeit: t0.addingTimeInterval(30))
        stand = SignaleLogik.anwenden([weg], auf: stand)
        XCTAssertEqual(SignaleLogik.geschenke(stand, von: .ahmed).map(\.id), ["g2"])
        stand = SignaleLogik.anwenden([ring, haken], auf: stand)
        XCTAssertEqual(SignaleLogik.geschenke(stand, von: .ahmed).map(\.id), ["g2"], "eine spät eintreffende ältere Op holt nichts zurück")
        XCTAssertEqual(SignaleLogik.anwenden([weg, ring, haken, buch]), stand, "Löschen zuerst, gleiches Ergebnis")
    }

    func testGeschenkeSindNurInDerBoxDesAbsenders() {
        let meins = geschenk("g1", "Ring", opId: "o1")
        let ihres = geschenk("g2", "Buch", von: .annika, opId: "o2", nach: 5)
        let stand = SignaleLogik.anwenden([meins, ihres])
        XCTAssertEqual(SignaleLogik.geschenke(stand, von: .ahmed).map(\.text), ["Ring"])
        XCTAssertEqual(SignaleLogik.geschenke(stand, von: .annika).map(\.text), ["Buch"])
    }

    func testKurzSchneidetRandAbUndLehntLeeresAb() {
        XCTAssertEqual(SignaleLogik.kurz("  Ring \n", hoechstens: 140), "Ring")
        XCTAssertNil(SignaleLogik.kurz(" \n ", hoechstens: 5))
        XCTAssertEqual(SignaleLogik.kurz("abcdefgh", hoechstens: 3), "abc")
    }

    // MARK: - Speicher

    func testSpeicherStimmungSendetEineOpUndFaltetSofort() {
        let ziel = Ziel()
        let s = SignaleSpeicher(ich: { .ahmed }, senden: { ziel.ops.append($0) })
        XCTAssertNil(s.stimmung(von: .ahmed))
        s.stimmungSetzen(.verliebt)
        XCTAssertEqual(s.stimmung(von: .ahmed), .verliebt)
        XCTAssertEqual(ziel.ops.map(\.art), [SignaleLogik.artStimmung])
        XCTAssertEqual(ziel.ops.first?.von, .ahmed)
        s.stimmungSetzen(nil)
        XCTAssertNil(s.stimmung(von: .ahmed))
        XCTAssertEqual(ziel.ops.count, 2)
    }

    func testSpeicherNimmtDieStimmungDerAnderenPersonAnUndOhneIchPassiertNichts() {
        let ziel = Ziel()
        let s = SignaleSpeicher(ich: { nil }, senden: { ziel.ops.append($0) })
        s.stimmungSetzen(.krank)
        XCTAssertFalse(s.geschenkMerken("Ring"))
        XCTAssertTrue(ziel.ops.isEmpty)
        XCTAssertTrue(s.geschenke.isEmpty)

        s.einarbeiten([op(SignaleLogik.artStimmung, SignaleLogik.StimmungD(art: "muede"), von: .annika, id: "o1", zeit: Date())])
        XCTAssertEqual(s.stimmung(von: .annika), .muede)
    }

    func testSpeicherGeschenkMerkenAbhakenLoeschen() throws {
        let ziel = Ziel()
        let s = SignaleSpeicher(ich: { .ahmed }, senden: { ziel.ops.append($0) })
        XCTAssertFalse(s.geschenkMerken("   "), "leer wird nicht gemerkt")
        XCTAssertTrue(s.geschenkMerken(" Ring "))
        XCTAssertEqual(s.geschenke.map(\.text), ["Ring"])
        let g = try XCTUnwrap(s.geschenke.first)
        s.geschenkAbhaken(g)
        let abgehakt = try XCTUnwrap(s.geschenke.first)
        XCTAssertTrue(abgehakt.erledigt)
        s.geschenkAbhaken(abgehakt)
        XCTAssertFalse(try XCTUnwrap(s.geschenke.first).erledigt, "zweites Antippen nimmt den Haken weg")
        s.geschenkLoeschen(g)
        XCTAssertTrue(s.geschenke.isEmpty)
        XCTAssertEqual(ziel.ops.map(\.art), [SignaleLogik.artGeschenk, SignaleLogik.artGeschenk, SignaleLogik.artGeschenk, SignaleLogik.artGeschenkWeg])
    }

    func testSpeicherFasstFremdeGeschenkeNichtAn() {
        let ziel = Ziel()
        let s = SignaleSpeicher(ich: { .ahmed }, senden: { ziel.ops.append($0) })
        let fremd = Geschenk(id: "x", text: "t", erledigt: false, von: .annika, zeit: t0, opId: "o")
        s.geschenkAbhaken(fremd)
        s.geschenkLoeschen(fremd)
        XCTAssertTrue(ziel.ops.isEmpty)
        s.einarbeiten([geschenk("g9", "Buch", von: .annika, opId: "o9")])
        XCTAssertTrue(s.geschenke.isEmpty, "selbst wenn eines ankäme, zeigt die Box nur meine")
    }

    func testGeschenkTextWirdAufDieHoechstlaengeGekuerzt() throws {
        let s = SignaleSpeicher(ich: { .ahmed }, senden: { _ in })
        XCTAssertTrue(s.geschenkMerken(String(repeating: "a", count: SignaleLogik.geschenkMaxZeichen + 50)))
        XCTAssertEqual(try XCTUnwrap(s.geschenke.first).text.count, SignaleLogik.geschenkMaxZeichen)
    }

    // MARK: - Lampe

    func testLampeHatZehnSekundenPause() {
        XCTAssertTrue(SignaleLogik.lampeFrei(zuletzt: nil, jetzt: t0))
        XCTAssertFalse(SignaleLogik.lampeFrei(zuletzt: t0, jetzt: t0.addingTimeInterval(9.9)))
        XCTAssertTrue(SignaleLogik.lampeFrei(zuletzt: t0, jetzt: t0.addingTimeInterval(10)))
    }

    // MARK: - Gute Nacht

    private func berlin(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde, minute: minute))!
    }

    private func gruss(_ nacht: Date?, _ morgen: Date? = nil) -> (nacht: Date?, morgen: Date?) { (nacht, morgen) }

    func testNachtBeginntUmAchtzehnUhr() {
        XCTAssertEqual(NachtLogik.nachtBeginn(jetzt: berlin(9, 22)), berlin(9, 18))
        XCTAssertEqual(NachtLogik.nachtBeginn(jetzt: berlin(10, 2)), berlin(9, 18), "nach Mitternacht gehört zur Nacht davor")
        XCTAssertEqual(NachtLogik.nachtBeginn(jetzt: berlin(10, 12)), berlin(9, 18))
    }

    func testGedruecktGiltBisElfUhrAmMorgen() {
        let g: NachtLogik.Gruesse = [.ahmed: gruss(berlin(9, 22))]
        XCTAssertTrue(NachtLogik.gedrueckt(.ahmed, g, jetzt: berlin(9, 23)))
        XCTAssertTrue(NachtLogik.gedrueckt(.ahmed, g, jetzt: berlin(10, 2)))
        XCTAssertTrue(NachtLogik.gedrueckt(.ahmed, g, jetzt: berlin(10, 10, 59)))
        XCTAssertFalse(NachtLogik.gedrueckt(.ahmed, g, jetzt: berlin(10, 11, 1)))
        XCTAssertFalse(NachtLogik.gedrueckt(.annika, g, jetzt: berlin(9, 23)), "nur wer gedrückt hat")
    }

    func testGestrigerGrussZaehltNichtFuerHeuteNacht() {
        let g: NachtLogik.Gruesse = [.ahmed: gruss(berlin(8, 22))]
        XCTAssertFalse(NachtLogik.gedrueckt(.ahmed, g, jetzt: berlin(9, 23)))
        XCTAssertFalse(NachtLogik.gedrueckt(.ahmed, [:], jetzt: berlin(9, 23)))
    }

    func testLichtGehtErstAusWennBeideGedruecktHaben() {
        let einer: NachtLogik.Gruesse = [.ahmed: gruss(berlin(9, 22))]
        let beide: NachtLogik.Gruesse = [.ahmed: gruss(berlin(9, 22)), .annika: gruss(berlin(9, 23))]
        XCTAssertFalse(NachtLogik.gemeinsamDunkel(einer, jetzt: berlin(9, 23, 30)))
        XCTAssertTrue(NachtLogik.gemeinsamDunkel(beide, jetzt: berlin(9, 23, 30)))
        XCTAssertTrue(NachtLogik.gemeinsamDunkel(beide, jetzt: berlin(10, 3)))
    }

    func testGutenMorgenNachDerNachtMachtWiederHellAlterMorgenNicht() {
        let alterMorgen: NachtLogik.Gruesse = [.ahmed: gruss(berlin(9, 22), berlin(9, 7)), .annika: gruss(berlin(9, 23))]
        XCTAssertTrue(NachtLogik.gemeinsamDunkel(alterMorgen, jetzt: berlin(10, 1)))
        let neuerMorgen: NachtLogik.Gruesse = [.ahmed: gruss(berlin(9, 22)), .annika: gruss(berlin(9, 23), berlin(10, 7))]
        XCTAssertFalse(NachtLogik.gemeinsamDunkel(neuerMorgen, jetzt: berlin(10, 8)))
    }

    func testSchalterIstVonZwanzigBisVierUhrDa() {
        XCTAssertFalse(NachtLogik.schalterSichtbar([:], jetzt: berlin(9, 12)))
        XCTAssertFalse(NachtLogik.schalterSichtbar([:], jetzt: berlin(9, 19, 59)))
        XCTAssertTrue(NachtLogik.schalterSichtbar([:], jetzt: berlin(9, 20)))
        XCTAssertTrue(NachtLogik.schalterSichtbar([:], jetzt: berlin(10, 3, 59)))
        XCTAssertFalse(NachtLogik.schalterSichtbar([:], jetzt: berlin(10, 4)))
    }

    func testSchalterBleibtNachVierUhrSichtbarWennJemandGedruecktHat() {
        let g: NachtLogik.Gruesse = [.annika: gruss(berlin(9, 22))]
        XCTAssertTrue(NachtLogik.schalterSichtbar(g, jetzt: berlin(10, 5)))
        XCTAssertFalse(NachtLogik.schalterSichtbar(g, jetzt: berlin(10, 11, 30)))
    }

    // MARK: - Liebesbrief

    func testLiebesbriefIstEinBriefMitEigenemTitelUndLiegtImStapel() throws {
        let ziel = Ziel()
        var ich = Person.ahmed
        let b = BriefeSpeicher(ich: { ich }, senden: { ziel.ops.append($0) })
        XCTAssertNil(b.schreiben(titel: SignaleLogik.liebesbriefTitel, text: "  ", frei: true), "ohne Text kein Brief")
        XCTAssertNil(b.schreiben(titel: "  ", text: "x", frei: true), "ohne Titel kein Brief")
        let brief = try XCTUnwrap(b.schreiben(titel: SignaleLogik.liebesbriefTitel, text: " Ich denk an dich ", frei: true))
        XCTAssertEqual(brief.titel, "Ein Liebesbrief")
        XCTAssertEqual(brief.text, "Ich denk an dich")
        XCTAssertEqual(ziel.ops.map(\.art), [BriefeLogik.artNeu])

        ich = .annika
        XCTAssertEqual(b.ungeoeffnet, 1, "liegt als Umschlag auf ihrem Tisch")
        b.oeffnen(brief)
        XCTAssertEqual(b.ungeoeffnet, 0)
        XCTAssertEqual(b.erhalten.map(\.titel), ["Ein Liebesbrief"], "nach dem Öffnen im Briefstapel")
    }

    func testNormalerBriefBautWeiterOeffneWenn() throws {
        let b = BriefeSpeicher(ich: { .ahmed }, senden: { _ in })
        XCTAssertEqual(try XCTUnwrap(b.schreiben(titel: "du mich vermisst", text: "x")).titel, "Öffne, wenn du mich vermisst")
    }
}
