import XCTest
@testable import Lovea

/// Sende-Weg: das Schnitt-Ergebnis ersetzt das Original, ohne Schnitt bleibt das Original.
final class SnapEditorSchnittTests: XCTestCase {
    private let original = URL(fileURLWithPath: "/tmp/original.mov")
    private let geschnitten = URL(fileURLWithPath: "/tmp/snap-schnitt-1.mov")

    func testSendeQuelleNimmtGeschnittenes() {
        XCTAssertEqual(SnapEditor.sendeQuelle(original: original, geschnitten: geschnitten), geschnitten)
    }

    func testSendeQuelleOhneSchnittIstOriginal() {
        XCTAssertEqual(SnapEditor.sendeQuelle(original: original, geschnitten: nil), original)
    }

    func testUnveraenderterPlanLiefertQuelleZurueck() async {
        let plan = SnapSchnitt(dauer: 10)
        let ergebnis = await SnapSchnittExport.exportieren(quelle: original, plan: plan)
        XCTAssertEqual(ergebnis, original)
    }
}
