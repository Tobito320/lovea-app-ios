import XCTest
@testable import Lovea

final class FigurenTests: XCTestCase {
    private func berlin(_ tag: Int, _ monat: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal.date(from: DateComponents(year: 2026, month: monat, day: tag, hour: stunde, minute: minute))!
    }

    func testGesteSchlaegtAlles() {
        var e = FigurEingabe(person: .ahmed, jetzt: berlin(10, 3, 22))
        e.geste = .herz
        e.online = false
        e.app = .tippt
        e.ort = .gym
        e.bewegung = .rennt
        e.akku = 0.05
        e.fokus = "schlafen"
        e.stimmung = "schlecht"
        e.brauche = "ruhe"
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .herz)
    }

    func testTipptSchlaegtGym() {
        var e = FigurEingabe(person: .annika, jetzt: berlin(10, 3, 14))
        e.app = .tippt
        e.ort = .gym
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .tippt)
    }

    func testOfflineSchlaegtOrt() {
        var e = FigurEingabe(person: .annika, jetzt: berlin(10, 3, 14))
        e.ort = .zuhause
        e.bewegung = .laeuft
        e.online = false
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .offline)
    }

    func testGeburtstagAnnikaPartyhut() {
        // 00:30 in Berlin is still 05.06. in UTC, so this fails if the calendar is not Europe/Berlin.
        let datum = berlin(6, 6, 0, 30)
        XCTAssertTrue(FigurZustand.bestimmen(FigurEingabe(person: .annika, jetzt: datum)).abzeichen.contains("partyhut"))
        XCTAssertFalse(FigurZustand.bestimmen(FigurEingabe(person: .ahmed, jetzt: datum)).abzeichen.contains("partyhut"))
    }
    // MARK: Aussehen v2

    private struct AltesAussehen: Decodable {
        let haut, frisur, haarfarbe, augen, brille, bart, oberteil, oberteilfarbe: Int
    }

    func testAltesAussehenDekodiert() throws {
        let json = #"{"haut":3,"frisur":0,"haarfarbe":0,"augen":0,"brille":0,"bart":1,"oberteil":1,"oberteilfarbe":0}"#
        let a = try JSONDecoder().decode(FigurAussehen.self, from: Data(json.utf8))
        XCTAssertEqual(a.haut, 3)
        XCTAssertEqual(a.bart, 1)
        XCTAssertEqual(a.oberteil, 1)
        XCTAssertEqual(a.gesichtsform, 0)
        XCTAssertEqual(a.jacke, 0)
        XCTAssertEqual(a.hose, FigurAussehen().hose)
        XCTAssertEqual(a.koerperform, 1)
        XCTAssertFalse(a.wimpern)
    }

    func testNeuesAussehenRundreise() throws {
        for p in [Person.ahmed, .annika] {
            let a = FigurAussehen.standard(for: p)
            XCTAssertEqual(try JSONDecoder().decode(FigurAussehen.self, from: JSONEncoder().encode(a)), a)
        }
    }

    func testAlteAppLiestNeuesAussehen() throws {
        let neu = FigurAussehen.standard(for: .ahmed)
        let alt = try JSONDecoder().decode(AltesAussehen.self, from: JSONEncoder().encode(neu))
        XCTAssertEqual(alt.frisur, neu.frisur)
        XCTAssertEqual(alt.bart, neu.bart)
    }

    func testOptionenAnzahl() {
        typealias A = FigurAussehen
        XCTAssertEqual(A.gesichtsformen.count, 6)
        XCTAssertGreaterThanOrEqual(A.hautToene.count, 12)
        XCTAssertGreaterThanOrEqual(A.augenformen.count, 8)
        XCTAssertGreaterThanOrEqual(A.augenfarben.count, 8)
        XCTAssertGreaterThanOrEqual(A.augenbrauen.count, 8)
        XCTAssertGreaterThanOrEqual(A.nasen.count, 6)
        XCTAssertGreaterThanOrEqual(A.muender.count, 8)
        XCTAssertGreaterThanOrEqual(A.frisuren.count, 30)
        XCTAssertGreaterThanOrEqual(A.haarfarben.count, 14)
        XCTAssertTrue(A.haarfarben.contains { $0.straehne != nil })
        XCTAssertGreaterThanOrEqual(A.baerte.count - 1, 8)
        XCTAssertGreaterThanOrEqual(A.brillen.count - 1, 7)
        XCTAssertGreaterThanOrEqual(A.kopfbedeckungen.count, 3)
        XCTAssertGreaterThanOrEqual(A.oberteile.count, 12)
        XCTAssertGreaterThanOrEqual(A.jacken.count - 1, 5)
        XCTAssertGreaterThanOrEqual(A.hosen.count, 8)
        XCTAssertGreaterThanOrEqual(A.schuhArten.count, 6)
        XCTAssertGreaterThanOrEqual(A.farben.count, 16)
        XCTAssertEqual(A.koerperformen.count, 3)
        XCTAssertEqual(A.groessen.count, 3)
    }

    func testStandardFiguren() {
        let ahmed = FigurAussehen.standard(for: .ahmed)
        XCTAssertGreaterThan(ahmed.bart, 0)
        XCTAssertEqual(FigurAussehen.oberteile[ahmed.oberteil], "Hoodie")
        let annika = FigurAussehen.standard(for: .annika)
        XCTAssertEqual(FigurAussehen.frisuren[annika.frisur], "Lang glatt")
        XCTAssertEqual(FigurAussehen.jacken[annika.jacke], "Lederjacke")
        XCTAssertTrue(FigurAussehen.hosen[annika.hose].contains("Jeans"))
    }
}
