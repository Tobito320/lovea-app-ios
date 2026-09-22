import Photos
import SwiftUI
import UIKit

enum ArtworkExportFormat: String, CaseIterable, Identifiable {
    case png
    case jpeg

    var id: String { rawValue }

    var title: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        }
    }
}

enum ArtworkExport {
    nonisolated static func encode(_ image: UIImage, format: ArtworkExportFormat) -> Data? {
        switch format {
        case .png:
            return image.pngData()
        case .jpeg:
            // JPEG has no alpha; without this transparent areas turn black.
            let rendererFormat = UIGraphicsImageRendererFormat()
            rendererFormat.scale = image.scale
            rendererFormat.opaque = true
            return UIGraphicsImageRenderer(size: image.size, format: rendererFormat).jpegData(withCompressionQuality: 0.9) { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: image.size))
                image.draw(at: .zero)
            }
        }
    }

    nonisolated static func file(named name: String, data: Data, format: ArtworkExportFormat) throws -> URL {
        let clean = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A fresh folder per export keeps the file name exactly "<name>.<ext>".
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder
            .appendingPathComponent(clean.isEmpty ? "Zeichnung" : clean)
            .appendingPathExtension(format == .png ? "png" : "jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func saveToPhotos(_ data: Data) async throws {
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }
}

struct ArtworkExportSheet: View {
    let artwork: ArtworkDocument
    @ObservedObject var library: ArtworkLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var format: ArtworkExportFormat = .png
    @State private var image: UIImage?
    @State private var data: Data?
    @State private var fileURL: URL?
    @State private var failed = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Format", selection: $format) {
                    ForEach(ArtworkExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                if let data, let fileURL {
                    ShareLink(item: fileURL) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        save(data)
                    } label: {
                        Label("In Fotos sichern", systemImage: "photo.badge.arrow.down")
                    }
                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if failed {
                    Text("Export fehlgeschlagen.")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView("Bild wird erstellt …")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Exportieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task(id: format) {
                data = nil
                fileURL = nil
                status = nil
                failed = false
                if image == nil {
                    image = await CanvasEngine.renderImage(document: artwork, library: library)
                }
                guard let image else {
                    failed = true
                    return
                }
                let format = self.format
                let name = artwork.name
                let result = await Task.detached(priority: .userInitiated) { () -> (Data, URL)? in
                    guard let data = ArtworkExport.encode(image, format: format),
                          let url = try? ArtworkExport.file(named: name, data: data, format: format) else {
                        return nil
                    }
                    return (data, url)
                }.value
                guard !Task.isCancelled else { return }
                if let result {
                    data = result.0
                    fileURL = result.1
                } else {
                    failed = true
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save(_ data: Data) {
        status = "Wird gesichert …"
        Task {
            do {
                try await ArtworkExport.saveToPhotos(data)
                status = "In Fotos gesichert."
            } catch {
                status = "Sichern fehlgeschlagen. Erlaube Lovea den Zugriff auf Fotos in den Einstellungen."
            }
        }
    }
}
