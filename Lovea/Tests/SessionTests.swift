import XCTest
@testable import Lovea

/// Layer actions through the studio model: every one is exactly one undo step (Z-4.3, Z-5.4, Z-5.6, Z-6.3).
@MainActor
final class SessionTests: XCTestCase {
    private func makeSession(layers: Int = 3) async throws -> DrawingSession {
        let library = TestGPU.library()
        let artwork = library.createArtwork(name: "Ebenen", projectID: nil, format: .custom, customWidth: 64, customHeight: 64)
        let session = DrawingSession(artworkID: artwork.id, library: library)
        await session.engine?.loading?.value
        for _ in 1..<layers { session.addPaintLayer() }
        return session
    }

    private func assertOneUndoStep(_ name: String, _ action: (DrawingSession) async -> Void) async throws {
        let session = try await makeSession()
        let before = session.document.layers
        await action(session)
        XCTAssertNotEqual(session.document.layers, before, "\(name) changed nothing")
        session.undo()
        XCTAssertEqual(session.document.layers, before, "\(name) undo")
        session.redo()
        XCTAssertNotEqual(session.document.layers, before, "\(name) redo")
    }

    func testEveryLayerActionIsOneUndoStep() async throws {
        try await assertOneUndoStep("anlegen") { $0.addPaintLayer() }
        try await assertOneUndoStep("löschen") { $0.deleteLayer($0.activeLayerID) }
        try await assertOneUndoStep("duplizieren") { $0.duplicateLayer($0.activeLayerID) }
        try await assertOneUndoStep("umbenennen") { $0.renameLayer($0.activeLayerID, to: "Neu") }
        try await assertOneUndoStep("Reihenfolge") { $0.moveLayer(from: IndexSet(integer: 0), to: 3) }
        try await assertOneUndoStep("Sichtbarkeit") { $0.toggleVisibility($0.activeLayerID) }
        try await assertOneUndoStep("Sperre") { $0.toggleLock($0.activeLayerID) }
        try await assertOneUndoStep("Deckkraft") { session in
            for value in stride(from: 0.9, through: 0.3, by: -0.1) { session.setOpacityLive(value, for: session.activeLayerID) }
            session.endOpacityGesture()
        }
        try await assertOneUndoStep("Blend Mode") { $0.setBlendMode(.multiply, for: $0.activeLayerID) }
        try await assertOneUndoStep("Clipping") { $0.toggleClipping($0.activeLayerID) }
        try await assertOneUndoStep("Alpha Lock") { $0.toggleAlphaLock($0.activeLayerID) }
        try await assertOneUndoStep("zusammenführen") { $0.mergeDown($0.activeLayerID) }
    }

    func testImageTransformIsOneUndoStep() async throws {
        let session = try await makeSession(layers: 1)
        let photo = RasterOps.encode(RasterOps.Pixels(bytes: [UInt8](repeating: 200, count: 16 * 16 * 4), width: 16, height: 16))!
        await session.importPhoto(photo, asTemplate: false)
        session.commitTransform()
        let before = session.document.layers
        session.beginTransform()
        session.updateTransform(LayerTransform(offsetX: 4, scale: 1.5))
        session.commitTransform()
        XCTAssertEqual(session.activeLayer?.transform.scale, 1.5)
        session.undo()
        XCTAssertEqual(session.document.layers, before)
    }

    func testOpacityGestureIsOneStep() async throws {
        let session = try await makeSession(layers: 1)
        for value in [0.9, 0.7, 0.5, 0.3] { session.setOpacityLive(value, for: session.activeLayerID) }
        session.endOpacityGesture()
        XCTAssertEqual(session.activeLayer?.opacity, 0.3)
        session.undo()
        XCTAssertEqual(session.activeLayer?.opacity, 1)
        XCTAssertFalse(session.canUndo)
    }

    // MARK: Z-5.4

    func testMoveLayerByDragAndUndo() async throws {
        let session = try await makeSession()
        let ids = session.document.layers.map(\.id)
        // Shown topmost first: [2, 1, 0]. Drag the top row to the bottom.
        session.moveLayer(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(session.document.layers.map(\.id), [ids[2], ids[0], ids[1]])
        session.undo()
        XCTAssertEqual(session.document.layers.map(\.id), ids)
    }

    // MARK: Z-5.6

    func testNewDuplicateRenameLockHideDelete() async throws {
        let session = try await makeSession(layers: 1)
        session.addPaintLayer()
        XCTAssertEqual(session.document.layers.count, 2)
        let id = session.activeLayerID
        session.renameLayer(id, to: "  Linien  ")
        XCTAssertEqual(session.activeLayer?.name, "Linien")
        session.toggleLock(id)
        XCTAssertEqual(session.activeLayer?.isLocked, true)
        XCTAssertFalse(session.ensureDrawable())
        session.toggleVisibility(id)
        XCTAssertEqual(session.activeLayer?.isVisible, false)
        session.duplicateLayer(id)
        XCTAssertEqual(session.document.layers.count, 3)
        XCTAssertEqual(session.activeLayer?.name, "Linien Kopie")
        let hasContent = await session.layerHasContent(session.activeLayerID)
        XCTAssertFalse(hasContent)
        session.deleteLayer(session.activeLayerID)
        XCTAssertEqual(session.document.layers.count, 2)
        session.undo()
        XCTAssertEqual(session.document.layers.count, 3)
    }

    // MARK: Z-6.3

    func testTemplateIsOneUndoStep() async throws {
        let session = try await makeSession(layers: 1)
        let before = session.document.layers
        let photo = RasterOps.encode(RasterOps.Pixels(bytes: [UInt8](repeating: 255, count: 32 * 32 * 4), width: 32, height: 32))!
        await session.importPhoto(photo, asTemplate: true)

        let template = try XCTUnwrap(session.document.layers.first)
        XCTAssertEqual(template.kind, .image)
        XCTAssertEqual(template.name, "Schablone")
        XCTAssertEqual(template.opacity, 0.35, accuracy: 0.0001)
        XCTAssertTrue(template.isLocked)
        XCTAssertEqual(session.document.layers.last?.name, "Zeichnen")
        XCTAssertEqual(session.document.layers.last?.kind, .paint)
        XCTAssertEqual(session.activeLayer?.name, "Zeichnen")

        session.undo()
        XCTAssertEqual(session.document.layers, before)
    }

    func testImportAsLayerStartsTransformAndCancelRemovesIt() async throws {
        let session = try await makeSession(layers: 1)
        let before = session.document.layers
        let photo = RasterOps.encode(RasterOps.Pixels(bytes: [UInt8](repeating: 255, count: 16 * 16 * 4), width: 16, height: 16))!
        await session.importPhoto(photo, asTemplate: false)
        XCTAssertTrue(session.isTransforming)
        XCTAssertEqual(session.tool, .transform)
        session.cancelTransform()
        XCTAssertEqual(session.document.layers.map(\.id), before.map(\.id))
    }
}
