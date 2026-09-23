import XCTest
@testable import Lovea

/// Pure selection logic (Z-26.4). `UmzugAufraeumen` itself needs `Raum`/network/disk, same as
/// `UmzugImport` — only `UmzugMigrationLogik` is covered directly here.
@MainActor
final class UmzugAufraeumenTests: XCTestCase {
    func testAuszuraeumenFiltertNurEigeneUnverarbeiteteUmzugZeichnungen() {
        let eigene = ChatModell.Nachricht(id: "umzug:zeichnung/1", von: .ahmed, zeit: Date())
        let partner = ChatModell.Nachricht(id: "umzug:zeichnung/2", von: .annika, zeit: Date())
        let normal = ChatModell.Nachricht(id: "m1", von: .ahmed, zeit: Date(), text: "hallo")
        let geloescht = ChatModell.Nachricht(id: "umzug:zeichnung/3", von: .ahmed, zeit: Date(), geloescht: true)

        let ausgewaehlt = UmzugMigrationLogik.auszuraeumen([eigene, partner, normal, geloescht], ich: .ahmed)

        XCTAssertEqual(ausgewaehlt.map(\.id), ["umzug:zeichnung/1"])
    }

    func testAuszuraeumenIstLeerOhneTreffer() {
        XCTAssertTrue(UmzugMigrationLogik.auszuraeumen([], ich: .ahmed).isEmpty)
    }

    // MARK: - ChatModell: umzug:zeichnung/ messages vanish outright on delete (Z-26.4)

    func testUmzugZeichnungVerschwindetKomplettStattNachrichtGeloescht() {
        let modell = ChatModell(registrieren: false)
        let neu = Op.neu("nachricht.neu", NachrichtPayload(id: "umzug:zeichnung/1", text: nil), von: .ahmed)
        modell.anwenden([Op(id: neu.id, seq: 1, art: neu.art, von: .ahmed, zeit: Date(), d: neu.d)])
        XCTAssertEqual(modell.nachrichten.count, 1)

        let loeschen = Op.neu("nachricht.geloescht", IDPayloadForTests(id: "umzug:zeichnung/1"), von: .ahmed)
        modell.anwenden([Op(id: loeschen.id, seq: 2, art: loeschen.art, von: .ahmed, zeit: Date(), d: loeschen.d)])

        XCTAssertTrue(modell.nachrichten.isEmpty, "an umzug:zeichnung/ row disappears outright, not as a 'Nachricht gelöscht' spur")
    }

    func testNormaleNachrichtBleibtAlsGeloeschtMarkiert() {
        let modell = ChatModell(registrieren: false)
        let neu = Op.neu("nachricht.neu", NachrichtPayload(id: "m1", text: "hi"), von: .ahmed)
        modell.anwenden([Op(id: neu.id, seq: 1, art: neu.art, von: .ahmed, zeit: Date(), d: neu.d)])
        modell.anwenden([Op.neu("nachricht.geloescht", IDPayloadForTests(id: "m1"), von: .ahmed)])

        XCTAssertEqual(modell.nachrichten.count, 1)
        XCTAssertEqual(modell.nachrichten.first?.geloescht, true)
    }
}

private struct NachrichtPayload: Encodable { let id: String; let text: String? }
private struct IDPayloadForTests: Encodable { let id: String }
