import XCTest
@testable import Lovea

/// Paar-Galerie: welche Medien zählen, Filter, Monatsgruppen, "Heute vor X".
final class GalerieLogikTests: XCTestCase {
    private let kal = Datum.kalender

    private func tag(_ j: Int, _ m: Int, _ t: Int, _ h: Int = 12) -> Date {
        kal.date(from: DateComponents(year: j, month: m, day: t, hour: h))!
    }

    private func nachricht(_ id: String, _ zeit: Date, typ: String = "foto", snap: Bool? = nil, gespeichert: Bool = false, geloescht: Bool = false) -> ChatModell.Nachricht {
        var n = ChatModell.Nachricht(id: id, von: .ahmed, zeit: zeit)
        n.medien = [ChatModell.MedienEintrag(id: "m-\(id)", typ: typ, breite: 100, hoehe: 100)]
        if let snap { n.snap = ChatModell.SnapInfo(bleibt: snap) }
        n.snapGespeichert = gespeichert
        n.geloescht = geloescht
        return n
    }

    func testFluechtigeSnapsUndGeloeschtesZaehlenNicht() {
        let s = GalerieLogik.stuecke(aus: [
            nachricht("a", tag(2026, 10, 1)),
            nachricht("b", tag(2026, 10, 2), snap: false),
            nachricht("c", tag(2026, 10, 3), snap: false, gespeichert: true),
            nachricht("d", tag(2026, 10, 4), snap: true),
            nachricht("e", tag(2026, 10, 5), geloescht: true),
            nachricht("f", tag(2026, 10, 6), typ: "sprache")
        ])
        XCTAssertEqual(s.map(\.nachrichtID), ["d", "c", "a"])
    }

    func testFilter() {
        let s = GalerieLogik.stuecke(aus: [
            nachricht("foto", tag(2026, 10, 1)),
            nachricht("video", tag(2026, 10, 2), typ: "video"),
            nachricht("snap", tag(2026, 10, 3), snap: true)
        ])
        XCTAssertEqual(GalerieLogik.filtern(s, .alle).count, 3)
        XCTAssertEqual(GalerieLogik.filtern(s, .fotos).map(\.nachrichtID), ["foto"])
        XCTAssertEqual(GalerieLogik.filtern(s, .videos).map(\.nachrichtID), ["video"])
        XCTAssertEqual(GalerieLogik.filtern(s, .snaps).map(\.nachrichtID), ["snap"])
    }

    func testMonateNeuesteZuerst() {
        let s = GalerieLogik.stuecke(aus: [
            nachricht("a", tag(2026, 9, 30, 23)),
            nachricht("b", tag(2026, 10, 1, 1)),
            nachricht("c", tag(2026, 10, 20)),
            nachricht("d", tag(2025, 12, 24))
        ])
        let m = GalerieLogik.monate(s)
        XCTAssertEqual(m.map(\.id), ["2026-10", "2026-09", "2025-12"])
        XCTAssertEqual(m[0].stuecke.map(\.nachrichtID), ["c", "b"])
        XCTAssertEqual(m[0].titel, "Oktober 2026")
    }

    func testRueckblickGleicherTagFruehereJahre() {
        let s = GalerieLogik.stuecke(aus: [
            nachricht("heute", tag(2026, 10, 9)),
            nachricht("v1", tag(2025, 10, 9, 8)),
            nachricht("v1b", tag(2025, 10, 9, 20)),
            nachricht("v2", tag(2024, 10, 9)),
            nachricht("anders", tag(2025, 10, 10))
        ])
        let r = GalerieLogik.rueckblick(s, jetzt: tag(2026, 10, 9, 15))
        XCTAssertEqual(r?.titel, "Heute vor einem Jahr")
        XCTAssertEqual(r?.stuecke.map(\.nachrichtID), ["v1", "v1b"])
    }

    func testRueckblickFaelltAufMonateZurueck() {
        let s = GalerieLogik.stuecke(aus: [nachricht("a", tag(2026, 7, 9)), nachricht("b", tag(2026, 10, 9))])
        let r = GalerieLogik.rueckblick(s, jetzt: tag(2026, 10, 9))
        XCTAssertEqual(r?.titel, "Heute vor 3 Monaten")
        XCTAssertEqual(r?.stuecke.map(\.nachrichtID), ["a"])
    }

    func testKeinRueckblickOhneTreffer() {
        let s = GalerieLogik.stuecke(aus: [nachricht("a", tag(2026, 10, 8)), nachricht("b", tag(2026, 10, 9))])
        XCTAssertNil(GalerieLogik.rueckblick(s, jetzt: tag(2026, 10, 9)))
    }

    func testTitelFormen() {
        XCTAssertEqual(GalerieLogik.rueckblickTitel(monate: 24), "Heute vor 2 Jahren")
        XCTAssertEqual(GalerieLogik.rueckblickTitel(monate: 1), "Heute vor einem Monat")
    }
}
