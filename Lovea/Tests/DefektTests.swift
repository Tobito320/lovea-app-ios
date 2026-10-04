import XCTest
@testable import Lovea

@MainActor
final class DefektTests: XCTestCase {
    private func frisch() -> (DefektNotizen, UserDefaults) {
        let name = "defekt-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return (DefektNotizen(defaults: defaults), defaults)
    }

    private let smith = "903mzG8"

    func testSpeichernUndLaden() {
        let (n, defaults) = frisch()
        n.melden(text: "  Sitz wackelt ", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-01")
        let geladen = DefektNotizen(defaults: defaults).offen(.ahmed, .fitxHagenMitte, uebung: smith)
        XCTAssertEqual(geladen, DefektNotiz(text: "Sitz wackelt", gemeldetAm: "2026-10-01"))
    }

    func testLeererTextIstNil() {
        let (n, _) = frisch()
        n.melden(text: "   ", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-01")
        XCTAssertNil(n.offen(.ahmed, .fitxHagenMitte, uebung: smith)?.text)
        XCTAssertNotNil(n.offen(.ahmed, .fitxHagenMitte, uebung: smith))
    }

    func testStudioTrennung() {
        let (n, _) = frisch()
        n.melden(text: "kaputt", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-01")
        XCTAssertNil(n.offen(.ahmed, .absolutFit, uebung: smith))
        XCTAssertNil(n.offen(.ahmed, .fitxHagenMitte, uebung: "EIeI8Vf"))
        XCTAssertNil(n.offen(.annika, .fitxHagenMitte, uebung: smith))
    }

    func testErledigenBlendetAus() {
        let (n, defaults) = frisch()
        n.melden(text: "kaputt", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-01")
        n.erledigen(.ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-03")
        XCTAssertNil(n.offen(.ahmed, .fitxHagenMitte, uebung: smith))
        XCTAssertNil(DefektNotizen(defaults: defaults).offen(.ahmed, .fitxHagenMitte, uebung: smith))
        n.melden(text: "wieder", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-05")
        XCTAssertEqual(n.offen(.ahmed, .fitxHagenMitte, uebung: smith)?.gemeldetAm, "2026-10-05")
    }

    func testLoeschen() {
        let (n, _) = frisch()
        n.melden(text: "kaputt", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-01")
        n.loeschen(.ahmed, .fitxHagenMitte, uebung: smith)
        XCTAssertNil(n.offen(.ahmed, .fitxHagenMitte, uebung: smith))
    }

    func testBestaetigenSetztDatumNeu() {
        let (n, _) = frisch()
        n.melden(text: "kaputt", .ahmed, .fitxHagenMitte, uebung: smith, am: "2026-08-01")
        n.bestaetigen(.ahmed, .fitxHagenMitte, uebung: smith, am: "2026-10-05")
        let neu = n.offen(.ahmed, .fitxHagenMitte, uebung: smith)
        XCTAssertEqual(neu?.gemeldetAm, "2026-10-05")
        XCTAssertEqual(neu?.text, "kaputt")
    }

    func testAltersanzeige() {
        let heute = "2026-10-05"
        func text(_ tag: String) -> String { DefektLogik.alterText(DefektNotiz(gemeldetAm: tag), heute: heute) }
        XCTAssertEqual(text("2026-10-05"), "heute")
        XCTAssertEqual(text("2026-10-04"), "gestern")
        XCTAssertEqual(text("2026-10-02"), "vor 3 Tagen")
        XCTAssertEqual(text("2026-10-06"), "heute", "Zukunft nie negativ")
    }

    func testVeraltetErstNachDreissigTagen() {
        let heute = "2026-10-05"
        XCTAssertFalse(DefektLogik.veraltet(DefektNotiz(gemeldetAm: "2026-09-05"), heute: heute))
        XCTAssertTrue(DefektLogik.veraltet(DefektNotiz(gemeldetAm: "2026-09-04"), heute: heute))
    }

    func testAusweichVorschlag() throws {
        let plan = PlanUebung(id: "p1", uebung: smith, name: nil, saetze: [], minuten: nil)
        let u = WorkoutUebung(planUebung: plan, saetze: [], vorher: [], extra: false)
        let vorschlag = try XCTUnwrap(DefektLogik.vorschlag(fuer: u))
        let ausweich = AusweichLogik.alternativen(fuer: try XCTUnwrap(plan.katalog))
        XCTAssertEqual(vorschlag.id, ausweich.first?.id)
        XCTAssertNotEqual(vorschlag.id, smith)
    }

    func testAusweichVorschlagNachTauschNichtDieAktuelle() throws {
        let erste = try XCTUnwrap(AusweichLogik.alternativen(fuer: try XCTUnwrap(UebungsKatalog.nachId[smith])).first)
        let plan = PlanUebung(id: "p1", uebung: erste.id, name: nil, saetze: [], minuten: nil)
        let u = WorkoutUebung(planUebung: plan, saetze: [], vorher: [], extra: false, ersatzFuer: smith)
        let vorschlag = try XCTUnwrap(DefektLogik.vorschlag(fuer: u))
        XCTAssertNotEqual(vorschlag.id, erste.id)
    }

    func testKeinVorschlagBeiEigenerUebung() {
        let u = WorkoutUebung(planUebung: PlanUebung.eigene("Mein Ding"), saetze: [], vorher: [], extra: false)
        XCTAssertNil(DefektLogik.vorschlag(fuer: u))
    }
}
