import XCTest
@testable import Lovea

final class ZimmerSchreibenLogikTests: XCTestCase {
    private typealias L = ZimmerSchreibenLogik

    func testKomplimentGleichBeiGleichemTag() {
        let a = Datum.datum("2026-10-09")
        let b = a.addingTimeInterval(3 * 3600)
        XCTAssertEqual(L.kompliment(fuer: a), L.kompliment(fuer: b))
    }

    func testKomplimentWechseltTaeglichUndLaeuftUm() {
        let tag = Datum.datum("2026-03-01")
        let n = L.komplimente.count
        let spaeter = Calendar.berlin.date(byAdding: .day, value: n, to: tag)!
        XCTAssertEqual(L.kompliment(fuer: tag), L.kompliment(fuer: spaeter))
        let naechster = Calendar.berlin.date(byAdding: .day, value: 1, to: tag)!
        XCTAssertNotEqual(L.kompliment(fuer: tag), L.kompliment(fuer: naechster))
    }

    func testKomplimentVorBezugKeinAbsturz() {
        XCTAssertFalse(L.kompliment(fuer: Datum.datum("2025-06-01")).isEmpty)
    }

    func testListeHatUmDieHundertUndKeineDubletten() {
        XCTAssertGreaterThanOrEqual(L.komplimente.count, 100)
        XCTAssertEqual(Set(L.komplimente).count, L.komplimente.count)
    }

    func testKapselOeffnetNaechstesJahrGleichesDatum() {
        let jetzt = Datum.datum("2026-10-09").addingTimeInterval(14 * 3600)
        XCTAssertEqual(Datum.text(L.kapselOeffnung(geschrieben: jetzt)), "2027-10-09")
    }

    func testKapselSchaltjahr() {
        let o = L.kapselOeffnung(geschrieben: Datum.datum("2028-02-29"))
        XCTAssertTrue(["2029-02-28", "2029-03-01"].contains(Datum.text(o)))
    }

    func testKapselVerschlossenBisZumTag() {
        let o = Datum.datum("2027-10-09")
        XCTAssertFalse(L.kapselOffen(oeffnung: o, jetzt: Datum.datum("2027-10-08")))
        XCTAssertTrue(L.kapselOffen(oeffnung: o, jetzt: o))
        XCTAssertEqual(L.kapselTageBis(oeffnung: o, jetzt: Datum.datum("2027-10-06")), 3)
        XCTAssertEqual(L.kapselTageBis(oeffnung: o, jetzt: Datum.datum("2028-01-01")), 0)
    }

    func testTagebuchSchluesselJeMonat() {
        XCTAssertEqual(L.tagebuchSchluessel(tag: "2026-10-09"), "zimmer.tagebuch.2026-10")
    }

    func testEintragBereinigt() {
        XCTAssertNil(L.eintragBereinigt("  \n "))
        XCTAssertEqual(L.eintragBereinigt(" Hallo "), "Hallo")
        XCTAssertEqual(L.eintragBereinigt(String(repeating: "a", count: 300))?.count, L.maxZeichen)
    }

    func testBuchErstAb365() {
        XCTAssertFalse(L.istBuch(anzahl: 364))
        XCTAssertTrue(L.istBuch(anzahl: 365))
        XCTAssertEqual(L.anzahl([["2026-10-01": "a", "2026-10-02": ""], ["2026-11-01": "b"]]), 2)
    }

    func testSeitenVereinenBeidePersonen() {
        let s = L.seiten(ahmed: ["2026-10-02": "x"], annika: ["2026-10-01": "y", "2026-10-02": "z"])
        XCTAssertEqual(s.map(\.tag), ["2026-10-01", "2026-10-02"])
        XCTAssertEqual(s[1].ahmed, "x")
        XCTAssertEqual(s[1].annika, "z")
        XCTAssertNil(s[0].ahmed)
        XCTAssertEqual(L.seiten(ahmed: ["2026-10-02": "x"], annika: ["2026-10-01": "y"], neuesteZuerst: true).first?.tag, "2026-10-02")
    }

    func testStempel() {
        XCTAssertEqual(L.stempel(ort: " Lissabon "), "LISSABON")
        XCTAssertEqual(L.stempel(ort: "Sehr langer Ortsname hier")?.count, 14)
        XCTAssertNil(L.stempel(ort: "  "))
        XCTAssertNil(L.stempel(ort: nil))
    }

    // MARK: Langsame Post

    private func brief(ankunft: Date?, von: Person = .ahmed) -> Brief {
        Brief(id: "b", titel: "t", text: "x", sprache: nil, dauer: nil, pegel: nil, von: von, zeit: Date(timeIntervalSince1970: 1_760_000_000), ankunft: ankunft)
    }

    func testUnterwegsNurBisAnkunft() {
        let jetzt = Date(timeIntervalSince1970: 1_760_000_000)
        XCTAssertFalse(BriefeLogik.unterwegs(brief(ankunft: nil), jetzt: jetzt))
        XCTAssertTrue(BriefeLogik.unterwegs(brief(ankunft: jetzt.addingTimeInterval(60)), jetzt: jetzt))
        XCTAssertFalse(BriefeLogik.unterwegs(brief(ankunft: jetzt), jetzt: jetzt))
    }

    func testAnkunftKlemmtTageUndLiegtInZukunft() {
        let start = Datum.datum("2026-10-09").addingTimeInterval(20 * 3600)
        XCTAssertEqual(Datum.text(BriefeLogik.ankunft(tage: 1, ab: start)), "2026-10-10")
        XCTAssertEqual(Datum.text(BriefeLogik.ankunft(tage: 9, ab: start)), "2026-10-12")
        XCTAssertEqual(Datum.text(BriefeLogik.ankunft(tage: 0, ab: start)), "2026-10-10")
    }

    func testUnterwegsBriefNichtBeiEmpfaengerinAberBeiAbsender() {
        let jetzt = Date(timeIntervalSince1970: 1_760_000_000)
        let flug = brief(ankunft: jetzt.addingTimeInterval(3600))
        let stand = BriefeStand(briefe: ["b": flug], geoeffnet: [:])
        XCTAssertTrue(BriefeLogik.erhalten(stand, ich: .annika, jetzt: jetzt).isEmpty)
        XCTAssertEqual(BriefeLogik.ungeoeffnet(stand, ich: .annika, jetzt: jetzt), 0)
        XCTAssertEqual(BriefeLogik.fliegende(stand, ich: .ahmed, jetzt: jetzt).count, 1)
        let spaeter = jetzt.addingTimeInterval(7200)
        XCTAssertEqual(BriefeLogik.erhalten(stand, ich: .annika, jetzt: spaeter).count, 1)
        XCTAssertEqual(BriefeLogik.ungeoeffnet(stand, ich: .annika, jetzt: spaeter), 1)
        XCTAssertTrue(BriefeLogik.fliegende(stand, ich: .ahmed, jetzt: spaeter).isEmpty)
    }
}
