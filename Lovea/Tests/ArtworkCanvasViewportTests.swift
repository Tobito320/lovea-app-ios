import CoreGraphics
import XCTest
@testable import Lovea

final class ArtworkCanvasViewportTests: XCTestCase {
    func testFitCentersEntireDocumentOnPortraitScreen() {
        var viewport = ArtworkCanvasViewport()
        viewport.fit(document: CGSize(width: 2048, height: 2048), screen: CGSize(width: 400, height: 800))

        let topLeft = viewport.screenPoint(.zero)
        let bottomRight = viewport.screenPoint(CGPoint(x: 2048, y: 2048))
        XCTAssertGreaterThanOrEqual(topLeft.x, 0)
        XCTAssertGreaterThanOrEqual(topLeft.y, 0)
        XCTAssertLessThanOrEqual(bottomRight.x, 400)
        XCTAssertLessThanOrEqual(bottomRight.y, 800)
        XCTAssertEqual((topLeft.x + bottomRight.x) / 2, 200, accuracy: 0.001)
        XCTAssertEqual((topLeft.y + bottomRight.y) / 2, 400, accuracy: 0.001)
    }

    func testScreenDocumentRoundTripAfterNavigation() {
        var viewport = ArtworkCanvasViewport()
        viewport.fit(document: CGSize(width: 2048, height: 1536), screen: CGSize(width: 390, height: 844))
        viewport.zoom(by: 2.7, around: CGPoint(x: 120, y: 330))
        viewport.rotate(by: .pi / 5, around: CGPoint(x: 190, y: 420))
        viewport.pan(by: CGPoint(x: 37, y: -24))

        let original = CGPoint(x: 1050, y: 640)
        let mapped = viewport.screenPoint(original)
        let restored = viewport.documentPoint(mapped)
        XCTAssertEqual(restored.x, original.x, accuracy: 0.001)
        XCTAssertEqual(restored.y, original.y, accuracy: 0.001)
    }
}
