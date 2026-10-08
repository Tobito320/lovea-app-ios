import XCTest
@testable import Lovea

/// p58: the home scene's rules: hour to time of day, who stands where, how long a step lasts.
final class ZuhauseAblaufTests: XCTestCase {
    func testStundeZuTageszeit() {
        let erwartet: [Int: Tageszeit] = [
            0: .nacht, 3: .nacht, 6: .nacht, 7: .morgen, 10: .morgen, 11: .tag, 15: .tag, 18: .tag,
            19: .abend, 21: .abend, 22: .nacht, 23: .nacht,
        ]
        for (stunde, zeit) in erwartet { XCTAssertEqual(Tageszeit(stunde: stunde), zeit, "Stunde \(stunde)") }
        for stunde in 0..<24 { _ = Tageszeit(stunde: stunde) }
    }

    func testAbendUndNachtBeideImBett() {
        for zeit in [Tageszeit.abend, .nacht] {
            for schritt in 0..<12 {
                let s = ZuhauseAblauf.aufstellung(zeit, schritt: schritt)
                XCTAssertEqual(s.annika, .bett)
                XCTAssertEqual(s.ahmed, .bett)
                XCTAssertNil(s.geste)
            }
            XCTAssertFalse(ZuhauseAblauf.bewegt(zeit))
        }
    }

    func testMorgensAmFensterTagsAufDemSofa() {
        XCTAssertEqual(ZuhauseAblauf.ruhestand(.morgen).annika, .fenster)
        XCTAssertEqual(ZuhauseAblauf.ruhestand(.tag).annika, .sofa)
        XCTAssertTrue(ZuhauseAblauf.bewegt(.morgen))
        XCTAssertTrue(ZuhauseAblauf.bewegt(.tag))
    }

    func testTagsGehtAnnikaAuchZumBett() {
        XCTAssertTrue(ZuhauseAblauf.abfolge(.tag).contains { $0.annika == .bett })
    }

    func testJederSchrittAendertWasUndDerKreisSchliesst() {
        for zeit in Tageszeit.allCases {
            let schritte = ZuhauseAblauf.abfolge(zeit)
            XCTAssertFalse(schritte.isEmpty)
            guard schritte.count > 1 else { continue }
            for i in schritte.indices {
                let naechster = schritte[(i + 1) % schritte.count]
                let a = schritte[i]
                XCTAssertTrue(a.annika != naechster.annika || a.ahmed != naechster.ahmed, "\(zeit) Schritt \(i) bleibt stehen")
            }
        }
    }

    func testGestenNurWoAnnikaStehtNichtImBett() {
        for zeit in Tageszeit.allCases {
            for s in ZuhauseAblauf.abfolge(zeit) where s.geste != nil {
                XCTAssertNotEqual(s.annika, .bett)
            }
        }
    }

    func testSchrittLaeuftImKreisAuchRueckwaerts() {
        let n = ZuhauseAblauf.abfolge(.tag).count
        XCTAssertEqual(ZuhauseAblauf.aufstellung(.tag, schritt: n), ZuhauseAblauf.aufstellung(.tag, schritt: 0))
        XCTAssertEqual(ZuhauseAblauf.aufstellung(.tag, schritt: n + 2), ZuhauseAblauf.aufstellung(.tag, schritt: 2))
        XCTAssertEqual(ZuhauseAblauf.aufstellung(.tag, schritt: -1), ZuhauseAblauf.aufstellung(.tag, schritt: n - 1))
    }

    func testWartezeitZwanzigBisSechzig() {
        var gesehen = Set<TimeInterval>()
        for schritt in -50..<500 {
            let s = ZuhauseAblauf.wartezeit(schritt: schritt)
            XCTAssertTrue((20...60).contains(s), "Schritt \(schritt): \(s)")
            gesehen.insert(s)
        }
        XCTAssertGreaterThan(gesehen.count, 20, "die Pausen wechseln, kein fester Takt")
    }

    func testSekundenBisWechsel() {
        XCTAssertEqual(Tageszeit.sekundenBisWechsel(stunde: 6, minute: 30), 30 * 60)
        XCTAssertEqual(Tageszeit.sekundenBisWechsel(stunde: 7, minute: 0), 4 * 3600)
        XCTAssertEqual(Tageszeit.sekundenBisWechsel(stunde: 21, minute: 59), 60)
        XCTAssertEqual(Tageszeit.sekundenBisWechsel(stunde: 23, minute: 0), 8 * 3600)
        XCTAssertEqual(Tageszeit.sekundenBisWechsel(stunde: 0, minute: 0), 7 * 3600)
        for stunde in 0..<24 {
            let s = Tageszeit.sekundenBisWechsel(stunde: stunde, minute: 17)
            XCTAssertGreaterThan(s, 0)
            XCTAssertLessThanOrEqual(s, 9 * 3600)
        }
    }

    func testOrteLiegenImBildUndZweiStehenNieAufeinander() {
        for platz in Platz.allCases {
            let a = ZuhauseOrte.fuss(platz, .annika)
            let h = ZuhauseOrte.fuss(platz, .ahmed)
            XCTAssertLessThan(a.x, h.x, "Annika links von Ahmed")
            for p in [a, h] {
                XCTAssertTrue((20...370).contains(p.x))
                XCTAssertEqual(p.y, ZuhauseOrte.fussY)
            }
        }
    }

    func testGehdauerBleibtRuhig() {
        XCTAssertEqual(ZuhauseOrte.gehdauer(von: .sofa, nach: .sofa, .annika), 0)
        for von in Platz.allCases {
            for nach in Platz.allCases where von != nach {
                for person in [Person.annika, .ahmed] {
                    let d = ZuhauseOrte.gehdauer(von: von, nach: nach, person)
                    XCTAssertTrue((1.4...3.4).contains(d), "\(von) nach \(nach): \(d)")
                }
            }
        }
    }

    func testStraeusseSchrankHatDreiPlaetze() {
        XCTAssertEqual(ZuhauseStraeusse.schrankPlaetze, 3)
        XCTAssertEqual(ZuhauseStraeusse().imSchrank, [])
        XCTAssertNil(ZuhauseStraeusse().vase)
        XCTAssertEqual(ZuhauseStraeusse(schrank: ["a", "b"]).imSchrank, ["a", "b"])
        XCTAssertEqual(ZuhauseStraeusse(schrank: ["a", "b", "c", "d", "e"]).imSchrank, ["a", "b", "c"])
    }
}
