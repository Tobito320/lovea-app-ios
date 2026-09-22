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

    /// Z-10.5: mirroring flips only the view; document points still map back exactly.
    func testMirroredViewRoundTrip() {
        var viewport = ArtworkCanvasViewport()
        viewport.fit(document: CGSize(width: 1000, height: 800), screen: CGSize(width: 500, height: 400))
        let left = viewport.screenPoint(CGPoint(x: 100, y: 400))
        viewport.setMirrored(true, around: CGPoint(x: 250, y: 200))
        let mirrored = viewport.screenPoint(CGPoint(x: 100, y: 400))
        XCTAssertGreaterThan(mirrored.x, left.x, "a point on the left now shows on the right")
        viewport.rotate(by: 0.4, around: CGPoint(x: 100, y: 100))
        let original = CGPoint(x: 321, y: 123)
        let restored = viewport.documentPoint(viewport.screenPoint(original))
        XCTAssertEqual(restored.x, original.x, accuracy: 0.001)
        XCTAssertEqual(restored.y, original.y, accuracy: 0.001)
    }
}
