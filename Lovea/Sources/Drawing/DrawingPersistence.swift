import Foundation

actor DrawingPersistence {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = directory.appendingPathComponent("lovea-drawing.json")
        }
    }

    func load() throws -> DrawingDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(DrawingDocument.self, from: Data(contentsOf: fileURL))
    }

    func save(_ document: DrawingDocument) throws {
        let data = try JSONEncoder().encode(document)
        try data.write(to: fileURL, options: .atomic)
    }
}
