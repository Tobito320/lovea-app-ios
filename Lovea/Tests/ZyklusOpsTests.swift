import XCTest
@testable import Lovea

@MainActor
final class ZyklusOpsTests: XCTestCase {
    private func speicher(_ ich: Person?, _ gesendet: @escaping (Op) -> Void = { _ in }) -> EchterZyklusSpeicher {
        EchterZyklusSpeicher(datei: nil, ich: { ich }, sende: gesendet)
    }

    private func op(_ tag: ZyklusTag?, id: String, zeit: Date, von: Person = .annika) -> Op {
        let roh = try! JSONEncoder().encode(ZyklusOps.TagD(id: "2026-10-01", tag: tag))
        return Op(id: id, seq: nil, art: ZyklusOps.tagArt, von: von, zeit: zeit, d: roh)
    }

    func testRoundtripOpKodierung() {
        let t = ZyklusTag(id: "2026-10-01", blutung: .mittel, symptome: [.kraempfe], stimmung: [.ruhig], temperatur: 36.5, notiz: "ok")
        let o = ZyklusOps.tagOp(t, von: .annika)
        XCTAssertEqual(o.art, "zyklus.tag")
        XCTAssertEqual(o.daten(ZyklusOps.TagD.self)?.tag, t)
        let e = ZyklusEinstellung(zyklusLaenge: 30, periodenLaenge: 4, modus: .pille)
        XCTAssertEqual(ZyklusOps.einstellungOp(e, von: .annika).daten(ZyklusOps.EinstellungD.self)?.einstellung, e)
    }

    func testAnnikaSendetUndZweitgeraetWendetAn() {
        var gesendet: [Op] = []
        let a = speicher(.annika) { gesendet.append($0) }
        a.setze(ZyklusTag(id: "2026-10-01", blutung: .leicht))
        a.einstellung = ZyklusEinstellung(zyklusLaenge: 31, periodenLaenge: 5, modus: .zyklus)
        XCTAssertEqual(gesendet.map(\.art), ["zyklus.tag", "zyklus.einstellung"])
        let zweit = speicher(.annika)
        gesendet.forEach { zweit.empfangen($0) }
        XCTAssertEqual(zweit.tage["2026-10-01"]?.blutung, .leicht)
        XCTAssertEqual(zweit.einstellung.zyklusLaenge, 31)
    }

    func testAhmedVerwirftOpsUndSendetNie() {
        var gesendet: [Op] = []
        let a = speicher(.ahmed) { gesendet.append($0) }
        a.empfangen(op(ZyklusTag(id: "2026-10-01", blutung: .stark), id: "1", zeit: Date()))
        a.empfangen(ZyklusOps.einstellungOp(ZyklusEinstellung(zyklusLaenge: 40), von: .annika))
        a.setze(ZyklusTag(id: "2026-10-02", blutung: .leicht))
        a.einstellung = ZyklusEinstellung(zyklusLaenge: 22)
        XCTAssertTrue(a.tage.isEmpty)
        XCTAssertEqual(a.einstellung, ZyklusEinstellung())
        XCTAssertTrue(gesendet.isEmpty)
    }

    func testAhmedsDemoSendetKeineOp() {
        let w = ZyklusSpeicherWahl.fuer(person: .ahmed)
        XCTAssertEqual(w.quelle, .demo)
        XCTAssertTrue(w is DemoZyklusSpeicher)
        let vorher = w.tage.count
        w.setze(ZyklusTag(id: "2030-01-01", blutung: .leicht))
        XCTAssertEqual(w.tage.count, vorher + 1)
    }

    func testLastWriterWinsJeTag() {
        let a = speicher(.annika)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let neu = op(ZyklusTag(id: "2026-10-01", blutung: .stark), id: "b", zeit: t0.addingTimeInterval(10))
        let alt = op(ZyklusTag(id: "2026-10-01", blutung: .leicht), id: "a", zeit: t0)
        a.empfangen(neu)
        a.empfangen(alt)
        XCTAssertEqual(a.tage["2026-10-01"]?.blutung, .stark)
        a.empfangen(op(nil, id: "c", zeit: t0.addingTimeInterval(20)))
        XCTAssertNil(a.tage["2026-10-01"])
        a.empfangen(neu)
        XCTAssertNil(a.tage["2026-10-01"])
    }

    func testPersistenzUeberNeustart() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zyklus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let a = EchterZyklusSpeicher(datei: url, ich: { .annika }, sende: { _ in })
        a.setze(ZyklusTag(id: "2026-10-03", symptome: [.akne]))
        let b = EchterZyklusSpeicher(datei: url, ich: { .annika }, sende: { _ in })
        XCTAssertEqual(b.tage["2026-10-03"]?.symptome, [.akne])
    }
}
