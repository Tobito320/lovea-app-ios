import XCTest
@testable import Lovea

final class PlanAusbauTests: XCTestCase {
    private func u(_ id: String, _ muskel: String, _ koerper: String = "Beine", name: String = "x") -> Uebung {
        Uebung(id: id, name: name, en: name, muskel: muskel, koerper: koerper, geraet: "", neben: [])
    }

    func testAlternativenGleicherMuskelBeliebteZuerst() {
        let liste = [u("a", "Quadrizeps", name: "Beinstrecker sitzend lang"), u("my33uHU", "Quadrizeps", name: "Beinstrecker an der Maschine"),
                     u("c", "Quadrizeps", name: "Kurz"), u("d", "Po"), u("e", "Quadrizeps", "Waden")]
        let alt = UebungsKatalog.alternativen(zu: liste[0], in: liste).map(\.id)
        XCTAssertEqual(alt, ["my33uHU", "c"], "ohne sich selbst, nur gleicher Muskel und Körperteil, beliebte zuerst")
    }

    func testMuskelnHaeufigsteZuerst() {
        let liste = [u("1", "Po"), u("2", "Po"), u("3", "Quadrizeps"), u("4", "Bauch", "Bauch")]
        XCTAssertEqual(UebungsKatalog.muskeln("Beine", in: liste), ["Po", "Quadrizeps"])
    }

    func testVorschlaegeNurBeliebteInListenreihenfolge() {
        let liste = [u("x", "Po"), u("my33uHU", "Quadrizeps"), u("EIeI8Vf", "Brust", "Brust")]
        XCTAssertEqual(UebungsKatalog.vorschlaege(in: liste).map(\.id), ["EIeI8Vf", "my33uHU"])
    }

    func testTagFarbeFesteDerReiheNachFlexibelEigen() {
        let tag = { (id: String, w: [Int]) in TrainingsTag(id: id, name: id, wochentage: w, uebungen: []) }
        let plan = TrainingsPlan(tage: [tag("a", [1]), tag("flex", []), tag("b", [3]), tag("c", [5])])
        XCTAssertEqual(plan.tage.map { TagFarbe.index($0, in: plan) }, [0, TagFarbe.flexibel, 1, 2])
    }

    func testKatalogVorschlaegeExistieren() {
        XCTAssertEqual(UebungsKatalog.beliebt.filter { UebungsKatalog.nachId[$0] == nil }, [], "jede Vorschlags-id gibt es im Katalog")
    }
}
