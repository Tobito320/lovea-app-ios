import SwiftUI
import XCTest
@testable import Lovea

@MainActor
private final class TestZyklusSpeicher: ZyklusSpeicher {
    let quelle = ZyklusQuelle.demo
    var tage: [String: ZyklusTag]
    var einstellung: ZyklusEinstellung

    init(tage: [String: ZyklusTag], einstellung: ZyklusEinstellung = ZyklusEinstellung()) {
        self.tage = tage
        self.einstellung = einstellung
    }

    func setze(_ tag: ZyklusTag) {
        if tag.istLeer { tage[tag.id] = nil } else { tage[tag.id] = tag }
    }
}

/// Periode 1. bis 5. September 2026, Zyklus 28 Tage: Eisprung 15.9., fruchtbar 10. bis 16.9., nächste Periode 29.9.
@MainActor
final class ZyklusAnsichtTests: XCTestCase {
    private func tage(blutung tage: [String] = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05"]) -> [String: ZyklusTag] {
        Dictionary(uniqueKeysWithValues: tage.map { ($0, ZyklusTag(id: $0, blutung: .mittel)) })
    }

    private func logik(heute: String, tage: [String: ZyklusTag]? = nil) -> ZyklusLogik {
        ZyklusLogik(tage: Array((tage ?? self.tage()).values), heute: heute)
    }

    // MARK: Raster

    func testRasterOktober2026() {
        let r = ZyklusKalenderLogik.raster(monat: "2026-10-01")
        XCTAssertEqual(r.count, 5)
        XCTAssertTrue(r.allSatisfy { $0.count == 7 })
        XCTAssertEqual(r[0].prefix(4).map { $0 }, [nil, nil, nil, "2026-10-01"])
        XCTAssertEqual(r.flatMap { $0 }.compactMap { $0 }.count, 31)
        XCTAssertEqual(r[4][5], "2026-10-31")
    }

    func testRasterFebruarBeginntSonntag() {
        let r = ZyklusKalenderLogik.raster(monat: "2026-02-17")
        XCTAssertEqual(r[0].filter { $0 == nil }.count, 6)
        XCTAssertEqual(r[0][6], "2026-02-01")
        XCTAssertEqual(r.flatMap { $0 }.compactMap { $0 }.count, 28)
    }

    func testMonatVerschieben() {
        XCTAssertEqual(ZyklusKalenderLogik.monatVerschieben("2026-12-15", um: 1), "2027-01-01")
        XCTAssertEqual(ZyklusKalenderLogik.monatVerschieben("2026-01-01", um: -1), "2025-12-01")
        XCTAssertEqual(ZyklusKalenderLogik.monatsStart("2026-10-31"), "2026-10-01")
    }

    // MARK: Status

    func testStatusPeriodeFruchtbarEisprung() {
        let t = tage()
        let l = logik(heute: "2026-09-10", tage: t)
        func s(_ id: String) -> ZyklusTagStatus { ZyklusKalenderLogik.status(id, logik: l, tage: t, heute: "2026-09-10") }
        XCTAssertTrue(s("2026-09-02").periode)
        XCTAssertFalse(s("2026-09-02").vorhersage)
        XCTAssertTrue(s("2026-09-12").fruchtbar)
        XCTAssertFalse(s("2026-09-12").eisprung)
        XCTAssertTrue(s("2026-09-15").eisprung)
        XCTAssertTrue(s("2026-09-15").fruchtbar)
        XCTAssertEqual(s("2026-09-20"), ZyklusTagStatus())
    }

    func testStatusVorhersageNurAbHeute() {
        let t = tage()
        let l = logik(heute: "2026-09-10", tage: t)
        let s = ZyklusKalenderLogik.status("2026-09-29", logik: l, tage: t, heute: "2026-09-10")
        XCTAssertTrue(s.vorhersage)
        XCTAssertFalse(s.periode)
        XCTAssertTrue(ZyklusKalenderLogik.status("2026-10-03", logik: l, tage: t, heute: "2026-09-10").vorhersage)
        XCTAssertFalse(ZyklusKalenderLogik.status("2026-10-04", logik: l, tage: t, heute: "2026-09-10").vorhersage)
    }

    func testStatusLogpunkt() {
        var t = tage()
        t["2026-09-20"] = ZyklusTag(id: "2026-09-20", notiz: "Spaziergang")
        t["2026-09-21"] = ZyklusTag(id: "2026-09-21")
        let l = logik(heute: "2026-09-22", tage: t)
        XCTAssertTrue(ZyklusKalenderLogik.status("2026-09-20", logik: l, tage: t, heute: "2026-09-22").log)
        XCTAssertFalse(ZyklusKalenderLogik.status("2026-09-21", logik: l, tage: t, heute: "2026-09-22").log)
    }

    // MARK: Periode nachträglich

    func testStartSetzen() {
        XCTAssertEqual(ZyklusKalenderLogik.startSetzen("2026-09-30", tage: tage())?.blutung, .mittel)
        XCTAssertNil(ZyklusKalenderLogik.startSetzen("2026-09-02", tage: tage()))
    }

    func testEndeSetzenKuerzt() {
        let t = tage()
        let geaendert = ZyklusKalenderLogik.endeSetzen("2026-09-03", tage: t, logik: logik(heute: "2026-09-10"))
        XCTAssertEqual(geaendert.map(\.id).sorted(), ["2026-09-04", "2026-09-05"])
        XCTAssertTrue(geaendert.allSatisfy { $0.blutung == nil })
    }

    func testEndeSetzenVerlaengert() {
        let t = tage()
        let geaendert = ZyklusKalenderLogik.endeSetzen("2026-09-07", tage: t, logik: logik(heute: "2026-09-10"))
        XCTAssertEqual(geaendert.map(\.id).sorted(), ["2026-09-06", "2026-09-07"])
        XCTAssertTrue(geaendert.allSatisfy { $0.blutung == .leicht })
    }

    func testEndeSetzenOhnePeriodeDavor() {
        let t = tage()
        XCTAssertTrue(ZyklusKalenderLogik.endeSetzen("2026-08-20", tage: t, logik: logik(heute: "2026-09-10")).isEmpty)
        XCTAssertTrue(ZyklusKalenderLogik.endeSetzen("2026-09-25", tage: t, logik: logik(heute: "2026-09-26")).isEmpty)
    }

    func testEndeSetzenImSpeicher() {
        let s = TestZyklusSpeicher(tage: tage())
        for t in ZyklusKalenderLogik.endeSetzen("2026-09-02", tage: s.tage, logik: s.logik(heute: "2026-09-10")) { s.setze(t) }
        XCTAssertEqual(s.tage.keys.sorted(), ["2026-09-01", "2026-09-02"])
    }

    // MARK: Heute

    func testRingTextPeriodeInTagen() {
        let t = tage()
        let r = ZyklusHeuteLogik.ringText(logik: logik(heute: "2026-09-07", tage: t), heute: "2026-09-07")
        XCTAssertEqual(r.titel, "Tag 7")
        XCTAssertEqual(r.untertitel, "Periode in 22 Tagen")
        XCTAssertEqual(r.ton, .follikel)
    }

    func testRingTextFruchtbarEisprungPeriode() {
        XCTAssertEqual(ZyklusHeuteLogik.ringText(logik: logik(heute: "2026-09-12"), heute: "2026-09-12").untertitel, "Fruchtbar")
        XCTAssertEqual(ZyklusHeuteLogik.ringText(logik: logik(heute: "2026-09-15"), heute: "2026-09-15").untertitel, "Eisprung")
        let p = ZyklusHeuteLogik.ringText(logik: logik(heute: "2026-09-03"), heute: "2026-09-03")
        XCTAssertEqual(p.titel, "Tag 3")
        XCTAssertEqual(p.untertitel, "Periode")
        XCTAssertEqual(p.ton, .periode)
    }

    func testRingTextOhneDaten() {
        let r = ZyklusHeuteLogik.ringText(logik: ZyklusLogik(tage: [], heute: "2026-09-10"), heute: "2026-09-10")
        XCTAssertEqual(r.titel, "Hallo")
        XCTAssertEqual(r.fortschritt, 0)
    }

    func testRingTextVerspaetet() {
        let l = logik(heute: "2026-10-02")
        XCTAssertEqual(ZyklusHeuteLogik.ringText(logik: l, heute: "2026-10-02").untertitel, "Periode 3 Tage später")
    }

    func testEintraegeZeilen() {
        XCTAssertTrue(ZyklusHeuteLogik.eintraege(nil).isEmpty)
        let t = ZyklusTag(id: "2026-09-02", blutung: .stark, symptome: [.kraempfe], stimmung: [.ruhig], schlafMin: 450)
        XCTAssertEqual(ZyklusHeuteLogik.eintraege(t).map(\.titel), ["Starke Blutung", "Krämpfe", "Ruhig", "7 Std 30 Min Schlaf"])
    }

    func testPeriodeStartSchnellknopf() {
        XCTAssertEqual(ZyklusHeuteLogik.periodeStart("2026-09-30", tage: [:])?.blutung, .mittel)
        var t = ZyklusTag(id: "2026-09-30", symptome: [.akne])
        let neu = ZyklusHeuteLogik.periodeStart("2026-09-30", tage: [t.id: t])
        XCTAssertEqual(neu?.symptome, [.akne])
        t.blutung = .leicht
        XCTAssertNil(ZyklusHeuteLogik.periodeStart("2026-09-30", tage: [t.id: t]))
    }

    // MARK: Render-Tafel

    private func demo() -> TestZyklusSpeicher {
        TestZyklusSpeicher(tage: ZyklusDemoDaten.tage(heute: "2026-10-03"), einstellung: ZyklusDemoDaten.einstellung)
    }

    private func zelle(_ titel: String, _ schema: ColorScheme, _ inhalt: some View) -> (titel: String, ansicht: AnyView) {
        let a = ZStack(alignment: .top) { ZyklusHintergrund(deko: false); inhalt.padding(16) }
            .frame(width: 390)
            .environment(\.colorScheme, schema)
        return (titel, AnyView(a))
    }

    private func tafel(_ schema: ColorScheme) -> [(titel: String, ansicht: AnyView)] {
        let name = schema == .light ? "hell" : "dunkel"
        let s = demo()
        let leer: (String) -> AnyView = { _ in AnyView(EmptyView()) }
        let heute = ZyklusHeuteView(speicher: s, eintragBlatt: leer, heute: "2026-10-03")
        let kalender = ZyklusKalenderView(speicher: s, eintragBlatt: leer, heute: "2026-10-03")
        let november = ZyklusKalenderView(speicher: s, eintragBlatt: leer, heute: "2026-11-03")
        return [
            zelle("Heute, \(name)", schema, heute.inhalt),
            zelle("Kalender Oktober, \(name)", schema, kalender.inhalt),
            zelle("Kalender November, \(name)", schema, november.inhalt),
        ]
    }

    func testRenderHell() {
        RenderTafel.speichern("zyklus-ansicht-hell", spalten: 3, zellen: tafel(.light))
    }

    func testRenderDunkel() {
        RenderTafel.speichern("zyklus-ansicht-dunkel", spalten: 3, zellen: tafel(.dark))
    }
}
