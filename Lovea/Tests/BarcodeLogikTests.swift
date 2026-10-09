import XCTest
@testable import Lovea

final class BarcodeLogikTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-4311501679715", name: "Skyr", barcode: "4311501679715",
                                    pro100: Naehrwerte(kcal: 65, protein: 11, kohlenhydrate: 4, fett: 0.2))

    func testNormal() {
        XCTAssertEqual(BarcodeLogik.normal(" 4311501679715\n"), "4311501679715")
        XCTAssertEqual(BarcodeLogik.normal("012345678905"), "0012345678905")
        XCTAssertEqual(BarcodeLogik.normal("20123456"), "20123456")
    }

    func testIstBarcodeEingabe() {
        XCTAssertTrue(BarcodeLogik.istBarcodeEingabe("20123456")) // EAN-8
        XCTAssertTrue(BarcodeLogik.istBarcodeEingabe("012345678905")) // UPC-A
        XCTAssertTrue(BarcodeLogik.istBarcodeEingabe("4311501679715")) // EAN-13
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("2012345")) // zu kurz (7)
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("201234567")) // keine plausible Länge (9)
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("Skyr Natur")) // Text, keine Ziffern
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("4311 501679715")) // Leerzeichen, kein reiner Ziffernstring
    }

    private func quellen(lokal: Lebensmittel? = nil, server: Result<Lebensmittel?, any Error & Sendable> = .success(nil),
                         off: Result<Lebensmittel?, any Error & Sendable> = .success(nil), name: (String, String?)? = nil,
                         aufrufe: Protokoll = Protokoll()) -> BarcodeQuellen {
        let treffer = skyr // lokale Kopie statt `self` im @Sendable-Closure
        return BarcodeQuellen(
            lokal: { _ in aufrufe.add("lokal"); return lokal },
            server: { _ in aufrufe.add("server"); return try server.get() },
            offLive: { _ in aufrufe.add("off"); return try off.get() },
            name: { _ in aufrufe.add("name"); return name.map { (name: $0.0, marke: $0.1) } },
            namensSuche: { text in aufrufe.add("suche:\(text)"); return [treffer] })
    }

    func testReihenfolgeUndStopp() async {
        let p = Protokoll()
        let r = await BarcodeKette.suchen("4311501679715", quellen(server: .success(skyr), aufrufe: p))
        XCTAssertEqual(r, .gefunden(skyr))
        XCTAssertEqual(p.liste, ["lokal", "server"])
    }

    func testServerAusDannOFF() async {
        let p = Protokoll()
        let r = await BarcodeKette.suchen("4311501679715", quellen(server: .failure(EssenServer.Fehler.netz), off: .success(skyr), aufrufe: p))
        XCTAssertEqual(r, .gefunden(skyr))
        XCTAssertEqual(p.liste, ["lokal", "server", "off"])
    }

    func testNameGibtVorschlaege() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen(name: ("Skyr Natur", "Gut & Günstig")))
        XCTAssertEqual(r, .vorschlaege(name: "Skyr Natur", [skyr]))
    }

    func testNichtsGefunden() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen())
        XCTAssertEqual(r, .unbekannt("4311501679715"))
    }

    func testAllesOffline() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen(server: .failure(URLError(.notConnectedToInternet)),
                                                                   off: .failure(URLError(.notConnectedToInternet))))
        XCTAssertEqual(r, .offline("4311501679715"))
    }
}

final class Protokoll: @unchecked Sendable {
    private let sperre = NSLock()
    private(set) var liste: [String] = []
    func add(_ s: String) { sperre.withLock { liste.append(s) } }
}
