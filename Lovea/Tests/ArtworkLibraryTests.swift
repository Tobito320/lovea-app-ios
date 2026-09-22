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

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LoveaTests-\(UUID().uuidString)", isDirectory: true)
    }
}
