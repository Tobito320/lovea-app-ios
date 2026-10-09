import XCTest
@testable import Lovea

final class MuskelnTests: XCTestCase {
    private func u(_ name: String, _ muskel: String, _ neben: [String] = [], koerper: String = "", en: String? = nil) -> Uebung {
        Uebung(id: name, name: name, en: en ?? name, muskel: muskel, koerper: koerper, geraet: "", neben: neben)
    }

    private func satz() -> PlanSatz { PlanSatz(wdh: 10, kg: nil, failure: false) }

    /// One finished exercise with `n` sets in a session that starts at `start`.
    private func session(_ id: String, start: Date, ende: Date? = nil, uebung: String = "x", saetze n: Int = 3) -> GymSession {
        let lauf = UebungsLauf(plan: "p", uebung: uebung, start: nil, ende: start, fertig: true, saetze: Array(repeating: satz(), count: n))
        return GymSession(id: id, tag: nil, start: start, ende: ende, laeufe: [lauf])
    }

    private func katalog(_ liste: Uebung...) -> (String) -> Uebung? {
        let nachId = Dictionary(uniqueKeysWithValues: liste.map { ($0.id, $0) })
        return { nachId[$0] }
    }

    private func op(_ art: String, _ d: some Encodable, zeit: Date, von: Person) -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: zeit, d: try! JSONEncoder().encode(d))
    }

    // MARK: - Zuordnung

    func testSeitheben() {
        XCTAssertEqual(MuskelLogik.teile(u("Seitheben Kurzhantel", "Schultern")).first?.teil, .sSeitlich)
    }

    func testReverseSeithebenIstHintereSchulter() {
        XCTAssertEqual(MuskelLogik.teile(u("Reverse Seitheben mit Kurzhanteln", "Schultern")).first?.teil, .sHinten)
    }

    func testNackendruckenBleibtSchulter() {
        let t = MuskelLogik.teile(u("Nackendrücken stehend", "Schultern", ["Trizeps", "oberer Rücken"]))
        XCTAssertEqual(t.first?.teil, .sVorne)
        XCTAssertEqual(t.first?.teil.gruppe, .schulter)
    }

    func testNebenZaehltHalb() {
        let t = MuskelLogik.teile(u("Bankdrücken", "Brust", ["Trizeps"]))
        XCTAssertEqual(t.first { $0.teil == .bUnten }?.faktor, 1)
        XCTAssertEqual(t.first { $0.teil == .triSeitlich }?.faktor, 0.5)
    }

    func testDirektSchlaegtNeben() {
        let t = MuskelLogik.teile(u("Curl", "Bizeps", ["Oberarmmuskel", "Unterarme"]))
        XCTAssertEqual(t.filter { $0.teil == .biLang }.map(\.faktor), [1])
        XCTAssertEqual(t.first { $0.teil == .uBeuger }?.faktor, 0.5)
    }

    func testSchluesselwoerter() {
        XCTAssertEqual(MuskelLogik.teile(u("Preacher Curls am Kabelzug", "Bizeps")).first?.teil, .biKurz)
        XCTAssertEqual(MuskelLogik.teile(u("Trizepsdrücken über Kopf am Kabelzug", "Trizeps")).first?.teil, .triLang)
        XCTAssertEqual(MuskelLogik.teile(u("Schrägbankdrücken", "Brust")).first?.teil, .bOben)
        XCTAssertEqual(MuskelLogik.teile(u("Handgelenkstrecken mit Langhantel", "Unterarme")).first?.teil, .uStrecker)
        XCTAssertEqual(MuskelLogik.teile(u("Rudern am Kabel", "Trapez")).first?.teil, .rTrapezUnten)
        XCTAssertEqual(MuskelLogik.teile(u("Schulterheben", "Trapez")).first?.teil, .rTrapezOben)
    }

    func testCardioGibtNichts() {
        XCTAssertTrue(MuskelLogik.teile(u("Laufband", "Herz-Kreislauf")).isEmpty)
        XCTAssertTrue(MuskelLogik.teile(u("Laufband", "Herz-Kreislauf", ["Waden"], koerper: "Cardio")).isEmpty)
    }

    func testEigeneUebungGibtNichts() {
        XCTAssertTrue(MuskelLogik.teile(u("eigen", "")).isEmpty)
        let s = session("s", start: Datum.datum("2026-09-23"), uebung: PlanUebung.eigen)
        XCTAssertTrue(MuskelLogik.wochenSaetze([s], woche: "2026-09-23").isEmpty)
        XCTAssertTrue(MuskelLogik.erholung([s], jetzt: Datum.datum("2026-09-24")).isEmpty)
    }

    func testJederTeilHatGruppeUndName() {
        for t in MuskelTeil.allCases { XCTAssertFalse(t.name.isEmpty) }
        XCTAssertEqual(MuskelTeil.beWaden.gruppe, .beine)
        XCTAssertEqual(Set(MuskelTeil.allCases.map(\.gruppe)), Set(MuskelGruppe.allCases))
    }

    // MARK: - Woche

    func testWochenSaetzeZaehlenNebenHalb() {
        let bank = u("Bankdrücken", "Brust", ["Trizeps"])
        let s = session("s", start: Datum.datum("2026-09-23"), uebung: bank.id, saetze: 4)
        let w = MuskelLogik.wochenSaetze([s], woche: "2026-09-25", katalog: katalog(bank))
        XCTAssertEqual(w[.bUnten], 4)
        XCTAssertEqual(w[.triSeitlich], 2)
    }

    func testSonntagNachtGehoertZurAltenWoche() {
        let bank = u("Bankdrücken", "Brust")
        let sonntag = Datum.datum("2026-09-27").addingTimeInterval(23 * 3600 + 59 * 60)
        let s = session("s", start: sonntag, uebung: bank.id)
        XCTAssertEqual(MuskelLogik.wochenSaetze([s], woche: "2026-09-21", katalog: katalog(bank))[.bUnten], 3)
        XCTAssertTrue(MuskelLogik.wochenSaetze([s], woche: "2026-09-28", katalog: katalog(bank)).isEmpty)
    }

    func testMontagNullUhrGehoertZurNeuenWoche() {
        let bank = u("Bankdrücken", "Brust")
        let s = session("s", start: Datum.datum("2026-09-28"), uebung: bank.id)
        XCTAssertEqual(MuskelLogik.wochenSaetze([s], woche: "2026-09-30", katalog: katalog(bank))[.bUnten], 3)
        XCTAssertTrue(MuskelLogik.wochenSaetze([s], woche: "2026-09-27", katalog: katalog(bank)).isEmpty)
    }

    func testOffeneUndLeereLaeufeZaehlenNicht() {
        let bank = u("Bankdrücken", "Brust")
        var s = session("s", start: Datum.datum("2026-09-23"), uebung: bank.id)
        s.laeufe[0].fertig = false
        s.laeufe.append(UebungsLauf(plan: "q", uebung: bank.id, start: nil, ende: nil, fertig: true, saetze: nil))
        XCTAssertTrue(MuskelLogik.wochenSaetze([s], woche: "2026-09-23", katalog: katalog(bank)).isEmpty)
    }

    func testWochenSaetzeFiltertNachPerson() {
        let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)
        var f = TrainingFaltung()
        for (person, sitzung) in [(Person.ahmed, "a"), (Person.annika, "b")] {
            f.anwenden(op("gym.checkin", GymD(session: sitzung, start: t0), zeit: t0, von: person))
            f.anwenden(op("gym.uebung", GymD(session: sitzung, plan: "p", uebung: "x", status: "fertig", saetze: [satz(), satz()]), zeit: t0 + 600, von: person))
        }
        f.anwenden(op("gym.checkin", GymD(session: "c", start: t0 + 3600), zeit: t0 + 3600, von: .ahmed))
        f.anwenden(op("gym.uebung", GymD(session: "c", plan: "p", uebung: "x", status: "fertig", saetze: [satz()]), zeit: t0 + 4000, von: .ahmed))
        let bank = u("x", "Brust")
        XCTAssertEqual(MuskelLogik.wochenSaetze(f, person: .ahmed, woche: "2026-09-23", katalog: katalog(bank))[.bUnten], 3)
        XCTAssertEqual(MuskelLogik.wochenSaetze(f, person: .annika, woche: "2026-09-23", katalog: katalog(bank))[.bUnten], 2)
    }

    // MARK: - Erholung

    func testErholungWaechstMitDerZeit() {
        let squat = u("Kniebeuge", "Quadrizeps")
        let ende = Datum.datum("2026-09-23")
        let s = session("s", start: ende.addingTimeInterval(-3600), ende: ende, uebung: squat.id, saetze: 3)
        let k = katalog(squat)
        XCTAssertEqual(MuskelLogik.erholung([s], jetzt: ende, katalog: k)[.beQuads], 0)
        XCTAssertEqual(MuskelLogik.erholung([s], jetzt: ende.addingTimeInterval(30 * 3600), katalog: k)[.beQuads], 50)
        XCTAssertEqual(MuskelLogik.erholung([s], jetzt: ende.addingTimeInterval(200 * 3600), katalog: k)[.beQuads], 100)
    }

    func testMehrSaetzeBrauchenLaenger() {
        let curl = u("Curl", "Bizeps")
        let ende = Datum.datum("2026-09-23")
        let k = katalog(curl)
        let drei = session("a", start: ende, ende: ende, uebung: curl.id, saetze: 3)
        let acht = session("b", start: ende, ende: ende, uebung: curl.id, saetze: 8)
        let jetzt = ende.addingTimeInterval(30 * 3600)
        XCTAssertEqual(MuskelLogik.erholung([drei], jetzt: jetzt, katalog: k)[.biLang], 100)
        XCTAssertEqual(MuskelLogik.erholung([acht], jetzt: jetzt, katalog: k)[.biLang], 71) // 30 / (30 * 1.4)
    }

    func testLetzteSessionZaehlt() {
        let squat = u("Kniebeuge", "Quadrizeps")
        let alt = session("alt", start: Datum.datum("2026-09-20"), uebung: squat.id, saetze: 10)
        let neu = session("neu", start: Datum.datum("2026-09-23"), uebung: squat.id, saetze: 3)
        let jetzt = Datum.datum("2026-09-24")
        XCTAssertEqual(MuskelLogik.erholung([alt, neu], jetzt: jetzt, katalog: katalog(squat))[.beQuads], 40) // 24 h von 60 h
        XCTAssertEqual(MuskelLogik.erholung([neu, alt], jetzt: jetzt, katalog: katalog(squat))[.beQuads], 40)
    }

    func testZukunftIstNull() {
        let squat = u("Kniebeuge", "Quadrizeps")
        let s = session("s", start: Datum.datum("2026-09-25"), uebung: squat.id)
        XCTAssertEqual(MuskelLogik.erholung([s], jetzt: Datum.datum("2026-09-24"), katalog: katalog(squat))[.beQuads], 0)
    }

    func testStufen() {
        XCTAssertEqual(MuskelLogik.stufe(95), .erholt)
        XCTAssertEqual(MuskelLogik.stufe(90), .erholt)
        XCTAssertEqual(MuskelLogik.stufe(89), .fast)
        XCTAssertEqual(MuskelLogik.stufe(59), .fast)
        XCTAssertEqual(MuskelLogik.stufe(50), .fast)
        XCTAssertEqual(MuskelLogik.stufe(45), .muede)
    }

    func testLeereSessionsSindErholt() {
        XCTAssertEqual(MuskelLogik.erholung([], jetzt: Date())[.beQuads] ?? 100, 100)
        XCTAssertTrue(MuskelLogik.erholung([], jetzt: Date()).isEmpty)
        XCTAssertTrue(MuskelLogik.wochenSaetze([], woche: "2026-09-25").isEmpty)
    }

    func testStandardZiel() {
        XCTAssertEqual(MuskelLogik.standardZiel(.schulter, prio: true), 16)
        XCTAssertEqual(MuskelLogik.standardZiel(.ruecken, prio: true), 16)
        XCTAssertEqual(MuskelLogik.standardZiel(.brust, prio: true), 12)
        XCTAssertEqual(MuskelLogik.standardZiel(.schulter, prio: false), 8)
        XCTAssertEqual(MuskelGruppe.standardPrio.count, 5)
    }
}
