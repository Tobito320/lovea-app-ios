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
}
