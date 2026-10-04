import XCTest
@testable import Lovea

@MainActor
final class DateSpeicherTests: XCTestCase {
    private final class Gesendet { var ops: [Op] = [] }

    private let t0 = Date(timeIntervalSince1970: 1_791_100_000)

    private func speicher(_ ich: Person = .ahmed, _ ziel: Gesendet = Gesendet(), uhr: @escaping () -> Date) -> DateSpeicher {
        let merker = UserDefaults(suiteName: "dates-test-" + UUID().uuidString)!
        return DateSpeicher(ich: { ich }, senden: { ziel.ops.append($0) }, jetzt: uhr, merker: merker)
    }

    private func idee(_ id: String, _ titel: String, _ zeit: Double, von: Person = .ahmed) -> DateIdee {
        DateIdee(id: id, titel: titel, kategorie: .essen, geaendert: Date(timeIntervalSince1970: zeit), von: von)
    }

    private func op(_ idee: DateIdee) -> Op { Op.neu(DateSpeicher.art, idee, von: idee.von) }

    // MARK: - LWW

    func testNeuereFassungGewinntInBeidenReihenfolgen() {
        let alt = op(idee("a", "Alt", 100))
        let neu = op(idee("a", "Neu", 200, von: .annika))
        XCTAssertEqual(DateSpeicher.anwenden([alt, neu]).ideen["a"]?.titel, "Neu")
        XCTAssertEqual(DateSpeicher.anwenden([neu, alt]).ideen["a"]?.titel, "Neu")
        XCTAssertEqual(DateSpeicher.anwenden([neu, alt]).ideen["a"]?.von, .annika)
    }

    func testDoppelteZustellungAendertNichts() {
        let o = op(idee("a", "A", 100))
        XCTAssertEqual(DateSpeicher.anwenden([o, o, o]), DateSpeicher.anwenden([o]))
    }

    func testOpRundreiseBehaeltAlleFelder() throws {
        var i = idee("a", "A", 123.456)
        i.erledigt = true
        i.erledigtAm = "2026-10-04"
        i.ort = PunktOrt(name: "Wildpark", lat: 51.2, lon: 6.8, adresse: "Düsseldorf")
        i.links = [DateLink(id: "l", url: "https://example.com", titel: "x")]
        i.notiz = "n"
        let zurueck = try XCTUnwrap(op(i).daten(DateIdee.self))
        XCTAssertEqual(zurueck.id, i.id)
        XCTAssertEqual(zurueck.ort, i.ort)
        XCTAssertEqual(zurueck.links, i.links)
        XCTAssertEqual(zurueck.erledigtAm, "2026-10-04")
        XCTAssertEqual(zurueck.geaendert.timeIntervalSince1970, 123.456, accuracy: 0.001)
    }

    // MARK: - Löschen und Rückgängig

    func testLoeschenUndRueckgaengig() throws {
        var uhr = t0
        let ziel = Gesendet()
        let s = speicher(.ahmed, ziel, uhr: { uhr })
        let angelegt = try XCTUnwrap(s.anlegen(titel: "  Sternschnuppen  ", kategorie: .draussen))
        XCTAssertEqual(angelegt.titel, "Sternschnuppen")
        XCTAssertEqual(s.ideen.count, 1)

        uhr = t0.addingTimeInterval(10)
        s.loeschen(angelegt.id)
        XCTAssertTrue(s.ideen.isEmpty)
        XCTAssertEqual(s.zustand.ideen[angelegt.id]?.geloescht, true)

        uhr = t0.addingTimeInterval(20)
        s.rueckgaengig(angelegt.id)
        XCTAssertEqual(s.ideen.map(\.id), [angelegt.id])
        XCTAssertEqual(ziel.ops.count, 3)
        let stempel = ziel.ops.compactMap { $0.daten(DateIdee.self)?.geaendert }
        XCTAssertEqual(stempel, stempel.sorted())
        XCTAssertEqual(Set(stempel).count, 3)
    }

    func testRueckgaengigGewinntGegenLoeschungBeimPartner() {
        let basis = idee("a", "A", 100)
        let geloescht = DateLogik.geloescht(basis, von: .annika, jetzt: Date(timeIntervalSince1970: 200))
        let zurueck = DateLogik.wiederhergestellt(geloescht, von: .ahmed, jetzt: Date(timeIntervalSince1970: 300))
        let z = DateSpeicher.anwenden([op(zurueck), op(geloescht), op(basis)])
        XCTAssertEqual(z.ideen["a"]?.geloescht, false)
        XCTAssertEqual(z.sichtbar.count, 1)
    }

    func testLoeschungMitRueckwaertsLaufenderUhrVerliertNicht() {
        let basis = idee("a", "A", 1000)
        let geloescht = DateLogik.geloescht(basis, von: .ahmed, jetzt: Date(timeIntervalSince1970: 500))
        XCTAssertGreaterThan(geloescht.geaendert, basis.geaendert)
        XCTAssertTrue(DateSpeicher.anwenden([op(basis), op(geloescht)]).sichtbar.isEmpty)
    }

    func testLoeschenOhnePersonOderUnbekannteIdeeSendetNichts() {
        let ziel = Gesendet()
        let s = DateSpeicher(ich: { nil }, senden: { ziel.ops.append($0) }, merker: UserDefaults(suiteName: "dates-test-" + UUID().uuidString)!)
        XCTAssertNil(s.anlegen(titel: "X", kategorie: .essen))
        s.loeschen("gibt-es-nicht")
        s.rueckgaengig("gibt-es-nicht")
        XCTAssertTrue(ziel.ops.isEmpty)
        let s2 = speicher(uhr: { self.t0 })
        XCTAssertNil(s2.anlegen(titel: "   ", kategorie: .essen))
    }

    func testAbhakenSetztUndLoeschtDatum() throws {
        var uhr = t0
        let s = speicher(uhr: { uhr })
        let i = try XCTUnwrap(s.anlegen(titel: "Kino", kategorie: .aktivitaet))
        uhr = t0.addingTimeInterval(5)
        s.abhaken(i.id, erledigt: true)
        XCTAssertEqual(s.zustand.ideen[i.id]?.erledigt, true)
        XCTAssertEqual(s.zustand.ideen[i.id]?.erledigtAm, Datum.text(uhr))
        uhr = t0.addingTimeInterval(9)
        s.abhaken(i.id, erledigt: false)
        XCTAssertEqual(s.zustand.ideen[i.id]?.erledigt, false)
        XCTAssertNil(s.zustand.ideen[i.id]?.erledigtAm)
    }

    func testBeidePersonenSehenDasselbe() throws {
        let ahmedOps = Gesendet(), annikaOps = Gesendet()
        var uhr = t0
        let ahmed = speicher(.ahmed, ahmedOps, uhr: { uhr })
        let annika = speicher(.annika, annikaOps, uhr: { uhr })
        let i = try XCTUnwrap(ahmed.anlegen(titel: "Sterne", kategorie: .draussen))
        annika.einarbeiten(ahmedOps.ops)
        uhr = t0.addingTimeInterval(30)
        annika.abhaken(i.id, erledigt: true)
        ahmed.einarbeiten(annikaOps.ops)
        XCTAssertEqual(ahmed.zustand, annika.zustand)
        XCTAssertEqual(ahmed.zustand.ideen[i.id]?.erledigt, true)
        XCTAssertEqual(ahmed.zustand.ideen[i.id]?.von, .annika)
    }

    // MARK: - Startdaten

    func testStartdatenEinmalMitFestenIDs() {
        let ziel = Gesendet()
        let s = speicher(.ahmed, ziel, uhr: { self.t0 })
        s.startdatenSenden()
        XCTAssertEqual(ziel.ops.count, 61)
        XCTAssertEqual(s.ideen.count, 61)
        s.startdatenSenden()
        XCTAssertEqual(ziel.ops.count, 61, "zweiter Aufruf darf nichts senden")
    }

    func testZweiGeraeteErzeugenKeinDuplikat() {
        let a = Gesendet(), b = Gesendet()
        let ahmed = speicher(.ahmed, a, uhr: { self.t0 })
        let annika = speicher(.annika, b, uhr: { self.t0 })
        ahmed.startdatenSenden()
        annika.startdatenSenden()
        let neu = speicher(uhr: { self.t0 })
        neu.einarbeiten(a.ops + b.ops)
        XCTAssertEqual(neu.zustand.ideen.count, 61)
        XCTAssertEqual(neu.zustand, DateSpeicher.anwenden(a.ops))
        XCTAssertEqual(neu.ideen.filter(\.erledigt).map(\.id), ["start-nordpark-japanischer-garten"])
    }

    func testSpaetEintreffendeStartfassungUeberschreibtKeineAenderung() throws {
        let a = Gesendet(), b = Gesendet()
        let ahmed = speicher(.ahmed, a, uhr: { self.t0 })
        let annika = speicher(.annika, b, uhr: { self.t0 })
        ahmed.startdatenSenden()
        annika.einarbeiten(a.ops)
        annika.abhaken("start-kino", erledigt: true)
        annika.loeschen("start-zoo")
        // Annikas Startdaten kommen erst nach ihren Änderungen am Handy von Ahmed an.
        let c = Gesendet()
        let spaet = speicher(.annika, c, uhr: { self.t0 })
        spaet.startdatenSenden()
        let ziel = speicher(uhr: { self.t0 })
        ziel.einarbeiten(a.ops + b.ops + c.ops)
        XCTAssertEqual(ziel.zustand.ideen["start-kino"]?.erledigt, true)
        XCTAssertEqual(ziel.zustand.ideen["start-zoo"]?.geloescht, true)
        XCTAssertEqual(ziel.ideen.count, 60)
    }

    func testGeloeschteStartideeKommtNichtZurueck() {
        let ziel = Gesendet()
        let s = speicher(.ahmed, ziel, uhr: { self.t0 })
        s.einarbeiten([op(DateLogik.geloescht(DateStartdaten.ideen[0], von: .annika, jetzt: t0))])
        s.startdatenSenden()
        XCTAssertEqual(ziel.ops.count, 60)
        XCTAssertEqual(s.ideen.count, 60)
    }

    // MARK: - Alter Op-Stand

    func testAlterOpStandOhneDatesBrichtNicht() {
        let alt = [
            Op.neu("muster.setzen", ["id": "m1"], von: .ahmed),
            Op.neu("treffen.setzen", ["datum": "2026-10-01"], von: .annika),
            Op.neu("dates.zukunft", ["x": 1], von: .ahmed),
            Op.neu(DateSpeicher.art, ["kaputt": true], von: .ahmed),
        ]
        let z = DateSpeicher.anwenden(alt)
        XCTAssertTrue(z.ideen.isEmpty)
        let s = speicher(uhr: { self.t0 })
        s.einarbeiten(alt)
        XCTAssertTrue(s.ideen.isEmpty)
    }

    func testOpLogRundreiseLiefertStand() async throws {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("dates-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: ordner) }
        let log = OpLog(rootURL: ordner)
        var ops = [op(idee("a", "Alt", 100)), op(idee("a", "Neu", 200, von: .annika)), op(idee("b", "B", 50))]
        ops.append(Op.neu("muster.setzen", ["id": "m1"], von: .ahmed))
        for i in ops.indices { ops[i].seq = i + 1 }
        await log.anhaengen(ops)
        let neuerLog = OpLog(rootURL: ordner)
        let geladen = await neuerLog.alle(arten: [DateSpeicher.art])
        XCTAssertEqual(geladen.count, 3)
        let z = DateSpeicher.anwenden(geladen)
        XCTAssertEqual(z.ideen["a"]?.titel, "Neu")
        XCTAssertEqual(z.ideen["b"]?.titel, "B")
    }
}
