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
        for (name, rect) in ZimmerPlatzLogik.alle {
            XCTAssertTrue(welt.contains(rect), "\(name) \(rect) ragt aus der Welt")
        }
    }
}
