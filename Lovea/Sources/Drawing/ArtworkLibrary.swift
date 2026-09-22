import Combine
import Foundation
import UIKit

@MainActor
final class ArtworkLibrary: ObservableObject {
    @Published private(set) var projects: [ArtworkProject] = []
    @Published private(set) var artworks: [ArtworkDocument] = []

    private let fileManager: FileManager
    private let rootURL: URL
    private let indexURL: URL
    private let artworksURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = rootURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea", isDirectory: true)
        self.rootURL = base
        self.indexURL = base.appendingPathComponent("library.json")
        self.artworksURL = base.appendingPathComponent("Artworks", isDirectory: true)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        prepareDirectories()
        load()
    }

    func load() {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let index = try? decoder.decode(ArtworkLibraryIndex.self, from: data) else {
            projects = []
            artworks = discoverArtworkDocuments()
            persistIndex()
            return
        }
        projects = index.projects
        artworks = index.artworkIDs.compactMap(loadDocument)
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
        let width = clampDimension(customWidth ?? proposed.width)
        let height = clampDimension(customHeight ?? proposed.height)
        var document = ArtworkDocument.new(
            name: cleaned(name, fallback: "Neue Zeichnung"),
            projectID: projectID,
            format: format,
            width: width,
            height: height,
            background: background
        )
        document.updatedAt = Date()
        prepareArtworkDirectory(document.id)
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
        guard var original = document(id) else { return nil }
        let oldDirectory = directory(for: original.id)
        let oldID = original.id
        original.id = UUID()
        original.name = "\(original.name) Kopie"
        original.createdAt = Date()
        original.updatedAt = Date()
        original.liveReadOnlyShare = false
        let newDirectory = directory(for: original.id)
        do {
            if fileManager.fileExists(atPath: newDirectory.path) {
                try fileManager.removeItem(at: newDirectory)
            }
            if fileManager.fileExists(atPath: oldDirectory.path) {
                try fileManager.copyItem(at: oldDirectory, to: newDirectory)
            } else {
                prepareArtworkDirectory(original.id)
            }
            try? fileManager.removeItem(at: newDirectory.appendingPathComponent("document.json"))
            artworks.append(original)
            persistDocument(original)
            persistIndex()
            return original
        } catch {
            original.id = oldID
            return nil
        }
    }

    func deleteArtwork(_ id: UUID) {
        artworks.removeAll { $0.id == id }
        try? fileManager.removeItem(at: directory(for: id))
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
        let folder = layersDirectory(for: artworkID)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent(fileName), options: .atomic)
    }

    func layerAsset(fileName: String, artworkID: UUID) -> Data? {
        try? Data(contentsOf: layersDirectory(for: artworkID).appendingPathComponent(fileName))
    }

    func removeLayerAsset(fileName: String, artworkID: UUID) {
        try? fileManager.removeItem(at: layersDirectory(for: artworkID).appendingPathComponent(fileName))
    }

    func savePreview(_ image: UIImage, artworkID: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.78) else { return }
        try? data.write(to: directory(for: artworkID).appendingPathComponent("preview.jpg"), options: .atomic)
        objectWillChange.send()
    }

    func previewImage(for artworkID: UUID) -> UIImage? {
        UIImage(contentsOfFile: directory(for: artworkID).appendingPathComponent("preview.jpg").path)
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

    private func prepareDirectories() {
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: artworksURL, withIntermediateDirectories: true)
    }

    private func prepareArtworkDirectory(_ id: UUID) {
        try? fileManager.createDirectory(at: directory(for: id), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: layersDirectory(for: id), withIntermediateDirectories: true)
    }

    private func directory(for id: UUID) -> URL {
        artworksURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func layersDirectory(for id: UUID) -> URL {
        directory(for: id).appendingPathComponent("layers", isDirectory: true)
    }

    private func loadDocument(_ id: UUID) -> ArtworkDocument? {
        let url = directory(for: id).appendingPathComponent("document.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ArtworkDocument.self, from: data)
    }

    private func discoverArtworkDocuments() -> [ArtworkDocument] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: artworksURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return loadDocument(id)
        }
    }

    private func persistDocument(_ document: ArtworkDocument) {
        prepareArtworkDirectory(document.id)
        guard let data = try? encoder.encode(document) else { return }
        try? data.write(to: directory(for: document.id).appendingPathComponent("document.json"), options: .atomic)
    }

    private func persistIndex() {
        let index = ArtworkLibraryIndex(projects: projects, artworkIDs: artworks.map(\.id))
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func clampDimension(_ value: Double) -> Double {
        min(max(value, 64), 4096)
    }

    private func cleaned(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(60))
    }
}
