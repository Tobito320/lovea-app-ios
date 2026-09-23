import Foundation

/// Chunked media upload/download against `PUT /medien/<id>/<rolle>/<teil>`,
/// `POST /medien/<id>/<rolle>/fertig` and `GET /medien/<id>`.
///
/// ponytail: the exact shape of `GET .../fehlend` isn't settled yet (Block 1 hadn't written the
/// server route when this was built) — decoded tolerantly, see `fehlendeTeile`. Reconcile once
/// Block 1's `server/raum.js` lands; if the field names differ this needs a one-line fix, not
/// a redesign.
enum Medien {
    static let teilGroesse = 1_048_576 // 1 MiB

    enum MedienFehler: Error { case nichtEingerichtet, datei, anfrage }

    static func lokal(_ id: String) -> URL? {
        let url = cacheURL(for: id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func hochladen(id: String, original: URL, klein: URL? = nil) async throws {
        guard let konfig = await Raum.shared.httpKonfiguration() else { throw MedienFehler.nichtEingerichtet }
        try await teilHochladen(id: id, rolle: "original", datei: original, konfig: konfig)
        if let klein { try await teilHochladen(id: id, rolle: "klein", datei: klein, konfig: konfig) }
        // So the sender sees their own media right away instead of downloading it back.
        try? FileManager.default.createDirectory(at: cacheURL(for: id).deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: cacheURL(for: id))
        try? FileManager.default.copyItem(at: original, to: cacheURL(for: id))
    }

    static func holen(_ id: String) async throws -> URL {
        if let cached = lokal(id) { return cached }
        guard let konfig = await Raum.shared.httpKonfiguration() else { throw MedienFehler.nichtEingerichtet }
        var request = URLRequest(url: konfig.basis.appendingPathComponent("medien/\(id)"))
        headers(konfig, in: &request)
        let (temp, response) = try await URLSession.shared.download(for: request)
        try pruefeErfolg(response)
        let ziel = cacheURL(for: id)
        try FileManager.default.createDirectory(at: ziel.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: ziel)
        try FileManager.default.moveItem(at: temp, to: ziel)
        return ziel
    }

    /// Pure: which part indices to (re)send. Clamps and dedupes whatever the server reports
    /// missing against the locally known part count.
    static func fehlendePlan(gesamt: Int, fehlend: [Int]) -> [Int] {
        Set(fehlend.filter { $0 >= 0 && $0 < gesamt }).sorted()
    }

    // MARK: - Upload

    private static func teilHochladen(id: String, rolle: String, datei: URL, konfig: Raum.HttpKonfiguration) async throws {
        let attribute = try? FileManager.default.attributesOfItem(atPath: datei.path)
        guard let groesse = attribute?[.size] as? Int, groesse > 0 else {
            throw MedienFehler.datei
        }
        let gesamt = Int((Double(groesse) / Double(teilGroesse)).rounded(.up))
        let fehlend = await fehlendeTeile(id: id, rolle: rolle, gesamt: gesamt, konfig: konfig)
        guard let handle = FileHandle(forReadingAtPath: datei.path) else { throw MedienFehler.datei }
        defer { try? handle.close() }
        for teil in fehlend {
            try handle.seek(toOffset: UInt64(teil * teilGroesse))
            let stueck = (try handle.read(upToCount: teilGroesse)) ?? Data()
            var request = URLRequest(url: konfig.basis.appendingPathComponent("medien/\(id)/\(rolle)/\(teil)"))
            request.httpMethod = "PUT"
            headers(konfig, in: &request)
            let (_, response) = try await URLSession.shared.upload(for: request, from: stueck)
            try pruefeErfolg(response)
        }
        var fertig = URLRequest(url: konfig.basis.appendingPathComponent("medien/\(id)/\(rolle)/fertig"))
        fertig.httpMethod = "POST"
        fertig.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers(konfig, in: &fertig)
        fertig.httpBody = try JSONEncoder().encode(FertigBody(teile: gesamt, typ: dateiTyp(datei), bytes: groesse))
        let (_, response) = try await URLSession.shared.data(for: fertig)
        try pruefeErfolg(response)
    }

    private static func fehlendeTeile(id: String, rolle: String, gesamt: Int, konfig: Raum.HttpKonfiguration) async -> [Int] {
        let alle = Array(0..<max(gesamt, 1))
        let basisURL = konfig.basis.appendingPathComponent("medien/\(id)/fehlend")
        guard var comps = URLComponents(url: basisURL, resolvingAgainstBaseURL: false) else { return alle }
        comps.queryItems = [URLQueryItem(name: "rolle", value: rolle)]
        guard let url = comps.url else { return alle }
        var request = URLRequest(url: url)
        headers(konfig, in: &request)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let antwort = try? JSONDecoder().decode(FehlendAntwort.self, from: data) else { return alle }
        if let fehlend = antwort.fehlend { return fehlendePlan(gesamt: gesamt, fehlend: fehlend) }
        if let vorhanden = antwort.vorhanden { return fehlendePlan(gesamt: gesamt, fehlend: alle.filter { !vorhanden.contains($0) }) }
        return alle
    }

    // MARK: - Helpers

    private static func headers(_ konfig: Raum.HttpKonfiguration, in request: inout URLRequest) {
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
    }

    private static func cacheURL(for id: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/medien/\(id)", isDirectory: false)
    }

    private static func pruefeErfolg(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw MedienFehler.anfrage }
    }

    private static func dateiTyp(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mov", "mp4": "video/mp4"
        case "m4a", "caf", "wav": "audio/m4a"
        default: "image/jpeg"
        }
    }
}

private struct FertigBody: Encodable { let teile: Int; let typ: String; let bytes: Int }
private struct FehlendAntwort: Decodable { let teile: Int?; let fehlend: [Int]?; let vorhanden: [Int]? }
