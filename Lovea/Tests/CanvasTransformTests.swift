import CoreGraphics
import XCTest
@testable import Lovea

final class CanvasTransformTests: XCTestCase {
    func testPanAddsTranslationToOffset() {
        var transform = CanvasTransform(
            scale: 1,
            rotation: 0,
            offset: CGPoint(x: 12, y: -8)
        )

        transform.pan(by: CGPoint(x: 5, y: 3))

        XCTAssertEqual(transform.offset.x, 17, accuracy: 0.000_001)
        XCTAssertEqual(transform.offset.y, -5, accuracy: 0.000_001)
    }

    func testZoomKeepsTheFocusedDocumentPointUnderTheFingers() {
        var transform = CanvasTransform(
            scale: 1.5,
            rotation: .pi / 6,
            offset: CGPoint(x: 24, y: -11)
        )
        let focus = CGPoint(x: 180, y: 260)
        let focusedDocumentPoint = transform.documentPoint(fromScreen: focus)

        transform.zoom(by: 1.75, around: focus)

        let mappedFocus = transform.screenPoint(fromDocument: focusedDocumentPoint)
        XCTAssertEqual(mappedFocus.x, focus.x, accuracy: 0.000_001)
        XCTAssertEqual(mappedFocus.y, focus.y, accuracy: 0.000_001)
    }

    func testZoomClampsScaleBetweenQuarterAndSixTimes() {
        var transform = CanvasTransform()

        transform.zoom(by: 100, around: CGPoint(x: 40, y: 70))
        XCTAssertEqual(transform.scale, 6, accuracy: 0.000_001)

        transform.zoom(by: 0.001, around: CGPoint(x: 40, y: 70))
        XCTAssertEqual(transform.scale, 0.25, accuracy: 0.000_001)
    }

    func testRotationKeepsTheFocusedDocumentPointUnderTheFingers() {
        var transform = CanvasTransform(
            scale: 2,
            rotation: .pi / 8,
            offset: CGPoint(x: -35, y: 46)
        )
        let focus = CGPoint(x: 210, y: 125)
        let focusedDocumentPoint = transform.documentPoint(fromScreen: focus)

        transform.rotate(by: .pi / 3, around: focus)

        let mappedFocus = transform.screenPoint(fromDocument: focusedDocumentPoint)
        XCTAssertEqual(mappedFocus.x, focus.x, accuracy: 0.000_001)
        XCTAssertEqual(mappedFocus.y, focus.y, accuracy: 0.000_001)
    }

    func testScreenToDocumentMappingReversesScaleRotationAndOffset() {
        let transform = CanvasTransform(
            scale: 2,
            rotation: .pi / 2,
            offset: CGPoint(x: 100, y: 50)
        )

        let documentPoint = transform.documentPoint(fromScreen: CGPoint(x: 60, y: 70))

        XCTAssertEqual(documentPoint.x, 10, accuracy: 0.000_001)
        XCTAssertEqual(documentPoint.y, 20, accuracy: 0.000_001)
    }
}
