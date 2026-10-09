import XCTest
@testable import Lovea

/// Kein immer sichtbares Ding im Zimmer-Panorama liegt über einem anderen; Berühren der Kanten ist erlaubt.
@MainActor
final class ZimmerPlatzLogikTests: XCTestCase {
    func testKeinDingUeberlapptEinAnderes() {
        let alle = ZimmerPlatzLogik.alle.sorted { $0.key < $1.key }
        XCTAssertGreaterThan(alle.count, 15)
        for (i, a) in alle.enumerated() {
            for b in alle[(i + 1)...] {
                XCTAssertFalse(a.value.intersects(b.value), "\(a.key) \(a.value) liegt auf \(b.key) \(b.value)")
            }
        }
    }

    func testAlleDingeLiegenInDerWelt() {
        let welt = CGRect(x: 0, y: 0, width: ZimmerPlatzLogik.weltBreite, height: ZimmerPlatzLogik.weltHoehe)
        // Mit Rand links und rechts: am Ende des Wischens darf nichts an der Bildkante kleben.
        let mitRand = welt.insetBy(dx: ZimmerPlatzLogik.weltRand, dy: 0)
        for (name, rect) in ZimmerPlatzLogik.alle {
            XCTAssertTrue(mitRand.contains(rect), "\(name) \(rect) liegt nicht mit Rand in der Welt")
        }
    }

    func testWeltBreiteStimmtMitDenSlotsUeberein() {
        XCTAssertEqual(ZimmerPlatzLogik.weltBreite, ProfilSlots.weltBreite)
        XCTAssertEqual(ZimmerPlatzLogik.weltHoehe, ProfilSlots.hoehe)
    }
}
