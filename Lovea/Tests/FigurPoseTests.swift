import XCTest
@testable import Lovea

/// p65 B1: the pose logic of the whole-body figure on the profile stage. Pure numbers, no drawing:
/// which pose a place asks for, where the hips sit when seated, how big the frame of each pose is.
final class FigurPoseTests: XCTestCase {
    private typealias L = FigurPoseLogik

    func testPlatzGibtPose() {
        XCTAssertEqual(L.pose(platz: .sofa, geht: false, liegt: false, geste: false), .sitzenSofa)
        XCTAssertEqual(L.pose(platz: .bett, geht: false, liegt: false, geste: false), .sitzenBettkante)
        XCTAssertEqual(L.pose(platz: .bett, geht: false, liegt: true, geste: false), .liegen)
        XCTAssertEqual(L.pose(platz: .fenster, geht: false, liegt: false, geste: false), .stehen)
        XCTAssertEqual(L.pose(platz: .blumen, geht: false, liegt: false, geste: true), .winken)
    }

    func testGehenGehtVorAllem() {
        for platz in Platz.allCases {
            XCTAssertEqual(L.pose(platz: platz, geht: true, liegt: true, geste: true), .gehen, "\(platz)")
        }
    }

    func testLiegenNurImBett() {
        for platz in Platz.allCases where platz != .bett {
            XCTAssertNotEqual(L.pose(platz: platz, geht: false, liegt: true, geste: false), .liegen, "\(platz)")
        }
    }

    func testSitzenIstEinePose() {
        XCTAssertTrue(FigurPose.sitzenSofa.sitzt)
        XCTAssertTrue(FigurPose.sitzenBettkante.sitzt)
        for pose in FigurPose.allCases where pose != .sitzenSofa && pose != .sitzenBettkante {
            XCTAssertFalse(pose.sitzt, "\(pose)")
        }
        XCTAssertTrue(FigurPose.liegen.liegt)
        XCTAssertEqual(FigurPose.allCases.filter(\.liegt).count, 1)
    }

    func testZustandJePose() {
        XCTAssertEqual(L.zustand(.gehen), .laeuft)
        XCTAssertEqual(L.zustand(.winken), .imChat)
        XCTAssertEqual(L.zustand(.stehen), .ruhig)
        XCTAssertEqual(L.zustand(.sitzenSofa), .ruhig)
        XCTAssertEqual(L.zustand(.liegen, schlaeft: true), .schlaeft)
        XCTAssertEqual(L.zustand(.liegen, schlaeft: false), .ruhig)
    }

    func testSitzHuefteLiegtZwischenTailleUndBoden() {
        for stufe in 0..<L.beinLaengen.count {
            XCTAssertGreaterThan(L.sitzHueftY(stufe: stufe), L.hueftY(stufe: stufe), "stufe \(stufe)")
            XCTAssertLessThan(L.sitzHueftY(stufe: stufe), L.fussY, "stufe \(stufe)")
            // The thigh seen from the front is short but never zero or negative.
            XCTAssertGreaterThan(L.fussY - L.sitzHueftY(stufe: stufe), 40, "stufe \(stufe)")
        }
    }

    func testSitzHoeheBlendetNachStufen() {
        let h: CGFloat = 150
        let klein = L.sitzHoehe(stufe: 0, hoehe: h)
        let gross = L.sitzHoehe(stufe: 2, hoehe: h)
        XCTAssertLessThan(klein, gross, "longer legs sit higher over the floor")
        XCTAssertGreaterThan(klein, 15)
        XCTAssertLessThan(gross, 45)
    }

    func testSitzKorrekturBleibtKlein() {
        // One sofa for everyone: the different leg lengths move the feet by only a few points.
        for hoehe in [CGFloat(110), 150, 190] {
            for stufe in 0..<L.beinLaengen.count {
                XCTAssertLessThanOrEqual(abs(L.sitzKorrektur(stufe: stufe, hoehe: hoehe)), 4, "stufe \(stufe) hoehe \(hoehe)")
            }
        }
        XCTAssertEqual(L.sitzKorrektur(stufe: L.mittelStufe, hoehe: 150), 0, accuracy: 0.0001)
    }

    func testRahmenLiegtQuer() {
        let steh = L.rahmen(.stehen, hoehe: 200)
        XCTAssertEqual(steh.width, 100)
        XCTAssertEqual(steh.height, 200)
        let sitz = L.rahmen(.sitzenSofa, hoehe: 200)
        XCTAssertEqual(sitz, steh, "sitting keeps the standing frame, the body inside is drawn lower")
        let liegt = L.rahmen(.liegen, hoehe: 200)
        XCTAssertEqual(liegt.width, 200)
        XCTAssertEqual(liegt.height, 100)
    }

    func testDrehungNurImLiegen() {
        XCTAssertEqual(L.drehung(.liegen), -90)
        for pose in FigurPose.allCases where pose != .liegen {
            XCTAssertEqual(L.drehung(pose), 0, "\(pose)")
        }
    }

    func testStufeAusGroesse() {
        // The engine reads the height step from the look; the logic must accept any int.
        XCTAssertEqual(L.beinLaenge(stufe: -3), L.beinLaengen[0])
        XCTAssertEqual(L.beinLaenge(stufe: 99), L.beinLaengen[2])
        XCTAssertEqual(L.beinLaenge(stufe: 1), 124)
    }

    func testSitzVersatzGleichZeichner() {
        // The engine drops the upper body to knee height minus 4: half the leg minus 4.
        XCTAssertEqual(L.sitzVersatz(beinLaenge: 124), 58)
        XCTAssertEqual(L.sitzHueftY(stufe: 1), L.hueftY(stufe: 1) + 58)
    }
}
