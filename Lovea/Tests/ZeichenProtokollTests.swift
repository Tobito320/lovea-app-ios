import XCTest
@testable import Lovea

/// Die Undo-Zeile im Zeichen-Protokoll sagt, ob Rückgängig genau den zuletzt gelandeten Strich trifft.
/// Reine Funktion, kein Metal nötig.
final class ZeichenProtokollTests: XCTestCase {
    private let ebene = UUID()
    private let rect = CGRect(x: 10, y: 20, width: 100, height: 50)

    private func spur(ebene: UUID? = nil, rect: CGRect? = nil) -> LandungsSpur {
        LandungsSpur(layerID: ebene ?? self.ebene, rect: rect ?? self.rect, zeit: 0)
    }

    func testNoLandingYet() {
        XCTAssertEqual(
            LandungsSpur.urteil(layerID: ebene, rect: rect, letzte: nil),
            "kein Strich in dieser Sitzung gelandet"
        )
    }

    func testSameLayerAndRegionIsTheLastStroke() {
        XCTAssertEqual(LandungsSpur.urteil(layerID: ebene, rect: rect, letzte: spur()), "genau der letzte Strich")
    }

    func testOtherLayer() {
        XCTAssertEqual(
            LandungsSpur.urteil(layerID: UUID(), rect: rect, letzte: spur()),
            "andere Ebene als der letzte Strich"
        )
    }

    func testOverlappingRegion() {
        let verschoben = rect.offsetBy(dx: 50, dy: 10)
        XCTAssertEqual(LandungsSpur.urteil(layerID: ebene, rect: verschoben, letzte: spur()), "überlappt den letzten Strich")
    }

    func testDisjointRegion() {
        let weit = CGRect(x: 500, y: 500, width: 10, height: 10)
        XCTAssertEqual(LandungsSpur.urteil(layerID: ebene, rect: weit, letzte: spur()), "trifft den letzten Strich nicht")
    }
}
