import XCTest
@testable import Lovea

@MainActor
final class ArtworkLibraryTests: XCTestCase {
    func testProjectsAndArtworksSurviveReload() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let project = library.createProject(name: "Skizzen")
        let artwork = library.createArtwork(name: "Katze", projectID: project.id, format: .portrait3x4, background: .white)
        await library.waitForWrites()

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
        let artwork = library.createArtwork(name: "Bild", projectID: nil, format: .square, background: .transparent)

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

    func testCustomCanvasIsClampedToSafeRange() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(
            name: "Groß", projectID: nil, format: .custom, customWidth: 9_000, customHeight: 1, background: .dark
        )
        XCTAssertEqual(artwork.canvasWidth, 4_096)
        XCTAssertEqual(artwork.canvasHeight, 64)
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

    /// Z-2.11: paint layers are PNG files, schema 3.
    func testNewArtworkUsesPNGLayersAndSchema3() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ArtworkLibrary(rootURL: root)
        let artwork = library.createArtwork(name: "Neu", projectID: nil, format: .square)
        let layer = try XCTUnwrap(artwork.layers.first)
        XCTAssertEqual(artwork.schemaVersion, 3)
        XCTAssertEqual(layer.contentFile, "\(layer.id.uuidString).png")

        await library.waitForWrites()
        XCTAssertEqual(ArtworkLibrary(rootURL: root).document(artwork.id)?.schemaVersion, 3)
    }

    /// Z-4.6: a failed write leaves the old file readable and unchanged.
    func testFailedAtomicWriteKeepsOldFile() throws {
        let root = temporaryRoot()
        let folder = root.appendingPathComponent("locked", isDirectory: true)
        let file = folder.appendingPathComponent("document.json")
        try ArtworkLibrary.atomicWrite(Data("alt".utf8), to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
            try? FileManager.default.removeItem(at: root)
        }

        XCTAssertThrowsError(try ArtworkLibrary.atomicWrite(Data("neu".utf8), to: file))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "alt")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LoveaTests-\(UUID().uuidString)", isDirectory: true)
    }
}
