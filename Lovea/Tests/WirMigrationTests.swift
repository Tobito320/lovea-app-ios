import XCTest
@testable import Lovea

@MainActor
final class WirMigrationTests: XCTestCase {
    private struct ListeAltD: Encodable { var id: String; var text: String; var geschafft: Bool }

    private func alt(_ id: String, _ text: String, geschafft: Bool = false, von: Person = .ahmed) -> Op {
        Op.neu("liste.setzen", ListeAltD(id: id, text: text, geschafft: geschafft), von: von)
    }

    private func migrieren(_ alteOps: [Op]) -> (alt: [Op], neu: [Op], plan: [WirMigration.Schritt]) {
        let plan = WirMigration.plan(WirModell.anwenden(alteOps).liste)
        return (alteOps, WirMigration.ops(plan, von: .ahmed), plan)
    }

    private let lang = String(repeating: "Wir fahren zusammen ans Meer und bleiben so lange wie moeglich. ", count: 3)

    // MARK: - Nichts geht verloren

    func testAlleEintraegeLandenAlsIdeeOderNotiz() {
        let ops = [
            alt("a", "Kino"), alt("b", "Picknick am See", geschafft: true, von: .annika),
            alt("c", lang), alt("d", "Zeile eins\nZeile zwei"),
        ]
        let m = migrieren(ops)
        let ideen = DateSpeicher.anwenden(m.neu).sichtbar
        let notizen = WirNotizLogik.sichtbar(WirNotizLogik.anwenden(m.neu))
        XCTAssertEqual(ideen.count + notizen.count, 4)
        XCTAssertEqual(Set(ideen.map(\.titel)), ["Kino", "Picknick am See"])
        XCTAssertEqual(Set(notizen.map(\.text)), [lang.trimmingCharacters(in: .whitespaces), "Zeile eins\nZeile zwei"])
    }

    func testGeschafftWirdErledigtUndAutorBleibt() throws {
        let m = migrieren([alt("a", "Kino"), alt("b", "Zoo", geschafft: true, von: .annika)])
        let ideen = DateSpeicher.anwenden(m.neu).ideen
        XCTAssertEqual(try XCTUnwrap(ideen[WirMigration.ideeId("a")]).erledigt, false)
        let zoo = try XCTUnwrap(ideen[WirMigration.ideeId("b")])
        XCTAssertTrue(zoo.erledigt)
        XCTAssertEqual(zoo.von, .annika)
        XCTAssertFalse(zoo.geloescht)
    }

    func testGeschafftLangerEintragBehaeltDenHinweisInDerNotiz() throws {
        let m = migrieren([alt("a", lang, geschafft: true)])
        let notiz = try XCTUnwrap(WirNotizLogik.anwenden(m.neu)[WirMigration.notizId("a")])
        XCTAssertTrue(notiz.text.hasSuffix("(geschafft)"))
        XCTAssertTrue(notiz.text.hasPrefix("Wir fahren"))
    }

    func testListeIstNachDerMigrationLeerUndDieAltenOpsFaltenWeiter() {
        let m = migrieren([alt("a", "Kino"), alt("b", lang)])
        XCTAssertEqual(WirModell.anwenden(m.alt).liste.count, 2)
        XCTAssertTrue(WirModell.anwenden(m.alt + m.neu).liste.isEmpty)
        // Nach der Migration findet ein weiterer Lauf nichts mehr.
        XCTAssertTrue(WirMigration.plan(WirModell.anwenden(m.alt + m.neu).liste).isEmpty)
    }

    func testEintragOhneTextBleibtInDerListeStehen() {
        let m = migrieren([alt("a", "   "), alt("b", "Kino")])
        XCTAssertEqual(m.plan.map(\.listenId), ["b"])
        XCTAssertEqual(WirModell.anwenden(m.alt + m.neu).liste.map(\.id), ["a"])
    }

    // MARK: - Sync

    func testNeueOpsFaltenBeiAltemUnbekanntemStandFolgenlos() {
        // Ein Handy ohne Notizen und Dates faltet nur die Wir-Arten: dort kommt nur `liste.loeschen` an.
        let m = migrieren([alt("a", "Kino")])
        let nurWir = m.neu.filter { WirModell.arten.contains($0.art) }
        XCTAssertEqual(nurWir.map(\.art), ["liste.loeschen"])
        XCTAssertTrue(WirModell.anwenden(m.alt + nurWir).liste.isEmpty)
    }

    func testZweiHandysOderZweiLaeufeErzeugenKeinDuplikat() {
        let a = migrieren([alt("a", "Kino"), alt("b", lang)])
        let b = migrieren([alt("a", "Kino"), alt("b", lang)])
        let ideen = DateSpeicher.anwenden(a.neu + b.neu)
        let notizen = WirNotizLogik.anwenden(a.neu + b.neu)
        XCTAssertEqual(ideen.sichtbar.count, 1)
        XCTAssertEqual(notizen.count, 1)
        XCTAssertEqual(ideen, DateSpeicher.anwenden(a.neu))
        XCTAssertTrue(WirModell.anwenden(a.alt + a.neu + b.neu).liste.isEmpty)
    }

    func testSpaetereAenderungGewinntGegenSpaetEintreffendeMigration() throws {
        let m = migrieren([alt("a", "Kino")])
        var idee = try XCTUnwrap(DateSpeicher.anwenden(m.neu).ideen[WirMigration.ideeId("a")])
        idee.geloescht = true
        idee.geaendert = WirMigration.stempel.addingTimeInterval(60)
        let geloescht = Op.neu(DateSpeicher.art, idee, von: .annika)
        // Löschung zuerst, Migration des anderen Handys danach: bleibt gelöscht.
        XCTAssertTrue(DateSpeicher.anwenden([geloescht] + m.neu).sichtbar.isEmpty)
        XCTAssertTrue(DateSpeicher.anwenden(m.neu + [geloescht]).sichtbar.isEmpty)
    }

    func testAltesHandySchreibtSpaeterNochInDieListe() {
        let m = migrieren([alt("a", "Kino")])
        let spaet = alt("z", "Bowling", von: .annika)
        let liste = WirModell.anwenden(m.alt + m.neu + [spaet]).liste
        XCTAssertEqual(liste.map(\.id), ["z"])
        XCTAssertEqual(WirMigration.plan(liste).map(\.listenId), ["z"])
    }

    func testOpsSindReihenfolgeNeuesVorLoeschen() {
        let m = migrieren([alt("a", "Kino"), alt("b", lang)])
        XCTAssertEqual(m.neu.map(\.art), [DateSpeicher.art, "liste.loeschen", WirNotizLogik.art, "liste.loeschen"])
    }

    // MARK: - Notizen

    private final class Gesendet { var ops: [Op] = [] }

    func testNotizSpeicherAnlegenAendernLoeschen() throws {
        var uhr = Date(timeIntervalSince1970: 1_791_500_000)
        let ziel = Gesendet()
        let s = WirNotizSpeicher(ich: { .annika }, senden: { ziel.ops.append($0) }, jetzt: { uhr })
        XCTAssertNil(s.anlegen("   "))
        let n = try XCTUnwrap(s.anlegen("  Hotel buchen "))
        XCTAssertEqual(n.text, "Hotel buchen")
        uhr = uhr.addingTimeInterval(10)
        s.aendern(n.id, text: "Hotel in Paris buchen")
        XCTAssertEqual(s.notizen.map(\.text), ["Hotel in Paris buchen"])
        uhr = uhr.addingTimeInterval(10)
        s.loeschen(n.id)
        XCTAssertTrue(s.notizen.isEmpty)
        XCTAssertEqual(ziel.ops.map(\.art), Array(repeating: WirNotizLogik.art, count: 3))
        // Das Partner-Handy faltet dieselben Ops zum selben Stand.
        XCTAssertEqual(WirNotizLogik.anwenden(ziel.ops), WirNotizLogik.anwenden(Array(ziel.ops.reversed())))
        XCTAssertEqual(WirNotizLogik.anwenden(ziel.ops)[n.id]?.geloescht, true)
    }

    func testNotizNeuereFassungGewinntInBeidenReihenfolgen() {
        let a = Op.neu(WirNotizLogik.art, WirNotiz(id: "n", text: "Alt", geaendert: Date(timeIntervalSince1970: 100), von: .ahmed), von: .ahmed)
        let b = Op.neu(WirNotizLogik.art, WirNotiz(id: "n", text: "Neu", geaendert: Date(timeIntervalSince1970: 200), von: .annika), von: .annika)
        XCTAssertEqual(WirNotizLogik.anwenden([a, b])["n"]?.text, "Neu")
        XCTAssertEqual(WirNotizLogik.anwenden([b, a])["n"]?.text, "Neu")
    }
}
