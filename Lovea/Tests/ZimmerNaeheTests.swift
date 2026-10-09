import XCTest
@testable import Lovea

final class ZimmerNaeheTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_800_000_000)

    func testKatzeLiegtBeiDemDerZuletztDaWar() {
        // Partner gerade da: Katze beim Partner
        XCTAssertFalse(ZimmerNaeheLogik.katzeBeiAhmed(ich: .ahmed, partnerDa: true, partnerZuletzt: nil, jetzt: jetzt))
        XCTAssertTrue(ZimmerNaeheLogik.katzeBeiAhmed(ich: .annika, partnerDa: true, partnerZuletzt: nil, jetzt: jetzt))
        // Partner lange weg: Katze bei mir
        let lange = jetzt.addingTimeInterval(-3 * 3600)
        XCTAssertTrue(ZimmerNaeheLogik.katzeBeiAhmed(ich: .ahmed, partnerDa: false, partnerZuletzt: lange, jetzt: jetzt))
        // Partner vor 5 Minuten: noch bei ihm
        let kurz = jetzt.addingTimeInterval(-300)
        XCTAssertFalse(ZimmerNaeheLogik.katzeBeiAhmed(ich: .ahmed, partnerDa: false, partnerZuletzt: kurz, jetzt: jetzt))
    }

    func testSterneNurNachts() {
        XCTAssertTrue(ZimmerNaeheLogik.nacht(stunde: 23))
        XCTAssertTrue(ZimmerNaeheLogik.nacht(stunde: 2))
        XCTAssertFalse(ZimmerNaeheLogik.nacht(stunde: 12))
        XCTAssertFalse(ZimmerNaeheLogik.nacht(stunde: 5))
    }

    func testSternOrtStabilUndImRahmen() {
        let a = ZimmerNaeheLogik.sternOrt(id: "x1")
        XCTAssertEqual(a, ZimmerNaeheLogik.sternOrt(id: "x1"))
        for id in ["a", "b", "foto-9", "satz-3"] {
            let p = ZimmerNaeheLogik.sternOrt(id: id)
            XCTAssertTrue((0...1).contains(p.x) && (0...1).contains(p.y))
        }
    }

    func testSterneDoppelteRausUndGedeckelt() {
        XCTAssertEqual(ZimmerNaeheLogik.sterne(ids: ["a", "b", "a"]), ["a", "b"])
        let viele = (0..<100).map { "i\($0)" }
        XCTAssertEqual(ZimmerNaeheLogik.sterne(ids: viele).count, ZimmerNaeheLogik.sterneMaximum)
    }

    func testSchubladeNurBeiBeidenImFenster() {
        let f = ZimmerNaeheLogik.schubladeFenster
        XCTAssertTrue(ZimmerNaeheLogik.schubladeOffen(meinHalt: jetzt, partnerHalt: jetzt.addingTimeInterval(-3), jetzt: jetzt))
        XCTAssertFalse(ZimmerNaeheLogik.schubladeOffen(meinHalt: jetzt, partnerHalt: jetzt.addingTimeInterval(-f - 1), jetzt: jetzt))
        XCTAssertFalse(ZimmerNaeheLogik.schubladeOffen(meinHalt: jetzt, partnerHalt: nil, jetzt: jetzt))
        XCTAssertFalse(ZimmerNaeheLogik.schubladeOffen(meinHalt: nil, partnerHalt: jetzt, jetzt: jetzt))
        // beide alt: nicht mehr offen
        XCTAssertFalse(ZimmerNaeheLogik.schubladeOffen(meinHalt: jetzt, partnerHalt: jetzt, jetzt: jetzt.addingTimeInterval(f + 5)))
    }

    func testZettel() {
        XCTAssertNil(ZimmerNaeheLogik.bereinigt("   "))
        XCTAssertEqual(ZimmerNaeheLogik.bereinigt("  hi "), "hi")
        XCTAssertEqual(ZimmerNaeheLogik.bereinigt(String(repeating: "a", count: 500))?.count, ZimmerNaeheLogik.zettelMaximum)
        var liste: [ZimmerNaeheLogik.Zettel] = []
        for i in 0..<20 { liste = ZimmerNaeheLogik.zettelHinzu(liste, text: "z\(i)", id: "\(i)") }
        XCTAssertEqual(liste.count, ZimmerNaeheLogik.zettelAnzahl)
        XCTAssertEqual(liste.last?.text, "z19")
        XCTAssertEqual(ZimmerNaeheLogik.zettelHinzu(liste, text: " ", id: "x"), liste)
    }

    func testKilometerGrobGerundet() {
        XCTAssertEqual(ZimmerNaeheLogik.gerundeteKm(meter: 0), 0)
        XCTAssertEqual(ZimmerNaeheLogik.gerundeteKm(meter: 3_400), 3)
        XCTAssertEqual(ZimmerNaeheLogik.gerundeteKm(meter: 47_000), 45)
        XCTAssertEqual(ZimmerNaeheLogik.gerundeteKm(meter: 432_000), 430)
        XCTAssertEqual(ZimmerNaeheLogik.gerundeteKm(meter: -5), 0)
    }

    func testFadenLaenge() {
        XCTAssertEqual(ZimmerNaeheLogik.fadenLaenge(km: 0), ZimmerNaeheLogik.fadenNah, accuracy: 0.0001)
        XCTAssertEqual(ZimmerNaeheLogik.fadenLaenge(km: 1000), 1, accuracy: 0.0001)
        XCTAssertEqual(ZimmerNaeheLogik.fadenLaenge(km: 5000), 1, accuracy: 0.0001)
        XCTAssertLessThan(ZimmerNaeheLogik.fadenLaenge(km: 100), ZimmerNaeheLogik.fadenLaenge(km: 500))
        XCTAssertNil(ZimmerNaeheLogik.fadenText(km: nil))
        XCTAssertEqual(ZimmerNaeheLogik.fadenText(km: 0), "Ihr seid am selben Ort")
        XCTAssertEqual(ZimmerNaeheLogik.fadenText(km: 40), "Noch rund 40 km")
    }

    func testKofferPackt() {
        let n = ZimmerNaeheLogik.koffer.count
        XCTAssertEqual(ZimmerNaeheLogik.gepackt(tageBis: 30), 0)
        XCTAssertEqual(ZimmerNaeheLogik.gepackt(tageBis: n), 1)
        XCTAssertEqual(ZimmerNaeheLogik.gepackt(tageBis: 0), n)
        XCTAssertEqual(ZimmerNaeheLogik.tageBis("2026-10-12", heute: "2026-10-09"), 3)
        XCTAssertEqual(ZimmerNaeheLogik.tageBis("2026-10-09", heute: "2026-10-09"), 0)
        XCTAssertNil(ZimmerNaeheLogik.tageBis("2026-10-01", heute: "2026-10-09"))
        XCTAssertNil(ZimmerNaeheLogik.tageBis(nil, heute: "2026-10-09"))
        XCTAssertEqual(ZimmerNaeheLogik.naechsterBesuch(["2026-12-01", "2026-10-20", "2026-09-01"], heute: "2026-10-09"), "2026-10-20")
        XCTAssertNil(ZimmerNaeheLogik.naechsterBesuch([], heute: "2026-10-09"))
    }

    func testWochenendeUndBurg() {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        func tag(_ d: Int) -> Date { kal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 12))! }
        XCTAssertFalse(ZimmerNaeheLogik.wochenende(tag(9), kalender: kal))   // Freitag
        XCTAssertTrue(ZimmerNaeheLogik.wochenende(tag(10), kalender: kal))   // Samstag
        XCTAssertTrue(ZimmerNaeheLogik.wochenende(tag(11), kalender: kal))   // Sonntag
        XCTAssertFalse(ZimmerNaeheLogik.wochenende(tag(12), kalender: kal))  // Montag
        XCTAssertEqual(ZimmerNaeheLogik.decken(meine: 5, partner: 1), ZimmerNaeheLogik.deckenProPerson + 1)
        XCTAssertFalse(ZimmerNaeheLogik.burgVoll(meine: 3, partner: 2))
        XCTAssertTrue(ZimmerNaeheLogik.burgVoll(meine: 3, partner: 3))
    }

    func testKetteBirnen() {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let heute = kal.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))!
        let tage = ZimmerNaeheLogik.letzteTage(heute: heute, kalender: kal)
        XCTAssertEqual(tage.count, ZimmerNaeheLogik.kettenTage)
        XCTAssertEqual(tage.last, "2026-10-09")
        let b = ZimmerNaeheLogik.birnen(meine: tage, partner: Array(tage.suffix(5)), heute: heute)
        XCTAssertEqual(b.count, 30)
        XCTAssertEqual(b.filter { $0 }.count, 5)
        XCTAssertFalse(ZimmerNaeheLogik.kettenVoll(b))
        XCTAssertTrue(ZimmerNaeheLogik.kettenVoll(ZimmerNaeheLogik.birnen(meine: tage, partner: tage, heute: heute)))
        XCTAssertEqual(ZimmerNaeheLogik.tagHinzu(["a"], heute: "b"), ["a", "b"])
        XCTAssertEqual(ZimmerNaeheLogik.tagHinzu(["a", "b"], heute: "b"), ["a", "b"])
        XCTAssertEqual(ZimmerNaeheLogik.tagHinzu((0..<60).map { "t\($0)" }, heute: "neu").count, ZimmerNaeheLogik.kettenTage + 10)
    }

    func testNeuesteSprachpostDesPartners() {
        func post(_ id: String, _ von: Person, _ s: TimeInterval) -> Sprachpost {
            Sprachpost(id: id, medienId: "m" + id, dauer: 3, pegel: [], von: von, zeit: Date(timeIntervalSince1970: s))
        }
        let liste = [post("1", .annika, 10), post("2", .annika, 30), post("3", .ahmed, 99), post("4", .annika, 20)]
        XCTAssertEqual(ZimmerNaeheLogik.neuesteSprachpost(liste, von: .annika)?.id, "2")
        XCTAssertNil(ZimmerNaeheLogik.neuesteSprachpost([], von: .annika))
    }
}
