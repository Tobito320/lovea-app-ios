import XCTest
@testable import Lovea

final class MitgelieferteStickerTests: XCTestCase {
    func testAssetPraefixWirdErkannt() {
        XCTAssertEqual(MitgelieferteSticker.assetName("asset:wir-kuss"), "wir-kuss")
        XCTAssertEqual(MitgelieferteSticker.medienId("meme-drake"), "asset:meme-drake")
        XCTAssertEqual(MitgelieferteSticker.assetName(MitgelieferteSticker.medienId("wir-umarmung")), "wir-umarmung")
    }

    func testAlteMedienIdsBleibenUnveraendert() {
        XCTAssertNil(MitgelieferteSticker.assetName("3F2504E0-4F89-11D3-9A0C-0305E82C3301"))
        XCTAssertNil(MitgelieferteSticker.assetName(""))
        XCTAssertNil(MitgelieferteSticker.assetName("Asset:wir-kuss")) // Groß geschrieben ist kein Präfix
    }
}
