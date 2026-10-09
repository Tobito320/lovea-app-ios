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

    func testBannerNurBeiNurLesen() {
        XCTAssertTrue(ZyklusRootLogik.zeigtBanner(nurLesen: true))
        XCTAssertFalse(ZyklusRootLogik.zeigtBanner(nurLesen: false))
        XCTAssertEqual(ZyklusRootLogik.leseBanner, "Annikas Zyklus, nur ansehen")
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
        let demo = EchterZyklusSpeicher(datei: nil, ich: { .ahmed }, sende: { _ in })
        demo.empfangen(ZyklusOps.tagOp(ZyklusTag(id: "2026-10-01", blutung: .leicht), von: .annika))
        ZyklusEinstellungenLogik.alleLoeschen(demo)
        XCTAssertEqual(demo.tage.count, 1)
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
        let sperre = ZyklusSperre(person: .ahmed, defaults: defaults(), pruefer: { true })
        let kachel = { (inhalt: AnyView) in
            AnyView(inhalt.padding(16).frame(width: 390).background(ZyklusHintergrund(deko: false)))
        }
        RenderTafel.speichern("zyklus-root", spalten: 2, zellen: [
            ("Einstellungen (Annika, mit Loeschen)", kachel(AnyView(ZyklusEinstellungenInhalt(einst: .constant(ZyklusEinstellung()), sperreAktiv: .constant(true), erweitert: nil, darfLoeschen: true)))),
            ("Sperre", AnyView(ZyklusSperreAnsicht(sperre: sperre).frame(width: 390, height: 400))),
            ("Profil-Zeile", kachel(AnyView(ZyklusProfilZeileInhalt()))),
        ])
    }

    func testReiterJeModus() {
        XCTAssertEqual(ZyklusRootLogik.reiter(.zyklus), [.heute, .kalender, .insights])
        for m in [Modus.schwanger, .kinderwunsch, .pille] {
            XCTAssertEqual(ZyklusRootLogik.reiter(m), [.modus, .kalender, .insights])
        }
    }

    func testReiterTitelUndGueltig() {
        XCTAssertEqual(ZyklusRootLogik.titel(.modus, modus: .schwanger), "Schwanger")
        XCTAssertEqual(ZyklusRootLogik.titel(.heute, modus: .zyklus), "Heute")
        XCTAssertEqual(ZyklusRootLogik.gueltig(.heute, modus: .pille), .modus)
        XCTAssertEqual(ZyklusRootLogik.gueltig(.modus, modus: .zyklus), .heute)
        XCTAssertEqual(ZyklusRootLogik.gueltig(.kalender, modus: .pille), .kalender)
    }

    func testErinnerungsArtenJeModus() {
        XCTAssertTrue(ZyklusErinnerungsDienst.arten(fuer: .pille).contains(.pille))
        XCTAssertFalse(ZyklusErinnerungsDienst.arten(fuer: .zyklus).contains(.pille))
        XCTAssertEqual(ZyklusErinnerungsDienst.arten(fuer: .schwanger), [.wasser, .eintragen])
    }
}
