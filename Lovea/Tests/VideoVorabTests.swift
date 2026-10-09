import XCTest
@testable import Lovea

/// Schalter "Videos vorab hochladen (Test)": wann das Vorab-Kodieren und -Hochladen startet, wann es
/// abgebrochen wird und was beim Senden passiert. Reine Entscheidung, kein Export, kein Upload.
final class VideoVorabTests: XCTestCase {

    func testSchalterStandardAn() {
        let suite = UserDefaults(suiteName: "VideoVorabTests-schalter")!
        suite.removePersistentDomain(forName: "VideoVorabTests-schalter")
        XCTAssertEqual(VideoVorab.schluessel, "lovea.videoVorab")
        XCTAssertTrue(VideoVorab.an(suite))
        suite.set(false, forKey: VideoVorab.schluessel)
        XCTAssertFalse(VideoVorab.an(suite))
        suite.set(true, forKey: VideoVorab.schluessel)
        XCTAssertTrue(VideoVorab.an(suite))
    }

    func testStartetNurBeiSchalterAnUndWennNichtsAnderesLaeuft() {
        XCTAssertTrue(VideoVorab.starten(schalter: true, laufende: 0))
        XCTAssertFalse(VideoVorab.starten(schalter: false, laufende: 0))
        XCTAssertFalse(VideoVorab.starten(schalter: true, laufende: 1))
    }

    func testBrichtNurAbWasNichtMehrImEntwurfIst() {
        let a = UUID(), b = UUID(), c = UUID()
        XCTAssertEqual(VideoVorab.abzubrechen(offen: [a, b], imEntwurf: [b, c]), [a])
        XCTAssertEqual(VideoVorab.abzubrechen(offen: [a, b], imEntwurf: [a, b]), [])
        XCTAssertEqual(VideoVorab.abzubrechen(offen: [a], imEntwurf: []), [a])
        XCTAssertEqual(VideoVorab.abzubrechen(offen: [], imEntwurf: [a]), [])
    }

    func testStandAusErgebnis() {
        XCTAssertEqual(VideoVorab.stand(kodiert: true, hochgeladen: true), .fertig)
        XCTAssertEqual(VideoVorab.stand(kodiert: true, hochgeladen: false), .nurKodiert)
        XCTAssertEqual(VideoVorab.stand(kodiert: false, hochgeladen: false), .gescheitert)
        XCTAssertEqual(VideoVorab.stand(kodiert: false, hochgeladen: true), .gescheitert)
    }

    func testSendenOhneVorabIstDerHeutigeWeg() {
        XCTAssertEqual(VideoVorab.weg(beimSenden: .keiner), .heutigerWeg)
    }

    func testSendenWartetAufLaufendesVorab() {
        XCTAssertEqual(VideoVorab.weg(beimSenden: .offen), .aufEndeWarten)
    }

    func testSendenNachFertigemVorabSchicktNurDieOp() {
        XCTAssertEqual(VideoVorab.weg(beimSenden: .fertig), .nurOp)
    }

    func testUploadFehlerKodiertNichtNochMal() {
        XCTAssertEqual(VideoVorab.weg(beimSenden: .nurKodiert), .opDannHochladen)
    }

    func testKodierFehlerFaelltAufHeutigenWegZurueck() {
        XCTAssertEqual(VideoVorab.weg(beimSenden: .gescheitert), .heutigerWeg)
    }

    func testNachDemWartenEntscheidetDasErgebnis() {
        // Der Ablauf in `ChatMedien.videoVorabSenden`: offen -> warten -> neuer Stand -> Weg.
        XCTAssertEqual(VideoVorab.weg(beimSenden: VideoVorab.stand(kodiert: true, hochgeladen: true)), .nurOp)
        XCTAssertEqual(VideoVorab.weg(beimSenden: VideoVorab.stand(kodiert: true, hochgeladen: false)), .opDannHochladen)
        XCTAssertEqual(VideoVorab.weg(beimSenden: VideoVorab.stand(kodiert: false, hochgeladen: false)), .heutigerWeg)
    }
}
