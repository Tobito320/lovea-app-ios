import Combine
import Foundation
import UIKit

@MainActor
final class ArtworkLibrary: ObservableObject {
    @Published private(set) var projects: [ArtworkProject] = []
    @Published private(set) var artworks: [ArtworkDocument] = []
    @Published private(set) var previewVersion = 0

    /// All disk writes run here, in order. Reads that must see earlier writes use `io.sync`.
    /// ponytail: one queue for every library instance, so a reload always sees pending writes.
    nonisolated static let io = DispatchQueue(label: "lovea.library.io", qos: .utility)

    private let rootURL: URL
    private let indexURL: URL
    private let artworksURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootURL: URL? = nil) {
        let base = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea", isDirectory: true)
        self.rootURL = base
        self.indexURL = base.appendingPathComponent("library.json")
        self.artworksURL = base.appendingPathComponent("Artworks", isDirectory: true)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        let artworksURL = artworksURL
        Self.io.sync {
            try? FileManager.default.createDirectory(at: artworksURL, withIntermediateDirectories: true)
        }
        load()
    }

    func load() {
        let indexURL = indexURL
        let data = Self.io.sync { try? Data(contentsOf: indexURL) }
        guard let data, let index = try? decoder.decode(ArtworkLibraryIndex.self, from: data) else {
            projects = []
            artworks = discoverArtworkDocuments()
            persistIndex()
            return
        }
        projects = index.projects
        artworks = index.artworkIDs.compactMap(loadDocument)
    }

    /// Resolves once every write queued so far is on disk.
    func waitForWrites() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Self.io.async { continuation.resume() }
        }
    }

    @discardableResult
    func createProject(name: String) -> ArtworkProject {
        let clean = cleaned(name, fallback: "Neues Projekt")
        let project = ArtworkProject(name: clean)
        projects.append(project)
        persistIndex()
        return project
    }

    func renameProject(_ id: UUID, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = cleaned(name, fallback: projects[index].name)
        projects[index].updatedAt = Date()
        persistIndex()
    }

    func deleteProject(_ id: UUID, deleteArtworks: Bool = false) {
        if deleteArtworks {
            for artwork in artworks where artwork.projectID == id {
                deleteArtwork(artwork.id)
            }
        } else {
            let ids = artworks.indices.filter { artworks[$0].projectID == id }
            for index in ids {
                artworks[index].projectID = nil
                artworks[index].updatedAt = Date()
                persistDocument(artworks[index])
            }
        }
        projects.removeAll { $0.id == id }
        persistIndex()
    }

    @discardableResult
    func createArtwork(
        name: String,
        projectID: UUID?,
        format: ArtworkFormat,
        customWidth: Double? = nil,
        customHeight: Double? = nil,
        background: CanvasBackground = .white
    ) -> ArtworkDocument {
        let proposed = format.size()
        let width = Self.clampDimension(customWidth ?? proposed.width)
        let height = Self.clampDimension(customHeight ?? proposed.height)
        var document = ArtworkDocument.new(
            name: cleaned(name, fallback: "Neue Zeichnung"),
            projectID: projectID,
            format: format,
            width: width,
            height: height,
            background: background
        )
        document.updatedAt = Date()
        artworks.append(document)
        persistDocument(document)
        persistIndex()
        return document
    }

    func document(_ id: UUID) -> ArtworkDocument? {
        artworks.first(where: { $0.id == id })
    }

    func saveDocument(_ document: ArtworkDocument) {
        var next = document
        next.updatedAt = Date()
        if let index = artworks.firstIndex(where: { $0.id == next.id }) {
            artworks[index] = next
        } else {
            artworks.append(next)
        }
        persistDocument(next)
        persistIndex()
    }

    func renameArtwork(_ id: UUID, to name: String) {
        guard var artwork = document(id) else { return }
        artwork.name = cleaned(name, fallback: artwork.name)
        saveDocument(artwork)
    }

    func moveArtwork(_ id: UUID, to projectID: UUID?) {
        guard var artwork = document(id) else { return }
        artwork.projectID = projectID
        saveDocument(artwork)
    }

    @discardableResult
    func duplicateArtwork(_ id: UUID) -> ArtworkDocument? {
        guard var copy = document(id) else { return nil }
        let oldDirectory = directory(for: copy.id)
        copy.id = UUID()
        copy.name = "\(copy.name) Kopie"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.liveReadOnlyShare = false
        let newDirectory = directory(for: copy.id)
        let copied: Bool = Self.io.sync {
            let files = FileManager.default
            try? files.removeItem(at: newDirectory)
            guard files.fileExists(atPath: oldDirectory.path) else { return true }
            guard (try? files.copyItem(at: oldDirectory, to: newDirectory)) != nil else { return false }
            try? files.removeItem(at: newDirectory.appendingPathComponent("document.json"))
            return true
        }
        guard copied else { return nil }
        artworks.append(copy)
        persistDocument(copy)
        persistIndex()
        return copy
    }

    func deleteArtwork(_ id: UUID) {
        artworks.removeAll { $0.id == id }
        let url = directory(for: id)
        Self.io.async { try? FileManager.default.removeItem(at: url) }
        persistIndex()
    }

    func saveLayerData(_ data: Data, layer: ArtworkLayer, artworkID: UUID) {
        saveLayerAsset(data, fileName: layer.contentFile, artworkID: artworkID)
    }

    func layerData(_ layer: ArtworkLayer, artworkID: UUID) -> Data? {
        layerAsset(fileName: layer.contentFile, artworkID: artworkID)
    }

    func metalStrokes(for layer: ArtworkLayer, artworkID: UUID) -> [MetalPaintStroke] {
        guard layer.kind == .paint,
              let data = layerAsset(fileName: metalStrokesFile(for: layer), artworkID: artworkID),
              let strokes = try? decoder.decode([MetalPaintStroke].self, from: data) else {
            return []
        }
        return strokes
    }

    func saveMetalStrokes(_ strokes: [MetalPaintStroke], for layer: ArtworkLayer, artworkID: UUID) {
        guard layer.kind == .paint, let data = try? encoder.encode(strokes) else { return }
        saveLayerAsset(data, fileName: metalStrokesFile(for: layer), artworkID: artworkID)
    }

    func metalStrokesFile(for layer: ArtworkLayer) -> String {
        "metal-\(layer.id.uuidString).json"
    }

    func saveLayerAsset(_ data: Data, fileName: String, artworkID: UUID) {
        let url = layersDirectory(for: artworkID).appendingPathComponent(fileName)
        Self.io.async { try? Self.atomicWrite(data, to: url) }
    }

    func layerAsset(fileName: String, artworkID: UUID) -> Data? {
        let url = layersDirectory(for: artworkID).appendingPathComponent(fileName)
        return Self.io.sync { try? Data(contentsOf: url) }
    }

    func layerAssetURL(fileName: String, artworkID: UUID) -> URL {
        layersDirectory(for: artworkID).appendingPathComponent(fileName)
    }

    func removeLayerAsset(fileName: String, artworkID: UUID) {
        let url = layersDirectory(for: artworkID).appendingPathComponent(fileName)
        Self.io.async { try? FileManager.default.removeItem(at: url) }
    }

    func renameLayerAsset(fileName: String, to newName: String, artworkID: UUID) {
        let folder = layersDirectory(for: artworkID)
        Self.io.async {
            try? FileManager.default.moveItem(
                at: folder.appendingPathComponent(fileName),
                to: folder.appendingPathComponent(newName)
            )
        }
    }

    func savePreview(jpeg data: Data, artworkID: UUID) {
        let url = directory(for: artworkID).appendingPathComponent("preview.jpg")
        Self.io.async {
            try? Self.atomicWrite(data, to: url)
            Task { @MainActor [weak self] in self?.previewVersion += 1 }
        }
    }

    func previewURL(for artworkID: UUID) -> URL {
        directory(for: artworkID).appendingPathComponent("preview.jpg")
    }

    func previewImage(for artworkID: UUID) -> UIImage? {
        UIImage(contentsOfFile: previewURL(for: artworkID).path)
    }

    func sortedArtworks(_ sort: ArtworkSort) -> [ArtworkDocument] {
        switch sort {
        case .newest:
            return artworks.sorted { $0.updatedAt > $1.updatedAt }
        case .name:
            return artworks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .oldest:
            return artworks.sorted { $0.createdAt < $1.createdAt }
        }
    }

    func setProjectShared(_ id: UUID, shared: Bool) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].sharedReadOnly = shared
        projects[index].updatedAt = Date()
        persistIndex()
    }

    /// Writes via a temporary file and rename. A failed write leaves the old file untouched.
    nonisolated static func atomicWrite(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    nonisolated static func clampDimension(_ value: Double) -> Double {
        min(max(value.rounded(), 64), 4096)
    }

    private func directory(for id: UUID) -> URL {
        artworksURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func layersDirectory(for id: UUID) -> URL {
        directory(for: id).appendingPathComponent("layers", isDirectory: true)
    }

    private func loadDocument(_ id: UUID) -> ArtworkDocument? {
        let url = directory(for: id).appendingPathComponent("document.json")
        guard let data = Self.io.sync(execute: { try? Data(contentsOf: url) }) else { return nil }
        return try? decoder.decode(ArtworkDocument.self, from: data)
    }

    private func discoverArtworkDocuments() -> [ArtworkDocument] {
        let artworksURL = artworksURL
        let urls = Self.io.sync {
            (try? FileManager.default.contentsOfDirectory(
                at: artworksURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
        }
        return urls.compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return loadDocument(id)
        }
    }

    private func persistDocument(_ document: ArtworkDocument) {
        guard let data = try? encoder.encode(document) else { return }
        let url = directory(for: document.id).appendingPathComponent("document.json")
        Self.io.async { try? Self.atomicWrite(data, to: url) }
    }

    private func persistIndex() {
        let index = ArtworkLibraryIndex(projects: projects, artworkIDs: artworks.map(\.id))
        guard let data = try? encoder.encode(index) else { return }
        let url = indexURL
        Self.io.async { try? Self.atomicWrite(data, to: url) }
    }

    private func cleaned(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(60))
    }
}
