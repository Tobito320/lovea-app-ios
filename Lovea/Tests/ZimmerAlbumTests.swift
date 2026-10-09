import XCTest
@testable import Lovea

/// p63: das Erinnerungsalbum aus Snaps und Chat-Highlights.
final class ZimmerAlbumTests: XCTestCase {
    /// Berliner Mitternacht des Tages plus `stunde`.
    private func zeit(_ tag: String, _ stunde: Int = 12) -> Date {
        Datum.datum(tag).addingTimeInterval(Double(stunde) * 3600)
    }

    private func foto(_ id: String) -> ChatModell.MedienEintrag { ChatModell.MedienEintrag(id: id, typ: "foto", breite: 100, hoehe: 100) }

    private func nachricht(_ id: String, _ tag: String, _ stunde: Int = 12, von: Person = .ahmed, _ aendern: (inout ChatModell.Nachricht) -> Void = { _ in }) -> ChatModell.Nachricht {
        var n = ChatModell.Nachricht(id: id, von: von, zeit: zeit(tag, stunde))
        aendern(&n)
        return n
    }

    func testSnapsUndHighlightsLandenImMonat() {
        let monate = ZimmerAlbumLogik.monate(aus: [
            nachricht("snap", "2026-09-03") { $0.snap = ChatModell.SnapInfo(bleibt: false); $0.snapGespeichert = true; $0.medien = [foto("f1")] },
            nachricht("satz", "2026-09-10") { $0.text = "Ich vermisse dich"; $0.gemerkt = [.annika] },
            nachricht("egal", "2026-09-11") { $0.text = "normaler Text" },
        ], ich: .ahmed)
        XCTAssertEqual(monate.map(\.id), ["2026-09"])
        XCTAssertEqual(monate.first?.fotos.map(\.id), ["f1"])
        XCTAssertEqual(monate.first?.fotos.first?.eigene, true)
        XCTAssertEqual(monate.first?.saetze.map(\.text), ["Ich vermisse dich"])
        XCTAssertEqual(monate.first?.titel, "September 2026")
    }

    func testAeltesterMonatZuerstUndLeereMonateFehlen() {
        let monate = ZimmerAlbumLogik.monate(aus: [
            nachricht("neu", "2026-10-02") { $0.text = "Neu"; $0.angeheftet = true },
            nachricht("leer", "2026-08-02") { $0.text = "nichts besonderes" },
            nachricht("alt", "2026-06-20") { $0.text = "Alt"; $0.gemerkt = [.ahmed] },
        ], ich: .annika)
        XCTAssertEqual(monate.map(\.id), ["2026-06", "2026-10"])
    }

    func testFluechtigerSnapZaehltNichtDauerhafterSchon() {
        let monate = ZimmerAlbumLogik.monate(aus: [
            nachricht("s", "2026-09-03") { $0.snap = ChatModell.SnapInfo(bleibt: false); $0.medien = [foto("f1")] },
            nachricht("b", "2026-09-04") { $0.snap = ChatModell.SnapInfo(bleibt: true); $0.medien = [foto("f2")] },
        ], ich: nil)
        XCTAssertEqual(monate.first?.fotos.map(\.id), ["f2"])
    }

    func testGeloeschteUndSystemzeilenFehlen() {
        let monate = ZimmerAlbumLogik.monate(aus: [
            nachricht("g", "2026-09-03") { $0.text = "weg"; $0.gemerkt = [.ahmed]; $0.geloescht = true },
            nachricht("s", "2026-09-04") { $0.text = "System"; $0.gemerkt = [.ahmed]; $0.system = "x" },
        ], ich: .ahmed)
        XCTAssertTrue(monate.isEmpty)
    }

    func testProMonatGewinnenDieNeuesten() {
        var alle: [ChatModell.Nachricht] = []
        for t in 1...6 {
            alle.append(nachricht("f\(t)", "2026-09-0\(t)") { $0.snap = ChatModell.SnapInfo(bleibt: true); $0.medien = [foto("f\(t)")] })
            alle.append(nachricht("s\(t)", "2026-09-0\(t)") { $0.text = "Satz \(t)"; $0.gemerkt = [.ahmed] })
        }
        let m = ZimmerAlbumLogik.monate(aus: alle, ich: .ahmed)[0]
        XCTAssertEqual(m.fotos.count, ZimmerAlbumLogik.maxFotos)
        XCTAssertEqual(m.saetze.count, ZimmerAlbumLogik.maxSaetze)
        XCTAssertEqual(m.fotos.map(\.id), ["f6", "f5", "f4", "f3"])
    }

    func testMonatGehtNachBerlinerZeit() {
        // 23 Uhr am 31.08. in Berlin ist noch August (in UTC wäre es 21 Uhr, auch August; 1 Uhr am 1.9. wäre September).
        let spaet = nachricht("a", "2026-08-31", 23) { $0.text = "Spät"; $0.gemerkt = [.ahmed] }
        let frueh = nachricht("b", "2026-09-01", 1) { $0.text = "Früh"; $0.gemerkt = [.ahmed] }
        XCTAssertEqual(ZimmerAlbumLogik.monate(aus: [spaet, frueh], ich: nil).map(\.id), ["2026-08", "2026-09"])
    }

    func testLeereEingabeGibtKeineSeiten() {
        XCTAssertTrue(ZimmerAlbumLogik.monate(aus: [], ich: .ahmed).isEmpty)
    }
}
