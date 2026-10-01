import XCTest
@testable import Lovea

final class StundenplanTests: XCTestCase {
    private func blocks(_ tag: String, _ muster: [Muster]) -> [Block] {
        Wochenplan.tag(tag, person: "annika", daten: KalenderDaten(muster: muster))
    }

    /// Mo und Mi 07:50–14:45, Di, Do, Fr 07:50–13:00, ein Schul-Block pro Tag, keine Wechselwoche.
    func testZeitenProTag() {
        let plan = Stundenplan.annika()
        let erwartet: [(tag: String, ende: String)] = [
            ("2026-09-28", "14:45"), // Mo
            ("2026-09-29", "13:00"), // Di
            ("2026-09-30", "14:45"), // Mi
            ("2026-10-01", "13:00"), // Do
            ("2026-10-02", "13:00"), // Fr
        ]
        for e in erwartet {
            let heute = blocks(e.tag, plan)
            XCTAssertEqual(heute.count, 1, e.tag)
            XCTAssertEqual(heute.first?.typ, "schule", e.tag)
            XCTAssertEqual(heute.first?.start, "07:50", e.tag)
            XCTAssertEqual(heute.first?.ende, e.ende, e.tag)
        }
    }

    func testWochenendeUndKeineWechselwoche() {
        let plan = Stundenplan.annika()
        XCTAssertTrue(blocks("2026-10-03", plan).isEmpty) // Sa
        XCTAssertTrue(blocks("2026-10-04", plan).isEmpty) // So
        XCTAssertTrue(plan.allSatisfy { $0.wochen == "alle" && $0.person == "annika" })
        // Woche A (KW40) und Woche B (KW41) gleich.
        XCTAssertEqual(blocks("2026-09-28", plan).map(\.ende), blocks("2026-10-05", plan).map(\.ende))
    }

    /// Frische Installation bekommt gleich den Stundenplan als Startmuster.
    func testStartmusterAnnikaIstDerStundenplan() {
        XCTAssertEqual(KalenderModell.standardMuster(fuer: .annika), Stundenplan.annika())
    }

    func testAltesStandardmusterWirdUmgestellt() {
        let alt = Stundenplan.altesStartmusterAnnika()
        let um = Stundenplan.umstellung(fuer: .annika, muster: [alt])
        XCTAssertEqual(um?.loeschen, "start-annika-schule")
        XCTAssertEqual(um?.setzen, Stundenplan.annika())
    }

    func testEigenerWochenplanBleibt() {
        let alt = Stundenplan.altesStartmusterAnnika()
        var geaendert = alt
        geaendert.start = "08:00"
        geaendert.ende = "13:00"
        let eigenes = Muster(id: "x", person: "annika", typ: "arbeit", titel: "Job", wochentage: [6], wochen: "alle", start: "10:00", ende: "16:00", ab: "2026-09-21")

        XCTAssertNil(Stundenplan.umstellung(fuer: .annika, muster: [geaendert]))
        XCTAssertNil(Stundenplan.umstellung(fuer: .annika, muster: [alt, eigenes]))
        XCTAssertNil(Stundenplan.umstellung(fuer: .annika, muster: [eigenes]))
        XCTAssertNil(Stundenplan.umstellung(fuer: .annika, muster: [])) // alles gelöscht = Entscheidung
    }

    func testNurAnnikaUndNurNachDemAltenStandard() {
        let alt = Stundenplan.altesStartmusterAnnika()
        XCTAssertNil(Stundenplan.umstellung(fuer: .ahmed, muster: [alt]))
        // Schon umgestellt: der neue Plan stößt nichts mehr an.
        XCTAssertNil(Stundenplan.umstellung(fuer: .annika, muster: Stundenplan.annika()))
        // Muster des Partners stören nicht.
        let ahmed = KalenderModell.standardMuster(fuer: .ahmed)
        XCTAssertNotNil(Stundenplan.umstellung(fuer: .annika, muster: [alt] + ahmed))
    }

    /// Vertretung und Ausfall sind einmalig: eine Ausnahme wirkt auf den Block und lässt das Muster stehen.
    func testAusfallEinmaligLaesstMusterStehen() {
        let ausfall = Ausnahme(person: "annika", datum: "2026-09-29", musterId: nil, status: "frei", bisDatum: nil, start: nil, ende: nil)
        let daten = KalenderDaten(muster: Stundenplan.annika(), ausnahmen: [ausfall])
        XCTAssertEqual(Wochenplan.tag("2026-09-29", person: "annika", daten: daten).map(\.status), ["frei"])
        XCTAssertEqual(Wochenplan.tag("2026-10-06", person: "annika", daten: daten).map(\.status), ["normal"])
    }
}
