import XCTest
@testable import Lovea

/// Reine Fasten-Logik: Faltung (neueste gewinnt, Löschen), Serie über Mitternacht, geplantes Ende,
/// geschafft/nicht geschafft.
final class FastenTests: XCTestCase {
    private func op(_ art: String, _ d: some Encodable, von: Person = .ahmed, sekunde: Double) throws -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(timeIntervalSince1970: sekunde), d: try JSONEncoder().encode(d))
    }

    /// `tag` als "yyyy-MM-dd" plus Uhrzeit, in Europe/Berlin wie der Rest des Kalenders.
    private func zeitpunkt(_ tag: String, _ stunde: Int, _ minute: Int) -> Date {
        var teile = Datum.kalender.dateComponents([.year, .month, .day], from: Datum.datum(tag))
        teile.hour = stunde
        teile.minute = minute
        return Datum.kalender.date(from: teile)!
    }

    // MARK: - Faltung

    func testNeuesteGewinntUndLoeschen() throws {
        var f = FastenFaltung()
        let start = zeitpunkt("2026-09-20", 20, 0)
        let laufend = FastenEintrag(id: "f1", start: start, ende: nil, plan: FastenPlan.sechzehn.rawValue, geloescht: nil)
        var beendet = laufend
        beendet.ende = start.addingTimeInterval(16 * 3600)

        // Später gesendet, aber früherer Zeitstempel: die spätere Version (beendet) muss gewinnen.
        f.anwenden(try op("fasten.eintrag", beendet, sekunde: 20))
        f.anwenden(try op("fasten.eintrag", laufend, sekunde: 10))
        XCTAssertEqual(f.eintraege(.ahmed).first?.ende, beendet.ende)
        XCTAssertNil(f.laufend(.ahmed))
        XCTAssertTrue(f.eintraege(.annika).isEmpty)

        var weg = beendet
        weg.geloescht = true
        f.anwenden(try op("fasten.eintrag", weg, sekunde: 30))
        XCTAssertTrue(f.eintraege(.ahmed).isEmpty)
    }

    func testPlanNeuesterGewinntProPerson() throws {
        var f = FastenFaltung()
        f.anwenden(try op("fasten.plan", FastenPlanD(plan: FastenPlan.omad.rawValue), sekunde: 10))
        f.anwenden(try op("fasten.plan", FastenPlanD(plan: FastenPlan.sechzehn.rawValue), sekunde: 20))
        XCTAssertEqual(f.plan(.ahmed), .sechzehn)
        XCTAssertEqual(f.plan(.annika), .standard)
    }

    // MARK: - Geplantes Ende

    func testGeplantesEndeBei16zu8() {
        let start = zeitpunkt("2026-09-27", 20, 0)
        let ende = FastenLogik.geplantesEnde(start: start, plan: .sechzehn)
        XCTAssertEqual(ende.timeIntervalSince(start), 16 * 3600, accuracy: 0.001)
        XCTAssertEqual(Datum.kalender.component(.hour, from: ende), 12)
    }

    // MARK: - Geschafft

    func testGeschafftUndNichtGeschafft() {
        let start = zeitpunkt("2026-09-27", 8, 0)
        var e = FastenEintrag(id: "1", start: start, ende: start.addingTimeInterval(16 * 3600), plan: FastenPlan.sechzehn.rawValue, geloescht: nil)
        XCTAssertTrue(FastenLogik.geschafft(e))

        e.ende = start.addingTimeInterval(15 * 3600 + 59 * 60)
        XCTAssertFalse(FastenLogik.geschafft(e))

        e.ende = nil
        XCTAssertFalse(FastenLogik.geschafft(e), "läuft noch, also nicht geschafft")
    }

    // MARK: - Serie

    /// Zwei 16-Stunden-Fasten, jedes über Mitternacht (Start abends, Ende am nächsten Tag): die
    /// Serie zählt nach dem Start-Tag und ergibt zwei Tage in Folge, nicht null oder drei.
    func testSerieUeberTagesgrenze() throws {
        var f = FastenFaltung()
        let start1 = zeitpunkt("2026-09-25", 22, 0)
        let ende1 = zeitpunkt("2026-09-26", 14, 0)
        let start2 = zeitpunkt("2026-09-26", 20, 0)
        let ende2 = zeitpunkt("2026-09-27", 12, 0)
        let e1 = FastenEintrag(id: "1", start: start1, ende: ende1, plan: FastenPlan.sechzehn.rawValue, geloescht: nil)
        let e2 = FastenEintrag(id: "2", start: start2, ende: ende2, plan: FastenPlan.sechzehn.rawValue, geloescht: nil)
        f.anwenden(try op("fasten.eintrag", e1, sekunde: 1))
        f.anwenden(try op("fasten.eintrag", e2, sekunde: 2))
        XCTAssertEqual(FastenLogik.serie(f.eintraege(.ahmed)), 2)

        // Ein drittes, zu kurzes Fasten am jüngsten Tag bricht die Serie wieder auf null.
        let start3 = zeitpunkt("2026-09-27", 20, 0)
        let ende3 = zeitpunkt("2026-09-27", 22, 0)
        let e3 = FastenEintrag(id: "3", start: start3, ende: ende3, plan: FastenPlan.sechzehn.rawValue, geloescht: nil)
        f.anwenden(try op("fasten.eintrag", e3, sekunde: 3))
        XCTAssertEqual(FastenLogik.serie(f.eintraege(.ahmed)), 0)
    }

    func testDurchschnittUndLaengstes() {
        let start = zeitpunkt("2026-09-20", 20, 0)
        let eintraege = [
            FastenEintrag(id: "1", start: start, ende: start.addingTimeInterval(16 * 3600), plan: FastenPlan.sechzehn.rawValue, geloescht: nil),
            FastenEintrag(id: "2", start: start, ende: start.addingTimeInterval(20 * 3600), plan: FastenPlan.sechzehn.rawValue, geloescht: nil),
            FastenEintrag(id: "3", start: start, ende: nil, plan: FastenPlan.sechzehn.rawValue, geloescht: nil),
        ]
        let beendete = FastenLogik.beendete(eintraege)
        XCTAssertEqual(beendete.count, 2)
        XCTAssertEqual(FastenLogik.durchschnittStunden(beendete), 18, accuracy: 0.001)
        XCTAssertEqual(FastenLogik.laengstesStunden(beendete), 20, accuracy: 0.001)
    }
}
