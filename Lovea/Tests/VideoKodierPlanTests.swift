import AVFoundation
import CoreGraphics
import XCTest
@testable import Lovea

/// Schalter "Videos schneller senden (Test)": welches Export-Preset, ob `klein` entsteht, ob die
/// Quelle unverändert übernommen wird. Reine Entscheidung, kein Export.
final class VideoKodierPlanTests: XCTestCase {
    private let hd = CGSize(width: 1080, height: 1920)

    func testSchalterAusIstDasAlteVerhalten() {
        let plan = MedienKodierung.videoPlan(schnell: false, upright: hd, dauer: 19, dateiBytes: 1_000_000)
        XCTAssertEqual(plan.weg, .kodieren(preset: AVAssetExportPresetHEVCHighestQuality))
        XCTAssertTrue(plan.mitKlein)
    }

    func testSchalterAusUebernimmtNieUnveraendert() {
        let klein = CGSize(width: 640, height: 360)
        let plan = MedienKodierung.videoPlan(schnell: false, upright: klein, dauer: 5, dateiBytes: 100_000)
        XCTAssertEqual(plan.weg, .kodieren(preset: AVAssetExportPresetHEVCHighestQuality))
    }

    func testSchnellKodiertKleinerOhneKleinFassung() {
        let plan = MedienKodierung.videoPlan(schnell: true, upright: hd, dauer: 19, dateiBytes: 30_000_000)
        XCTAssertEqual(plan.weg, .kodieren(preset: AVAssetExportPreset1280x720))
        XCTAssertFalse(plan.mitKlein)
    }

    func testSchnellUebernimmtKleinesKurzesVideoUnveraendert() {
        // 720p, 10 s, 4 MB = 3,2 Mbit/s
        let plan = MedienKodierung.videoPlan(schnell: true, upright: CGSize(width: 720, height: 1280), dauer: 10, dateiBytes: 4_000_000)
        XCTAssertEqual(plan.weg, .unveraendert)
        XCTAssertFalse(plan.mitKlein)
    }

    func testSchnellKodiertWennDateiZuGross() {
        // 720p, 10 s, 20 MB = 16 Mbit/s
        let plan = MedienKodierung.videoPlan(schnell: true, upright: CGSize(width: 720, height: 1280), dauer: 10, dateiBytes: 20_000_000)
        XCTAssertEqual(plan.weg, .kodieren(preset: AVAssetExportPreset1280x720))
    }

    func testSchnellKodiertWennAufloesungZuHoch() {
        let plan = MedienKodierung.videoPlan(schnell: true, upright: hd, dauer: 10, dateiBytes: 1_000_000)
        XCTAssertEqual(plan.weg, .kodieren(preset: AVAssetExportPreset1280x720))
    }

    func testSchnellKodiertWennLaengerAls30Sekunden() {
        let plan = MedienKodierung.videoPlan(schnell: true, upright: CGSize(width: 720, height: 1280), dauer: 31, dateiBytes: 1_000_000)
        XCTAssertEqual(plan.weg, .kodieren(preset: AVAssetExportPreset1280x720))
    }

    func testSchnellKodiertBeiUnbekannterGroesseOderDauer() {
        let klein = CGSize(width: 720, height: 1280)
        XCTAssertEqual(MedienKodierung.videoPlan(schnell: true, upright: klein, dauer: 10, dateiBytes: 0).weg, .kodieren(preset: AVAssetExportPreset1280x720))
        XCTAssertEqual(MedienKodierung.videoPlan(schnell: true, upright: klein, dauer: 0, dateiBytes: 1_000).weg, .kodieren(preset: AVAssetExportPreset1280x720))
    }

    /// Standard ohne gesetzten Wert ist AN (`bool(forKey:)` würde hier false liefern).
    func testSchalterStandardIstAn() {
        let suite = UserDefaults(suiteName: "VideoKodierPlanTests.\(UUID().uuidString)")!
        XCTAssertTrue(MedienKodierung.videoSchnell(suite))
        suite.set(false, forKey: MedienKodierung.videoSchnellSchluessel)
        XCTAssertFalse(MedienKodierung.videoSchnell(suite))
        suite.set(true, forKey: MedienKodierung.videoSchnellSchluessel)
        XCTAssertTrue(MedienKodierung.videoSchnell(suite))
    }
}
