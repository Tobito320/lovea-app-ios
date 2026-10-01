import CoreImage
import XCTest
@testable import Lovea

/// Reine Rezept-Funktionen hinter dem Filterkarussell (R9): jeder Filter muss die Ausdehnung des
/// Eingabebilds erhalten (sonst verschiebt sich das Ergebnis gegen Overlay/Export), `.original`
/// muss die Identität sein.
final class SnapFilterTests: XCTestCase {
    private let testBild = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))

    func testAlleFilterBehaltenDieAusdehnung() {
        for filter in SnapFilter.allCases {
            let ergebnis = filter.anwenden(auf: testBild)
            XCTAssertEqual(ergebnis.extent, testBild.extent, "\(filter.rawValue) verändert die Ausdehnung")
        }
    }

    func testOriginalIstIdentitaet() {
        let context = CIContext()
        guard let erwartet = context.createCGImage(testBild, from: testBild.extent),
              let ergebnis = context.createCGImage(SnapFilter.original.anwenden(auf: testBild), from: testBild.extent)
        else { return XCTFail("Rendern fehlgeschlagen") }
        XCTAssertEqual(erwartet.dataProvider?.data, ergebnis.dataProvider?.data)
    }

    func testFuenfzehnFilterMitDeutschenAnzeigenamen() {
        XCTAssertEqual(SnapFilter.allCases.count, 15)
        XCTAssertTrue(SnapFilter.allCases.allSatisfy { !$0.anzeigename.isEmpty })
    }

    func testJedeFilterIDIstEindeutig() {
        let ids = Set(SnapFilter.allCases.map(\.id))
        XCTAssertEqual(ids.count, SnapFilter.allCases.count)
    }

    /// R9-Review: `.film`s Korn (`CIRandomGenerator`) pro Frame angewendet wäre Flackern im Video —
    /// `video: true` lässt es weg. Zwei unabhängige Aufrufe müssen bitgenau gleich sein: ohne Korn gibt
    /// es nichts Zufälliges mehr im Rezept, das zwei Aufrufe auseinanderlaufen lassen könnte.
    func testFilmOhneKornImVideoModusIstDeterministisch() {
        let context = CIContext()
        let a = SnapFilter.film.anwenden(auf: testBild, video: true)
        let b = SnapFilter.film.anwenden(auf: testBild, video: true)
        guard let bildA = context.createCGImage(a, from: a.extent), let bildB = context.createCGImage(b, from: b.extent) else { return XCTFail("Rendern fehlgeschlagen") }
        XCTAssertEqual(bildA.dataProvider?.data, bildB.dataProvider?.data)
    }

    func testFilmImVideoModusBehaeltEbenfallsDieAusdehnung() {
        let ergebnis = SnapFilter.film.anwenden(auf: testBild, video: true)
        XCTAssertEqual(ergebnis.extent, testBild.extent)
    }
}
