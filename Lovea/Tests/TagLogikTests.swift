import XCTest
@testable import Lovea

/// "Ahmeds Tag": Rohwerte -> Zeitleiste. Tage nach Berliner Kalender, `tag` und alle Zeiten fest vorgegeben.
final class TagLogikTests: XCTestCase {
    private let kal = Calendar.berlin

    private func zeit(_ tag: Int, _ h: Int, _ m: Int = 0) -> Date {
        kal.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: h, minute: m))!
    }

    private func leiste(_ roh: [TagRoh], tag: Int = 8, ansicht: Person = .annika, person: Person = .ahmed) -> TagAnsicht {
        TagLogik.zeitleiste(roh, tag: zeit(tag, 12), ansicht: ansicht, person: person, kalender: kal)
    }

    func testLeererTagHatKeineMomente() {
        let a = leiste([])
        XCTAssertTrue(a.momente.isEmpty)
        XCTAssertEqual(a.herzen, 0)
    }

    func testZwanzigSchritteStaendeWerdenEinMeilenstein() {
        let roh = (0..<20).map { i in
            TagRoh(id: "s\(i)", zeit: zeit(8, 9, i * 3), art: .schritte(anzahl: 2_100 + i * 100))
        }
        let schritte = leiste(roh).momente.filter { $0.sorte == .schritte }
        XCTAssertEqual(schritte.count, 1)
        XCTAssertEqual(schritte[0].text, "2.000 Schritte geschafft")
        XCTAssertEqual(schritte[0].zeit, zeit(8, 9, 0))
    }

    func testSprungUeberMehrereMarkenZaehltNurDieHoechste() {
        let roh = [TagRoh(id: "a", zeit: zeit(8, 10), art: .schritte(anzahl: 600)),
                   TagRoh(id: "b", zeit: zeit(8, 11), art: .schritte(anzahl: 5_400))]
        let schritte = leiste(roh).momente.filter { $0.sorte == .schritte }
        XCTAssertEqual(schritte.map(\.text), ["5.000 Schritte geschafft"])
    }

    func testSchlafUeberMitternachtGehoertZumAufwachtag() {
        let nacht = TagRoh(id: "n", zeit: zeit(8, 6, 30), art: .schlaf(von: zeit(7, 23), bis: zeit(8, 6, 30), minuten: 440))
        XCTAssertTrue(leiste([nacht], tag: 7).momente.isEmpty)
        let heute = leiste([nacht], tag: 8).momente
        XCTAssertEqual(heute.count, 1)
        XCTAssertEqual(heute[0].text, "Aufgewacht · 7 Std. 20 Min. geschlafen")
        XCTAssertEqual(heute[0].zeit, zeit(8, 6, 30))
    }

    func testUeberlappendeSchlafEintraegeSindEinAufwachen() {
        let a = TagRoh(id: "a", zeit: zeit(8, 6), art: .schlaf(von: zeit(8, 0, 10), bis: zeit(8, 6), minuten: 330))
        let b = TagRoh(id: "b", zeit: zeit(8, 7), art: .schlaf(von: zeit(8, 0, 10), bis: zeit(8, 7), minuten: 400))
        let schlaf = leiste([a, b]).momente.filter { $0.sorte == .schlaf }
        XCTAssertEqual(schlaf.count, 1)
        XCTAssertEqual(schlaf[0].zeit, zeit(8, 7))
    }

    func testDoppelteIdsZaehlenEinmalUndReihenfolgeIstEgal() {
        let h1 = TagRoh(id: "h1", zeit: zeit(8, 15), art: .herz)
        let h2 = TagRoh(id: "h2", zeit: zeit(8, 9), art: .herz)
        let a = leiste([h1, h2, h1, h2, h1])
        XCTAssertEqual(a.herzen, 2)
        XCTAssertEqual(a.momente.count, 2) // 6 Stunden auseinander
        XCTAssertEqual(a.momente.map(\.zeit), [zeit(8, 9), zeit(8, 15)])
    }

    func testHerzenKurzHintereinanderEineZeileJederTippZaehlt() {
        let roh = (0..<14).map { TagRoh(id: "h\($0)", zeit: zeit(8, 20, $0), art: .herz) }
        let a = leiste(roh)
        XCTAssertEqual(a.herzen, 14)
        XCTAssertEqual(a.momente.count, 1)
        XCTAssertEqual(a.momente[0].text, "An dich gedacht · 14×")
    }

    func testHerzTextAusSichtDesPartnersUndDerEigenenPerson() {
        let h = [TagRoh(id: "h", zeit: zeit(8, 9), art: .herz)]
        XCTAssertEqual(leiste(h, ansicht: .annika, person: .ahmed).momente[0].text, "An dich gedacht")
        XCTAssertEqual(leiste(h, ansicht: .ahmed, person: .ahmed).momente[0].text, "An Annika gedacht")
    }

    func testSnapHatNieEineVorschau() {
        let roh = [TagRoh(id: "s", zeit: zeit(8, 12), art: .snap),
                   TagRoh(id: "f", zeit: zeit(8, 14), art: .foto(medienId: "m1"))]
        let momente = leiste(roh).momente
        XCTAssertNil(momente.first { $0.sorte == .snap }?.medienId)
        XCTAssertEqual(momente.first { $0.sorte == .foto }?.medienId, "m1")
    }

    func testFotosKurzHintereinanderWerdenZusammengefasst() {
        let roh = [TagRoh(id: "a", zeit: zeit(8, 12, 0), art: .foto(medienId: nil)),
                   TagRoh(id: "b", zeit: zeit(8, 12, 4), art: .foto(medienId: "m2")),
                   TagRoh(id: "c", zeit: zeit(8, 12, 8), art: .foto(medienId: "m3"))]
        let fotos = leiste(roh).momente.filter { $0.sorte == .foto }
        XCTAssertEqual(fotos.count, 1)
        XCTAssertEqual(fotos[0].text, "3 Fotos geschickt")
        XCTAssertEqual(fotos[0].medienId, "m2") // erste Vorschau, die es gibt
    }

    func testGymTrainingHatStartUebungenUndEnde() {
        let roh = [
            TagRoh(id: "1", zeit: zeit(8, 17), art: .gymStart(session: "g")),
            TagRoh(id: "2", zeit: zeit(8, 17, 20), art: .gymUebung(session: "g", name: "Bankdrücken")),
            TagRoh(id: "3", zeit: zeit(8, 17, 40), art: .gymUebung(session: "g", name: "Schrägbank")),
            TagRoh(id: "4", zeit: zeit(8, 17, 50), art: .gymUebung(session: "g", name: "Bankdrücken")),
            TagRoh(id: "5", zeit: zeit(8, 18, 5), art: .gymEnde(session: "g", minuten: 62, saetze: 24)),
        ]
        let gym = leiste(roh).momente.filter { $0.sorte == .gym }
        XCTAssertEqual(gym.map(\.text), ["Los geht’s im Gym", "Geschafft: Bankdrücken, Schrägbank", "Training beendet · 62 Min. · 24 Sätze"])
    }

    func testViereUebungenWerdenGekuerzt() {
        let namen = ["A", "B", "C", "D", "E"]
        let roh = namen.enumerated().map { i, n in
            TagRoh(id: "u\(i)", zeit: zeit(8, 17, i), art: .gymUebung(session: "g", name: n))
        }
        XCTAssertEqual(leiste(roh).momente.first?.text, "Geschafft: A, B, C und 2 weitere")
    }

    func testTagesgrenzeIstMitternachtInBerlin() {
        let knapp = TagRoh(id: "k", zeit: zeit(8, 23, 59), art: .herz)
        let danach = TagRoh(id: "d", zeit: zeit(9, 0, 1), art: .herz)
        XCTAssertEqual(leiste([knapp, danach], tag: 8).herzen, 1)
        XCTAssertEqual(leiste([knapp, danach], tag: 9).herzen, 1)
    }

    func testMomenteSindNachZeitSortiert() {
        let roh = [
            TagRoh(id: "h", zeit: zeit(8, 20), art: .herz),
            TagRoh(id: "s", zeit: zeit(8, 7), art: .schlaf(von: zeit(8, 0), bis: zeit(8, 7), minuten: 400)),
            TagRoh(id: "f", zeit: zeit(8, 13), art: .foto(medienId: nil)),
        ]
        XCTAssertEqual(leiste(roh).momente.map(\.sorte), [.schlaf, .foto, .herz])
    }

    func testTitelUndTausenderPunkt() {
        XCTAssertEqual(TagLogik.titel(person: .ahmed, momente: 7), "Ahmeds Tag · 7 Momente")
        XCTAssertEqual(TagLogik.titel(person: .annika, momente: 1), "Annikas Tag · 1 Moment")
        XCTAssertEqual(TagLogik.titel(person: .ahmed, momente: 0), "Ahmeds Tag")
        XCTAssertEqual(TagLogik.tausender(10_000), "10.000")
        XCTAssertEqual(TagLogik.tausender(950), "950")
        XCTAssertEqual(TagLogik.dauer(45), "45 Min.")
        XCTAssertEqual(TagLogik.dauer(120), "2 Std.")
    }
}
