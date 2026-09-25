import XCTest
@testable import Lovea

/// Brief F2: the redesigned faces replace the old ones once, a later editor choice sticks.
final class GesichtNeuTests: XCTestCase {
    func testNewFaceNamesAppended() {
        XCTAssertEqual(FigurAussehen.gesichtsformen.count, 9)
        XCTAssertEqual(FigurAussehen.gesichtsformen[6], "Kantig lang")
        XCTAssertEqual(FigurAussehen.gesichtsformen[7], "Schmal markant")
        XCTAssertEqual(FigurAussehen.gesichtsformen[8], "Schmal weich")
    }

    func testStandardLooksUseNewFaces() {
        XCTAssertEqual(FigurAussehen.standard(for: .ahmed).gesichtsform, 7)
        XCTAssertEqual(FigurAussehen.standard(for: .annika).gesichtsform, 8)
        XCTAssertEqual(FigurAussehen.standard(for: .ahmed).gesichtV2, true)
    }

    func testSavedLookWithoutFlagGetsNewFace() {
        var a = FigurAussehen()
        a.gesichtsform = 6
        a.frisur = 3
        a.haut = 12
        let ahmed = FigurAussehen.mitNeuemGesicht(a, .ahmed)
        XCTAssertEqual(ahmed.gesichtsform, 7)
        XCTAssertEqual(ahmed.gesichtV2, true)
        XCTAssertEqual(ahmed.frisur, 79)
        XCTAssertEqual(ahmed.haut, 12)
        let annika = FigurAussehen.mitNeuemGesicht(a, .annika)
        XCTAssertEqual(annika.gesichtsform, 8)
        XCTAssertEqual(annika.frisur, 56)
    }

    func testChosenFaceSticks() {
        var a = FigurAussehen()
        a.gesichtsform = 2
        a.gesichtV2 = true
        XCTAssertEqual(FigurAussehen.mitNeuemGesicht(a, .ahmed).gesichtsform, 2)
    }

    func testOldJsonDecodes() throws {
        let json = Data(#"{"haut":12,"gesichtsform":6,"frisur":79}"#.utf8)
        let a = try JSONDecoder().decode(FigurAussehen.self, from: json)
        XCTAssertEqual(a.gesichtsform, 6)
        XCTAssertNil(a.gesichtV2)
    }

    func testFlagRoundTrips() throws {
        var a = FigurAussehen()
        a.gesichtV2 = true
        let b = try JSONDecoder().decode(FigurAussehen.self, from: JSONEncoder().encode(a))
        XCTAssertEqual(b.gesichtV2, true)
    }
}
