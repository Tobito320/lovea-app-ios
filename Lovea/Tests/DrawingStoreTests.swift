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

    func testLayerOpacityIsClampedToValidRange() {
        let store = DrawingStore(document: .empty)
        let layerID = store.document.layers[0].id

        store.updateLayerOpacity(-0.5, id: layerID)
        XCTAssertEqual(store.document.layers[0].opacity, 0)

        store.updateLayerOpacity(1.5, id: layerID)
        XCTAssertEqual(store.document.layers[0].opacity, 1)
    }

    func testLayerOpacityCanBeUndoneAndRedone() {
        let store = DrawingStore(document: .empty)
        let layerID = store.document.layers[0].id

        store.updateLayerOpacity(0.4, id: layerID)
        store.undo()
        XCTAssertEqual(store.document.layers[0].opacity, 1)

        store.redo()
        XCTAssertEqual(store.document.layers[0].opacity, 0.4)
    }

    func testNewLayerOpacityChangeDiscardsRedo() {
        let store = DrawingStore(document: .empty)
        let layerID = store.document.layers[0].id

        store.updateLayerOpacity(0.4, id: layerID)
        store.undo()
        XCTAssertTrue(store.canRedo)

        store.updateLayerOpacity(0.7, id: layerID)
        XCTAssertFalse(store.canRedo)
    }

    func testRenamingLayerCanBeUndone() {
        let store = DrawingStore(document: .empty)
        let layerID = store.document.layers[0].id

        store.renameLayer("Skizze", id: layerID)
        XCTAssertEqual(store.document.layers[0].name, "Skizze")

        store.undo()
        XCTAssertEqual(store.document.layers[0].name, "Ebene 1")
    }

    func testBrushWidthIsClampedToSupportedRange() {
        let store = DrawingStore(document: .empty)

        store.setBrushWidth(0)
        XCTAssertEqual(store.brushWidth, 1)

        store.setBrushWidth(201)
        XCTAssertEqual(store.brushWidth, 200)
    }

    func testBrushOpacityIsClampedToSupportedRange() {
        let store = DrawingStore(document: .empty)

        store.setBrushOpacity(-0.1)
        XCTAssertEqual(store.opacity, 0)

        store.setBrushOpacity(1.1)
        XCTAssertEqual(store.opacity, 1)
    }

    func testFinishedStrokeStoresCurrentBrushAppearance() {
        let store = DrawingStore(document: .empty)
        let color = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        store.color = color
        store.setBrushWidth(42)
        store.setBrushOpacity(0.35)

        store.beginStroke(at: StrokePoint(x: 10, y: 20, pressure: 1))
        store.endStroke()

        let stroke = store.document.layers[0].strokes[0]
        XCTAssertEqual(stroke.width, 42)
        XCTAssertEqual(stroke.opacity, 0.35)
        XCTAssertEqual(stroke.color, color)
    }
}
