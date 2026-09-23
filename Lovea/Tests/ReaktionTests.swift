import XCTest
@testable import Lovea

/// Z-33.1: the `emoji` field of `nachricht.reaktion`.
final class ReaktionTests: XCTestCase {
    func testWerteWerdenErkannt() {
        XCTAssertEqual(Reaktion("❤️"), .emoji("❤️"))
        XCTAssertEqual(Reaktion("figur:lacht"), .figur("lacht"))
        XCTAssertEqual(Reaktion("sticker:meme-drake"), .sticker("meme-drake"))
    }

    func testRundreiseWert() {
        for reaktion in [Reaktion.emoji("😂"), .figur("paar-kuss"), .sticker("meme-drake")] {
            XCTAssertEqual(Reaktion(reaktion.wert), reaktion)
        }
        XCTAssertEqual(Reaktion("figur:lacht").wert, "figur:lacht")
    }

    func testFigurReaktionenReichen() {
        XCTAssertEqual(FigurReaktionen.schnell.map(\.id), ["lacht", "verliebt", "weint", "schockiert", "daumen", "kuss"])
        XCTAssertGreaterThanOrEqual(FigurReaktionen.alle.filter { !$0.paar }.count, 20)
        XCTAssertGreaterThanOrEqual(FigurReaktionen.alle.filter(\.paar).count, 10)
        XCTAssertEqual(Set(FigurReaktionen.alle.map(\.id)).count, FigurReaktionen.alle.count, "ids eindeutig")
        for paar in FigurReaktionen.alle where paar.paar { XCTAssertNotNil(FigurReaktionen.paarPose(paar.id), paar.id) }
    }

    func testNurEmojisZaehlen() {
        XCTAssertTrue(Reaktion.istEmoji("😂"))
        XCTAssertTrue(Reaktion.istEmoji("❤️"))
        XCTAssertTrue(Reaktion.istEmoji("👍🏽"))
        XCTAssertFalse(Reaktion.istEmoji("a"))
        XCTAssertFalse(Reaktion.istEmoji("1"))
    }
}
