import SwiftUI
import XCTest
@testable import Lovea

@MainActor
final class ZyklusRootTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "zyklus-root-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testSperreStandard() {
        XCTAssertTrue(ZyklusSperre(person: .annika, defaults: defaults(), pruefer: { true }).aktiv)
        XCTAssertFalse(ZyklusSperre(person: .ahmed, defaults: defaults(), pruefer: { true }).aktiv)
    }

    func testSperreSchalterBleibt() {
        let d = defaults()
        ZyklusSperre(person: .annika, defaults: d, pruefer: { true }).aktiv = false
        XCTAssertFalse(ZyklusSperre(person: .annika, defaults: d, pruefer: { true }).aktiv)
    }

    func testEntsperrenNurBeiErfolg() async {
        let nein = ZyklusSperre(person: .annika, defaults: defaults(), pruefer: { false })
        XCTAssertTrue(nein.gesperrt)
        await nein.entsperren()
        XCTAssertTrue(nein.gesperrt)

        let ja = ZyklusSperre(person: .annika, defaults: defaults(), pruefer: { true })
        await ja.entsperren()
        XCTAssertFalse(ja.gesperrt)
        ja.sperren()
        XCTAssertTrue(ja.gesperrt)
    }

    func testAusgeschaltetIstNieGesperrt() {
        let s = ZyklusSperre(person: .ahmed, defaults: defaults(), pruefer: { false })
        XCTAssertFalse(s.gesperrt)
    }

    func testBannerNurDemo() {
        XCTAssertTrue(ZyklusRootLogik.zeigtBanner(.demo))
        XCTAssertFalse(ZyklusRootLogik.zeigtBanner(.echt))
        XCTAssertEqual(ZyklusRootLogik.demoBanner, "Testdaten, nur zum Ausprobieren")
    }

    func testGrenzen() {
        let e = ZyklusEinstellungenLogik.begrenzt(ZyklusEinstellung(zyklusLaenge: 99, periodenLaenge: 0, modus: .pille))
        XCTAssertEqual(e.zyklusLaenge, 45)
        XCTAssertEqual(e.periodenLaenge, 2)
        XCTAssertEqual(e.modus, .pille)
    }

    func testLoeschenNurEcht() {
        XCTAssertTrue(ZyklusEinstellungenLogik.darfLoeschen(.echt))
        XCTAssertFalse(ZyklusEinstellungenLogik.darfLoeschen(.demo))
        let demo = DemoZyklusSpeicher(heute: "2026-10-04")
        let vorher = demo.tage.count
        ZyklusEinstellungenLogik.alleLoeschen(demo)
        XCTAssertEqual(demo.tage.count, vorher)
    }

    func testExport() {
        let tage = ["2026-10-02": ZyklusTag(id: "2026-10-02", blutung: .leicht, notiz: "gut"), "2026-10-01": ZyklusTag(id: "2026-10-01")]
        let text = ZyklusEinstellungenLogik.export(tage: tage, einstellung: ZyklusEinstellung())
        let zeilen = text.split(separator: "\n").map(String.init)
        XCTAssertEqual(zeilen.first, "Lovea Zyklus")
        XCTAssertTrue(text.contains("Zykluslänge: 28 Tage"))
        let i1 = text.range(of: "2026-10-01")!.lowerBound, i2 = text.range(of: "2026-10-02")!.lowerBound
        XCTAssertTrue(i1 < i2)
        XCTAssertTrue(text.contains("Leichte Blutung"))
        XCTAssertTrue(text.contains("Notiz: gut"))
    }

    func testRenderRootDemo() {
        let s = DemoZyklusSpeicher(heute: "2026-10-04")
        let sperre = ZyklusSperre(person: .ahmed, defaults: defaults(), pruefer: { true })
        RenderTafel.speichern("zyklus-root", spalten: 2, zellen: [
            ("Einstellungen", AnyView(ZyklusEinstellungenBlatt(speicher: s, sperre: sperre).frame(width: 390, height: 800))),
            ("Sperre", AnyView(ZyklusSperreAnsicht(sperre: sperre).frame(width: 390, height: 400))),
            ("Profil-Zeile", AnyView(ZyklusProfilZeile(person: .annika).padding(16).frame(width: 390).background(ZyklusHintergrund(deko: false)))),
        ])
    }
}
