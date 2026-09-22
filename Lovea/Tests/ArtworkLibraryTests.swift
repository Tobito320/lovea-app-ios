import PencilKit
import UIKit
import XCTest
@testable import Lovea

@MainActor
final class ArtworkLibraryTests: XCTestCase {
    func testProjectsAndArtworksSurviveReload() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let project = library.createProject(name: "Skizzen")
        let artwork = library.createArtwork(
            name: "Katze",
            projectID: project.id,
            format: .portrait3x4,
            background: .white
        )

        let reloaded = ArtworkLibrary(rootURL: root)

        XCTAssertEqual(reloaded.projects.map(\.name), ["Skizzen"])
        XCTAssertEqual(reloaded.artworks.count, 1)
        XCTAssertEqual(reloaded.artworks[0].id, artwork.id)
        XCTAssertEqual(reloaded.artworks[0].projectID, project.id)
        XCTAssertEqual(reloaded.artworks[0].name, "Katze")
    }

    func testArtworkCanMoveDuplicateAndLeaveDeletedProject() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let project = library.createProject(name: "A")
        let artwork = library.createArtwork(
            name: "Bild",
            projectID: nil,
            format: .square,
            background: .transparent
        )

        library.moveArtwork(artwork.id, to: project.id)
        XCTAssertEqual(library.document(artwork.id)?.projectID, project.id)

        let duplicate = try XCTUnwrap(library.duplicateArtwork(artwork.id))
        XCTAssertNotEqual(duplicate.id, artwork.id)
        XCTAssertEqual(duplicate.projectID, project.id)

        library.deleteProject(project.id, deleteArtworks: false)
        XCTAssertTrue(library.projects.isEmpty)
        XCTAssertEqual(library.artworks.count, 2)
        XCTAssertTrue(library.artworks.allSatisfy { $0.projectID == nil })
    }

    func testCustomCanvasIsClampedToSafeRange() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Groß",
            projectID: nil,
            format: .custom,
            customWidth: 9_000,
            customHeight: 1,
            background: .dark
        )

        XCTAssertEqual(artwork.canvasWidth, 4_096)
        XCTAssertEqual(artwork.canvasHeight, 64)
    }

    func testTemplateImportCreatesLockedReferenceAndPaintLayerAbove() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Schablone",
            projectID: nil,
            format: .square,
            background: .white
        )
        let session = DrawingSession(artworkID: artwork.id, library: library)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }

        session.addImageLayer(data: try XCTUnwrap(image.pngData()), asTemplate: true)

        let template = try XCTUnwrap(session.document.layers.first)
        XCTAssertEqual(template.name, "Schablone")
        XCTAssertEqual(template.kind, .image)
        XCTAssertEqual(template.opacity, 0.35, accuracy: 0.0001)
        XCTAssertEqual(template.isLocked, true)
        XCTAssertEqual(session.activeLayer?.kind, .paint)
        XCTAssertEqual(session.activeLayer?.name, "Zeichnen")
    }

    func testMetalStrokesPersistBesideUnchangedLegacyDrawingAndUndoRedo() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Metal",
            projectID: nil,
            format: .square,
            background: .white
        )
        let layer = try XCTUnwrap(artwork.layers.first)
        let legacy = PKDrawing().dataRepresentation()
        library.saveLayerData(legacy, layer: layer, artworkID: artwork.id)

        let session = DrawingSession(artworkID: artwork.id, library: library)
        session.beginMetalStroke(at: StrokePoint(x: 10, y: 20, pressure: 0.5))
        session.appendMetalStrokePoint(StrokePoint(x: 30, y: 40, pressure: 1))
        session.endMetalStroke()

        XCTAssertEqual(session.metalStrokes(for: layer.id).count, 1)
        XCTAssertEqual(library.layerData(layer, artworkID: artwork.id), legacy)
        XCTAssertTrue(session.canUndo)

        session.undo()
        XCTAssertTrue(session.metalStrokes(for: layer.id).isEmpty)
        XCTAssertTrue(session.canRedo)

        session.redo()
        XCTAssertEqual(session.metalStrokes(for: layer.id).first?.points.count, 2)

        let reloadedLibrary = ArtworkLibrary(rootURL: root)
        let reloadedSession = DrawingSession(artworkID: artwork.id, library: reloadedLibrary)
        XCTAssertEqual(reloadedSession.metalStrokes(for: layer.id), session.metalStrokes(for: layer.id))
        XCTAssertEqual(reloadedLibrary.layerData(layer, artworkID: artwork.id), legacy)
        XCTAssertNotNil(ArtworkRenderer.legacyPaintImage(
            layer,
            document: artwork,
            library: reloadedLibrary
        ))
    }

    func testDuplicatedPaintLayerKeepsMetalStrokes() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Kopie",
            projectID: nil,
            format: .square,
            background: .white
        )
        let session = DrawingSession(artworkID: artwork.id, library: library)
        let originalID = session.activeLayerID
        session.beginMetalStroke(at: StrokePoint(x: 5, y: 8, pressure: 1))
        session.endMetalStroke()
        session.duplicateLayer(originalID)

        XCTAssertNotEqual(session.activeLayerID, originalID)
        XCTAssertEqual(session.metalStrokes(for: session.activeLayerID), session.metalStrokes(for: originalID))
        let copy = try XCTUnwrap(session.activeLayer)
        XCTAssertEqual(library.metalStrokes(for: copy, artworkID: artwork.id).count, 1)
    }

    func testPressureAndStabilizerSettingsAreCapturedPerStrokeAndSurviveReload() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Druck",
            projectID: nil,
            format: .square,
            background: .white
        )
        let session = DrawingSession(artworkID: artwork.id, library: library)
        let layerID = session.activeLayerID
        session.pressureControlsSize = false
        session.pressureControlsOpacity = true
        session.stabilizer = 9
        session.beginMetalStroke(at: StrokePoint(x: 1, y: 2, pressure: 0.4))
        session.pressureControlsSize = true
        session.pressureControlsOpacity = false
        session.stabilizer = 0
        session.endMetalStroke()

        let stroke = try XCTUnwrap(session.metalStrokes(for: layerID).first)
        XCTAssertFalse(stroke.pressureControlsSize)
        XCTAssertTrue(stroke.pressureControlsOpacity)
        XCTAssertEqual(stroke.stabilizer, 9)

        session.undo()
        session.redo()
        let reloaded = DrawingSession(artworkID: artwork.id, library: ArtworkLibrary(rootURL: root))
        XCTAssertEqual(reloaded.metalStrokes(for: layerID).first, stroke)
    }

    func testOldMetalSidecarDecodesWithPreviousPressureBehavior() throws {
        let json = #"[{"id":"DE5E401B-99F6-474C-9880-32F47A6DB92A","points":[{"x":1,"y":2,"pressure":0.4,"timestamp":0}],"color":{"red":1,"green":0,"blue":0,"alpha":1},"width":7,"opacity":1,"tool":"brush","brushPreset":"pen"}]"#

        let strokes = try JSONDecoder().decode([MetalPaintStroke].self, from: Data(json.utf8))
        let stroke = try XCTUnwrap(strokes.first)
        XCTAssertTrue(stroke.pressureControlsSize)
        XCTAssertFalse(stroke.pressureControlsOpacity)
        XCTAssertEqual(stroke.stabilizer, 0)
    }

    func testMetalStrokeSidecarAppearsInLayerImageAndExport() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Metal",
            projectID: nil,
            format: .custom,
            customWidth: 64,
            customHeight: 64,
            background: .white
        )
        let layer = try XCTUnwrap(artwork.layers.first)
        let stroke = MetalPaintStroke(
            points: [
                StrokePoint(x: 12, y: 32, pressure: 1),
                StrokePoint(x: 52, y: 32, pressure: 1),
            ],
            color: .red,
            width: 14,
            opacity: 1,
            tool: .brush,
            brushPreset: "pen"
        )
        library.saveMetalStrokes([stroke], for: layer, artworkID: artwork.id)

        let layerImage = try XCTUnwrap(ArtworkRenderer.layerImage(layer, document: artwork, library: library))
        let export = ArtworkRenderer.render(document: artwork, library: library)
        let layerPixel = try XCTUnwrap(RasterTools.sampleColor(in: layerImage, at: CGPoint(x: 32, y: 32)))
        let exportPixel = try XCTUnwrap(RasterTools.sampleColor(in: export, at: CGPoint(x: 32, y: 32)))

        XCTAssertGreaterThan(layerPixel.red, 0.8)
        XCTAssertLessThan(layerPixel.green, 0.5)
        XCTAssertGreaterThan(exportPixel.red, 0.8)
        XCTAssertLessThan(exportPixel.green, 0.5)
    }

    func testMergeDownDoesNotBakeOpaqueCanvasBackgroundIntoLayer() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Merge",
            projectID: nil,
            format: .custom,
            customWidth: 64,
            customHeight: 64,
            background: .white
        )
        let session = DrawingSession(artworkID: artwork.id, library: library)
        session.addPaintLayer()
        session.beginMetalStroke(at: StrokePoint(x: 32, y: 32, pressure: 1))
        session.endMetalStroke()
        session.mergeActiveDown()

        let merged = try XCTUnwrap(session.activeLayer)
        let image = try XCTUnwrap(ArtworkRenderer.layerImage(merged, document: session.document, library: library))
        let corner = try XCTUnwrap(RasterTools.sampleColor(in: image, at: CGPoint(x: 1, y: 1)))
        XCTAssertLessThan(corner.alpha, 0.01)
    }

    func testAirbrushExportHasSoftEdgeLikeMetalCanvas() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Airbrush",
            projectID: nil,
            format: .custom,
            customWidth: 64,
            customHeight: 64,
            background: .transparent
        )
        let layer = try XCTUnwrap(artwork.layers.first)
        library.saveMetalStrokes([
            MetalPaintStroke(
                points: [StrokePoint(x: 32, y: 32, pressure: 1)],
                color: .red,
                width: 24,
                opacity: 1,
                tool: .brush,
                brushPreset: "airbrush"
            )
        ], for: layer, artworkID: artwork.id)

        let export = ArtworkRenderer.render(document: artwork, library: library)
        let center = try XCTUnwrap(RasterTools.sampleColor(in: export, at: CGPoint(x: 32, y: 32)))
        let edge = try XCTUnwrap(RasterTools.sampleColor(in: export, at: CGPoint(x: 40, y: 32)))
        XCTAssertGreaterThan(center.alpha, edge.alpha)
        XCTAssertGreaterThan(edge.alpha, 0)
    }

    func testRapidSavesLeaveValidLatestDocument() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        var artwork = library.createArtwork(name: "Schnell", projectID: nil, format: .square)
        for index in 0..<100 {
            artwork.name = "Stand \(index)"
            library.saveDocument(artwork)
        }
        await library.waitForWrites()

        let reloaded = ArtworkLibrary(rootURL: root)
        XCTAssertEqual(reloaded.document(artwork.id)?.name, "Stand 99")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LoveaTests-\(UUID().uuidString)", isDirectory: true)
    }
}
