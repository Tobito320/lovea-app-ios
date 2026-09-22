import XCTest
@testable import Lovea

@MainActor
final class DrawingStoreTests: XCTestCase {
    func testFinishingAStrokeAddsItToTheActiveLayer() {
        let store = DrawingStore(document: .empty)

        store.beginStroke(at: StrokePoint(x: 10, y: 10, pressure: 0.5))
        store.appendPoint(StrokePoint(x: 20, y: 20, pressure: 1))
        store.endStroke()

        XCTAssertEqual(store.document.layers[0].strokes.count, 1)
        XCTAssertEqual(store.document.layers[0].strokes[0].points.count, 2)
    }

    func testUndoAndRedoRestoreTheLastStroke() {
        let store = DrawingStore(document: .empty)
        store.beginStroke(at: StrokePoint(x: 0, y: 0, pressure: 1))
        store.appendPoint(StrokePoint(x: 8, y: 8, pressure: 1))
        store.endStroke()

        store.undo()
        XCTAssertTrue(store.document.layers[0].strokes.isEmpty)

        store.redo()
        XCTAssertEqual(store.document.layers[0].strokes.count, 1)
    }

    func testAddingALayerMakesItActive() {
        let store = DrawingStore(document: .empty)

        store.addLayer()

        XCTAssertEqual(store.document.layers.count, 2)
        XCTAssertEqual(store.activeLayerID, store.document.layers[1].id)
    }

    func testHiddenLayerStaysInTheDocument() {
        let store = DrawingStore(document: .empty)
        let layerID = store.document.layers[0].id

        store.toggleLayerVisibility(layerID)

        XCTAssertFalse(store.document.layers[0].isVisible)
    }
}
