import XCTest
@testable import Lovea

@MainActor
final class GalleryLibraryTests: XCTestCase {
    func testNewArtworkDefaultsAndLimits() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = ArtworkLibrary(rootURL: root)
        let square = library.createArtwork(name: "", projectID: nil, format: .square)
        XCTAssertEqual(square.canvasWidth, 2048)
        XCTAssertEqual(square.canvasHeight, 2048)

        let custom = library.createArtwork(
            name: "Groß",
            projectID: nil,
            format: .custom,
            customWidth: 9_000,
            customHeight: 10
        )
        XCTAssertEqual(custom.canvasWidth, 4096)
        XCTAssertEqual(custom.canvasHeight, 64)

        let rose = RGBAColor(red: 1, green: 0.84, blue: 0.88)
        let colored = library.createArtwork(name: "Rosa", projectID: nil, format: .a4, background: .color(rose))
        await library.waitForWrites()

        let reloaded = ArtworkLibrary(rootURL: root)
        XCTAssertEqual(reloaded.document(colored.id)?.background, .color(rose))
    }

    func testProjectRenameAndMoveOut() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = ArtworkLibrary(rootURL: root)
        let project = library.createProject(name: "Alt")
        let artwork = library.createArtwork(name: "Bild", projectID: project.id, format: .square)

        library.renameProject(project.id, to: "  Neu  ")
        library.moveArtwork(artwork.id, to: nil)
        await library.waitForWrites()

        let reloaded = ArtworkLibrary(rootURL: root)
        XCTAssertEqual(reloaded.projects.map(\.name), ["Neu"])
        XCTAssertNil(reloaded.document(artwork.id)?.projectID)
    }

    func testDeleteProjectKeepsOrDeletesArtworks() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = ArtworkLibrary(rootURL: root)
        let keep = library.createProject(name: "Behalten")
        let drop = library.createProject(name: "Weg")
        let kept = library.createArtwork(name: "A", projectID: keep.id, format: .square)
        let dropped = library.createArtwork(name: "B", projectID: drop.id, format: .square)

        library.deleteProject(keep.id, deleteArtworks: false)
        library.deleteProject(drop.id, deleteArtworks: true)
        await library.waitForWrites()

        let reloaded = ArtworkLibrary(rootURL: root)
        XCTAssertTrue(reloaded.projects.isEmpty)
        XCTAssertEqual(reloaded.artworks.map(\.id), [kept.id])
        XCTAssertNil(reloaded.document(kept.id)?.projectID)
        XCTAssertNil(reloaded.document(dropped.id))
    }

    func testExportFileIsNamedAfterDrawing() throws {
        let data = Data([1, 2, 3])
        let png = try ArtworkExport.file(named: "Katze/Hund", data: data, format: .png)
        let jpeg = try ArtworkExport.file(named: "Katze/Hund", data: data, format: .jpeg)

        XCTAssertEqual(png.lastPathComponent, "Katze-Hund.png")
        XCTAssertEqual(jpeg.lastPathComponent, "Katze-Hund.jpg")
        XCTAssertEqual(try Data(contentsOf: png), data)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
}
