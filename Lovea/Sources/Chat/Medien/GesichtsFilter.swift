import UIKit
import Vision

/// "Mit Gesichtern"-Filter (Z-5.4): `VNDetectFaceRectanglesRequest` runs once per photo in the
/// background, the yes/no result is cached forever (a photo's content never changes).
@MainActor
enum GesichtsFilter {
    private static let cacheURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Lovea/gesichter-cache.json")
    private static var cache: [String: Bool] = ladeCache()

    static func hatGesichter(_ id: String) -> Bool? { cache[id] }

    static func pruefen(id: String, dateiURL: URL) async {
        guard cache[id] == nil else { return }
        let gefunden = await Task.detached(priority: .utility) { () -> Bool in
            guard let uiImage = UIImage(contentsOfFile: dateiURL.path), let cgImage = uiImage.cgImage else { return false }
            let handler = VNImageRequestHandler(cgImage: cgImage)
            let request = VNDetectFaceRectanglesRequest()
            try? handler.perform([request])
            return !(request.results?.isEmpty ?? true)
        }.value
        cache[id] = gefunden
        speichern()
    }

    private static func ladeCache() -> [String: Bool] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    /// `cache` in memory is the truth; the file only gets ordered snapshots, off the main thread (Z-16.2).
    private static func speichern() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        KleineDatei.schreiben(data, nach: cacheURL)
    }
}
