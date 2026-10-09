import XCTest
@testable import Lovea

/// Reine Einkaufslisten-Logik: Sortierung, Duplikate, Faltung mit neuester gewinnt und "erstellt von".
final class EinkaufTests: XCTestCase {
    private func op(_ art: String, _ d: some Encodable, von: Person = .ahmed, sekunde: Double) throws -> Op {
        Op(id: UUID().uuidString, seq: nil, art: art, von: von, zeit: Date(timeIntervalSince1970: sekunde), d: try JSONEncoder().encode(d))
    }

    // MARK: - Logik

    func testSortiertOffeneZuerstNachReihenfolge() {
        let a = EinkaufEintrag(id: "a", liste: "l", text: "Milch", menge: nil, erledigt: false, reihenfolge: 2, geloescht: nil)
        let b = EinkaufEintrag(id: "b", liste: "l", text: "Brot", menge: nil, erledigt: false, reihenfolge: 1, geloescht: nil)
        let c = EinkaufEintrag(id: "c", liste: "l", text: "Butter", menge: nil, erledigt: true, reihenfolge: 0, geloescht: nil)
        let sortiert = EinkaufLogik.sortiert([a, b, c])
        XCTAssertEqual(sortiert.map(\.id), ["b", "a", "c"])
    }

    func testGleicherTextOhneGrossKleinUndLeerraum() {
        XCTAssertTrue(EinkaufLogik.gleicherText("Milch", " milch "))
        XCTAssertFalse(EinkaufLogik.gleicherText("Milch", "Buttermilch"))
    }

    func testNaechsteReihenfolge() {
        XCTAssertEqual(EinkaufLogik.naechsteReihenfolge([]), 1)
        let e = EinkaufEintrag(id: "a", liste: "l", text: "Milch", menge: nil, erledigt: false, reihenfolge: 3, geloescht: nil)
        XCTAssertEqual(EinkaufLogik.naechsteReihenfolge([e]), 4)
    }

    // MARK: - Faltung

    func testNeuesteGewinntUndLoeschen() throws {
        var f = EinkaufFaltung()
        let e = EinkaufEintrag(id: "e", liste: "l", text: "Milch", menge: "1 l", erledigt: false, reihenfolge: 1, geloescht: nil)
        var erledigt = e
        erledigt.erledigt = true
        var weg = e
        weg.geloescht = true
        f.anwenden(try op("einkauf.eintrag", erledigt, sekunde: 20))
        f.anwenden(try op("einkauf.eintrag", e, sekunde: 10))
        XCTAssertEqual(f.eintraege("l").first?.erledigt, true)
        f.anwenden(try op("einkauf.eintrag", weg, sekunde: 30))
        XCTAssertTrue(f.eintraege("l").isEmpty)
    }

    func testListenNeuesteGewinntUndGeloeschteFallenRaus() throws {
        var f = EinkaufFaltung()
        f.anwenden(try op("einkauf.liste", EinkaufListe(id: "l", name: "Einkauf", geloescht: nil), sekunde: 1))
        f.anwenden(try op("einkauf.liste", EinkaufListe(id: "l", name: "Wocheneinkauf", geloescht: nil), sekunde: 2))
        XCTAssertEqual(f.liste("l")?.name, "Wocheneinkauf")
        XCTAssertEqual(f.listen.map(\.name), ["Wocheneinkauf"])
        f.anwenden(try op("einkauf.liste", EinkaufListe(id: "l", name: "Wocheneinkauf", geloescht: true), sekunde: 3))
        XCTAssertTrue(f.listen.isEmpty)
    }

    /// Annika legt an, Ahmed ändert später nur die Menge: der Eintrag bleibt "von Annika".
    func testErstelltVonBleibtBeimErstenAnleger() throws {
        var f = EinkaufFaltung()
        let e = EinkaufEintrag(id: "e", liste: "l", text: "Milch", menge: nil, erledigt: false, reihenfolge: 1, geloescht: nil)
        var geaendert = e
        geaendert.menge = "2 l"
        f.anwenden(try op("einkauf.eintrag", e, von: .annika, sekunde: 10))
        f.anwenden(try op("einkauf.eintrag", geaendert, von: .ahmed, sekunde: 20))
        XCTAssertEqual(f.erstelltVon("e"), .annika)
        XCTAssertEqual(f.eintraege("l").first?.menge, "2 l")
    }

    /// Kommt die anlegende Op verspätet an (kleinere Zeit als eine schon verarbeitete Änderung), zählt trotzdem sie als Anlegerin.
    func testErstelltVonAuchBeiVerspaeteterAnlegeOp() throws {
        var f = EinkaufFaltung()
        let e = EinkaufEintrag(id: "e", liste: "l", text: "Milch", menge: nil, erledigt: false, reihenfolge: 1, geloescht: nil)
        var geaendert = e
        geaendert.menge = "2 l"
        f.anwenden(try op("einkauf.eintrag", geaendert, von: .ahmed, sekunde: 20))
        f.anwenden(try op("einkauf.eintrag", e, von: .annika, sekunde: 10))
        XCTAssertEqual(f.erstelltVon("e"), .annika)
        XCTAssertEqual(f.eintraege("l").first?.menge, "2 l")
    }
}
