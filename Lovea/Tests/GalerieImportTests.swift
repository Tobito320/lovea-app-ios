import XCTest
@testable import Lovea

final class GalerieImportTests: XCTestCase {
    func testUprightOrientationKeepsWidthAndHeight() {
        let size = GalerieImport.canvasSize(pixelWidth: 1200, pixelHeight: 800, orientation: 1)
        XCTAssertEqual(size.width, 1200)
        XCTAssertEqual(size.height, 800)
    }

    func testRotatedOrientationSwapsWidthAndHeight() {
        // EXIF 6 = rotated 90° CW, same case MedienKodierung.foto treats as swapped.
        let size = GalerieImport.canvasSize(pixelWidth: 1200, pixelHeight: 800, orientation: 6)
        XCTAssertEqual(size.width, 800)
        XCTAssertEqual(size.height, 1200)
    }

    func testResultIsClampedToSafeRange() {
        let size = GalerieImport.canvasSize(pixelWidth: 9_000, pixelHeight: 10, orientation: 1)
        XCTAssertEqual(size.width, 4_096)
        XCTAssertEqual(size.height, 64)
    }
}
