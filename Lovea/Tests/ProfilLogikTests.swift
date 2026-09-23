import XCTest
@testable import Lovea

final class ProfilLogikTests: XCTestCase {
    func testSternzeichen() {
        XCTAssertEqual(Sternzeichen.fuer(monat: 2, tag: 27).name, "Fische")
        XCTAssertEqual(Sternzeichen.fuer(monat: 6, tag: 6).name, "Zwillinge")
        XCTAssertEqual(Sternzeichen.fuer(monat: 1, tag: 19).name, "Steinbock")
        XCTAssertEqual(Sternzeichen.fuer(monat: 1, tag: 20).name, "Wassermann")
        XCTAssertEqual(Sternzeichen.fuer(monat: 6, tag: 21).name, "Zwillinge")
        XCTAssertEqual(Sternzeichen.fuer(monat: 6, tag: 22).name, "Krebs")
        XCTAssertEqual(Sternzeichen.fuer(monat: 12, tag: 31).name, "Steinbock")
    }

    func testFaceTimeLink() {
        XCTAssertEqual(FaceTimeLink.url("+49 (151) 234-5678", audio: true)?.absoluteString, "facetime-audio://+491512345678")
        XCTAssertEqual(FaceTimeLink.url("0151 2345678", audio: false)?.absoluteString, "facetime://01512345678")
        XCTAssertNil(FaceTimeLink.url("", audio: false))
        XCTAssertNil(FaceTimeLink.url("12", audio: false))
    }

    func testChatFarbeHex() {
        let rot = ChatFarbe.rgb("#FF0080")
        XCTAssertEqual(rot?.r, 1)
        XCTAssertEqual(rot?.g, 0)
        XCTAssertEqual(rot?.b ?? 0, 128.0 / 255, accuracy: 0.0001)
        XCTAssertNotNil(ChatFarbe.rgb("2F6BFF"))
        XCTAssertNil(ChatFarbe.rgb(""))
        XCTAssertNil(ChatFarbe.rgb("#12345"))
        XCTAssertNil(ChatFarbe.rgb("#+1234F"))
        XCTAssertNil(ChatFarbe.rgb("#GGGGGG"))
        for option in ChatFarbe.auswahl { XCTAssertNotNil(ChatFarbe.rgb(option.hex), option.name) }
    }
}
