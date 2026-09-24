import XCTest
@testable import Lovea

/// Brief R: which rooms darken at night.
final class SzenenNachtUndWandTests: XCTestCase {
    func testRaeumeWerdenNachtsDunkel() {
        for szene in [ProfilSzene.zimmer, .schule, .arbeit] {
            XCTAssertTrue(szene.dunkel(nacht: true), "\(szene) at night")
            XCTAssertFalse(szene.dunkel(nacht: false), "\(szene) by day")
        }
        XCTAssertTrue(ProfilSzene.schlafen(zusammen: false).dunkel(nacht: false), "the bed is always night")
        let hell: [ProfilSzene] = [.gym, .draussen(wetter: .sonne, nacht: true), .unterwegs(wetter: .regen, nacht: true)]
        for szene in hell { XCTAssertFalse(szene.dunkel(nacht: true), "\(szene) has its own light") }
    }
}
