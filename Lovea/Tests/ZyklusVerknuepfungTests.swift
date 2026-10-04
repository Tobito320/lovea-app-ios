import HealthKit
import SwiftUI
import XCTest
@testable import Lovea

@MainActor
final class ZyklusVerknuepfungTests: XCTestCase {
    private let start = "2026-09-01"

    private func plus(_ tag: String, _ n: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: n, to: Datum.datum(tag))!)
    }

    /// Eine Periode ab `start`, 5 Tage, Standard 28/5. `nummer` = Zyklustag (1 = erster Periodentag).
    private func hinweis(nummer: Int, modus: Modus = .zyklus) -> ZyklusHinweis? {
        let tage = (0..<5).map { ZyklusTag(id: plus(start, $0), blutung: .mittel) }
        let heute = plus(start, nummer - 1)
        var e = ZyklusEinstellung()
        e.modus = modus
        let logik = ZyklusLogik(tage: tage, einstellung: e, heute: heute)
        return ZyklusVerknuepfung.hinweis(logik: logik, am: heute)
    }

    func testPeriodeIstSanftMitEisen() {
        let h = hinweis(nummer: 2)
        XCTAssertEqual(h?.phase, .periode)
        XCTAssertEqual(h?.rat, .sanft)
        XCTAssertTrue(h?.ernaehrung.contains("Eisen") ?? false)
    }

    func testFollikelFruchtbarEisprungSindKraft() {
        for (nummer, phase) in [(7, Phase.follikel), (12, .fruchtbar), (15, .eisprung)] {
            let h = hinweis(nummer: nummer)
            XCTAssertEqual(h?.phase, phase, "Tag \(nummer)")
            XCTAssertEqual(h?.rat, .kraft, "Tag \(nummer)")
        }
    }

    func testLutealFruehNormalSpaetSanft() {
        XCTAssertEqual(hinweis(nummer: 19)?.phase, .luteal)
        XCTAssertEqual(hinweis(nummer: 19)?.rat, .normal)
        XCTAssertEqual(hinweis(nummer: 25)?.rat, .sanft)
        XCTAssertTrue(hinweis(nummer: 25)?.ernaehrung.contains("Heißhunger") ?? false)
    }

    func testWasserZielJePhase() {
        XCTAssertEqual(ZyklusVerknuepfung.hinweis(phase: .follikel).wasserZielMl, 2000)
        XCTAssertEqual(ZyklusVerknuepfung.hinweis(phase: .periode).wasserZielMl, 2300)
        XCTAssertEqual(ZyklusVerknuepfung.hinweis(phase: .luteal).wasserZielMl, 2300)
    }

    func testJedePhaseHatAlleTexteUndSchritte() {
        for p in Phase.allCases {
            let h = ZyklusVerknuepfung.hinweis(phase: p)
            XCTAssertEqual(h.phase, p)
            for t in [h.training, h.energie, h.schlaf, h.wasser, h.ernaehrung, h.schritte] { XCTAssertFalse(t.isEmpty) }
            XCTAssertGreaterThan(h.schrittZiel, 0)
        }
    }

    func testKeinHinweisOhnePhaseOderAusserhalbZyklusModus() {
        let leer = ZyklusLogik(tage: [], heute: start)
        XCTAssertNil(ZyklusVerknuepfung.hinweis(logik: leer, am: start))
        XCTAssertNil(hinweis(nummer: 7, modus: .schwanger))
    }

    func testSchalterStandardAusUndGate() {
        UserDefaults.standard.removeObject(forKey: ZyklusSchalter.imTraining)
        UserDefaults.standard.removeObject(forKey: ZyklusSchalter.healthKit)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: ZyklusSchalter.imTraining))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: ZyklusSchalter.healthKit))
        XCTAssertTrue(ZyklusVerknuepfung.zeigen(person: .annika, schalter: true, quelle: .echt))
        XCTAssertFalse(ZyklusVerknuepfung.zeigen(person: .annika, schalter: false, quelle: .echt))
        XCTAssertFalse(ZyklusVerknuepfung.zeigen(person: .ahmed, schalter: true, quelle: .echt))
        XCTAssertFalse(ZyklusVerknuepfung.zeigen(person: .annika, schalter: true, quelle: .demo))
    }

    func testHealthKitGateNurAnnikaSchalterEcht() {
        XCTAssertTrue(ZyklusHealthKit.erlaubt(person: .annika, schalter: true, quelle: .echt))
        XCTAssertFalse(ZyklusHealthKit.erlaubt(person: .annika, schalter: false, quelle: .echt))
        XCTAssertFalse(ZyklusHealthKit.erlaubt(person: .ahmed, schalter: true, quelle: .echt))
        XCTAssertFalse(ZyklusHealthKit.erlaubt(person: .annika, schalter: true, quelle: .demo))
    }

    func testAnfragenOhneErlaubnisFragtNicht() async throws {
        let gefragt = try await ZyklusHealthKit.anfragen(person: .ahmed, schalter: true, quelle: .demo)
        XCTAssertFalse(gefragt)
    }

    func testFlussAbbildung() {
        XCTAssertEqual(ZyklusHealthKit.fluss(von: .leicht), .light)
        XCTAssertEqual(ZyklusHealthKit.fluss(von: .mittel), .medium)
        XCTAssertEqual(ZyklusHealthKit.fluss(von: .stark), .heavy)
        XCTAssertNil(ZyklusHealthKit.fluss(von: .schmierblutung))
        for b in [Blutung.leicht, .mittel, .stark] {
            XCTAssertEqual(ZyklusHealthKit.blutung(von: ZyklusHealthKit.fluss(von: b)!), b)
        }
        XCTAssertEqual(ZyklusHealthKit.blutung(von: .unspecified), .mittel)
        XCTAssertNil(ZyklusHealthKit.blutung(von: .none))
        XCTAssertNil(ZyklusHealthKit.blutung(vonRohwert: 999))
    }

    func testTypenUndProbe() {
        XCTAssertEqual(ZyklusHealthKit.schreibTypen, [HKCategoryType(.menstrualFlow)])
        XCTAssertEqual(ZyklusHealthKit.leseTypen.count, 5)
        XCTAssertNil(ZyklusHealthKit.probe(blutung: .schmierblutung, tag: start, periodenStart: false))
        let p = ZyklusHealthKit.probe(blutung: .stark, tag: start, periodenStart: true)
        XCTAssertEqual(p?.value, HKCategoryValueMenstrualFlow.heavy.rawValue)
        XCTAssertEqual(p?.metadata?[HKMetadataKeySyncIdentifier] as? String, "lovea.zyklus.fluss.\(start)")
        XCTAssertEqual(p?.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool, true)
    }

    func testKarteRendert() {
        let zellen = Phase.allCases.map { p in
            (titel: p.rawValue, ansicht: AnyView(ZyklusHinweisKarte(hinweis: ZyklusVerknuepfung.hinweis(phase: p)).frame(width: 360).padding(8)))
        }
        RenderTafel.speichern("zyklus-hinweiskarte", spalten: 3, zellen: zellen)
    }
}
