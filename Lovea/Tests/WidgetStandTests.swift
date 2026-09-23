import XCTest
@testable import Lovea

/// Z-28.2/Z-28.3: reine Logik rund um den Widget-Stand — Schreib-Drosselung und die Idempotenz
/// des Merges wartender Gym-Ops aus `GymHeuteIntent`. Kein `Raum`/App Group nötig.
final class WidgetStandTests: XCTestCase {
    // MARK: - WidgetThrottle

    func testWartezeitDirektNachSchreibenIstVolleFrist() {
        let jetzt = Date()
        XCTAssertEqual(WidgetThrottle.wartezeit(zuletzt: jetzt, jetzt: jetzt, minAbstand: 15), 15)
    }

    func testWartezeitNachAblaufDerFristIstNull() {
        let zuletzt = Date()
        let jetzt = zuletzt.addingTimeInterval(20)
        XCTAssertEqual(WidgetThrottle.wartezeit(zuletzt: zuletzt, jetzt: jetzt, minAbstand: 15), 0)
    }

    func testWartezeitInDerMitteDerFrist() {
        let zuletzt = Date()
        let jetzt = zuletzt.addingTimeInterval(5)
        XCTAssertEqual(WidgetThrottle.wartezeit(zuletzt: zuletzt, jetzt: jetzt, minAbstand: 15), 10, accuracy: 0.001)
    }

    // MARK: - WidgetPendingMerge (Idempotenz, Review-Fokus 2)

    func testEindeutigBehaeltJedeIdNurEinmal() {
        let a = WidgetPendingOp(id: "1", von: "ahmed", zeit: "2026-09-23T10:00:00Z", datum: "2026-09-23", wert: 1)
        let aErneut = WidgetPendingOp(id: "1", von: "ahmed", zeit: "2026-09-23T10:00:05Z", datum: "2026-09-23", wert: 0)
        let b = WidgetPendingOp(id: "2", von: "annika", zeit: "2026-09-23T10:00:00Z", datum: "2026-09-23", wert: 1)

        let ergebnis = WidgetPendingMerge.eindeutig([a, aErneut, b])

        XCTAssertEqual(ergebnis.count, 2)
        XCTAssertEqual(ergebnis.map(\.id), ["1", "2"])
        // Die erste Fassung gewinnt (ein zweiter Directory-Read vor dem Löschen darf die schon
        // eingereihte Op nicht durch eine andere ersetzen).
        XCTAssertEqual(ergebnis.first?.wert, 1)
    }

    func testEindeutigMitLeererListe() {
        XCTAssertEqual(WidgetPendingMerge.eindeutig([]), [])
    }

    // MARK: - WidgetDatum (Review-Fokus 1: Ortszeit)

    func testHeuteFolgtBerlinerZeitzone() {
        var utc = DateComponents()
        utc.year = 2026; utc.month = 9; utc.day = 23; utc.hour = 23; utc.minute = 30
        var kalenderUTC = Calendar(identifier: .gregorian)
        kalenderUTC.timeZone = TimeZone(identifier: "UTC")!
        let datum = kalenderUTC.date(from: utc)!

        // 23:30 UTC ist am 24.09. bereits 01:30 in Berlin (Sommerzeit, UTC+2).
        XCTAssertEqual(WidgetDatum.heute(datum), "2026-09-24")
    }

    func testTageZwischenUeberZeitumstellung() {
        // 25.10.2026: deutsche Uhren stellen von Sommer- auf Normalzeit zurück.
        XCTAssertEqual(WidgetDatum.tageZwischen("2026-10-24", "2026-10-26"), 2)
    }
}
