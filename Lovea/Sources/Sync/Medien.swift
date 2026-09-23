import Foundation

/// Chunked media upload/download against `PUT /medien/<id>/<rolle>/<teil>`,
/// `POST /medien/<id>/<rolle>/fertig` and `GET /medien/<id>`.
enum Medien {
    static let teilGroesse = 1_048_576 // 1 MiB

    enum MedienFehler: Error { case nichtEingerichtet, datei, anfrage }

    static func lokal(_ id: String) -> URL? {
        let url = cacheURL(for: id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func hochladen(id: String, original: URL, klein: URL? = nil) async throws {
        guard await aktiveUploads.beanspruchen(id) else { return } // already uploading (e.g. fortsetzen())
        do {
            guard let konfig = await Raum.shared.httpKonfiguration() else { throw MedienFehler.nichtEingerichtet }
            // Copy into our own cache BEFORE uploading, not after: `original`/`klein` are often an
            // ephemeral picker temp file that can be gone by the time a retry (after a dropped
            // connection, or the app being killed mid-upload) reads it again.
            let originalKopie = try lokaleKopie(von: original, id: id, rolle: "original")
            let kleinKopie = try klein.map { try lokaleKopie(von: $0, id: id, rolle: "klein") }
            try await teilHochladen(id: id, rolle: "original", datei: originalKopie, konfig: konfig)
            if let kleinKopie { try await teilHochladen(id: id, rolle: "klein", datei: kleinKopie, konfig: konfig) }
            // Sender sees their own media right away instead of downloading it back.
            try? FileManager.default.removeItem(at: cacheURL(for: id))
            try? FileManager.default.copyItem(at: originalKopie, to: cacheURL(for: id))
            // Upload finished — the resumable copy is no longer needed, and must go so
            // `fortsetzen()` doesn't retry an already-finished upload forever (I-4/M-7).
            try? FileManager.default.removeItem(at: originalKopie)
            if let kleinKopie { try? FileManager.default.removeItem(at: kleinKopie) }
            await aktiveUploads.freigeben(id)
        } catch {
            await aktiveUploads.freigeben(id)
            throw error
        }
    }

    /// Scans `Lovea/medien/hochladen/` for uploads that never finished (app killed mid-upload,
    /// or offline) and retries them from the cached copy. Call once from `Raum.start()` — not
    /// awaited there, this runs in the background. `hochladen`'s own `aktiveUploads` claim keeps
    /// this from racing a fresh, still-in-flight `hochladen` call for the same id (I-4).
    static func fortsetzen() {
        Task {
            let ordner = hochladenOrdner()
            guard let dateien = try? FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil) else { return }
            for original in dateien where original.lastPathComponent.hasSuffix("-original") {
                let id = String(original.lastPathComponent.dropLast("-original".count))
                let kleinURL = ordner.appendingPathComponent("\(id)-klein")
                let klein = FileManager.default.fileExists(atPath: kleinURL.path) ? kleinURL : nil
                try? await hochladen(id: id, original: original, klein: klein)
            }
        }
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

    /// Pure: which part indices still need uploading, given the server's `/fehlend` response.
    /// `vorhanden` (existing parts) is always reliable per the server — including `[]` for a
    /// brand-new id — so it's preferred; `fehlend` alone (no `vorhanden`) is only a best-effort
    /// fallback for gaps below the highest uploaded part, and an empty `fehlend` does NOT mean
    /// "nothing missing" for a fresh upload (C-1).
    static func plan(gesamt: Int, antwort: FehlendAntwort) -> [Int] {
        let alle = Array(0..<max(gesamt, 1))
        if let vorhanden = antwort.vorhanden {
            let vorhandenSet = Set(vorhanden)
            return alle.filter { !vorhandenSet.contains($0) }
        }
        if let fehlend = antwort.fehlend {
            return fehlendePlan(gesamt: gesamt, fehlend: fehlend)
        }
        return alle
    }

    /// Pure: clamps and dedupes a `fehlend` list against the locally known part count. Used by
    /// `plan` for the (rare) case the server response has no `vorhanden` at all.
    static func fehlendePlan(gesamt: Int, fehlend: [Int]) -> [Int] {
        Set(fehlend.filter { $0 >= 0 && $0 < gesamt }).sorted()
    }

    // MARK: - Upload

    /// Tracks ids currently uploading, so `fortsetzen()` (a background rescan) never starts a
    /// second, concurrent upload of an id a fresh `hochladen` call is already handling — both
    /// would read/write the same cached copy.
    private actor AktiveUploads {
        private var ids: Set<String> = []
        func beanspruchen(_ id: String) -> Bool {
            guard !ids.contains(id) else { return false }
            ids.insert(id)
            return true
        }
        func freigeben(_ id: String) { ids.remove(id) }
    }
    private static let aktiveUploads = AktiveUploads()

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
        comps.queryItems = [URLQueryItem(name: "rolle", value: rolle), URLQueryItem(name: "teile", value: String(gesamt))]
        guard let url = comps.url else { return alle }
        var request = URLRequest(url: url)
        headers(konfig, in: &request)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let antwort = try? JSONDecoder().decode(FehlendAntwort.self, from: data) else { return alle }
        return plan(gesamt: gesamt, antwort: antwort)
    }

    // MARK: - Helpers

    private static func headers(_ konfig: Raum.HttpKonfiguration, in request: inout URLRequest) {
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
    }

    private static func cacheURL(for id: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/medien/\(id)", isDirectory: false)
    }

    private static func hochladenOrdner() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/medien/hochladen", isDirectory: true)
    }

    /// Copies a to-be-uploaded file into a stable location keyed by `id`/`rolle`, so re-running
    /// `hochladen` for the same `id` (e.g. after a crash) resumes from here even if the original
    /// picker/recording temp file is already gone (I-2).
    private static func lokaleKopie(von quelle: URL, id: String, rolle: String) throws -> URL {
        let ziel = hochladenOrdner().appendingPathComponent("\(id)-\(rolle)", isDirectory: false)
        try FileManager.default.createDirectory(at: ziel.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: ziel.path) {
            // Already have a stable copy (e.g. resuming after a crash) — keep it. Deleting it
            // first and then trying to copy from `quelle` (often long gone by now) would lose
            // both, which is exactly the bug this guards against.
            return ziel
        }
        guard quelle != ziel, FileManager.default.fileExists(atPath: quelle.path) else { throw MedienFehler.datei }
        // Copy to a temp file first, then move: a crash mid-copy leaves a truncated `.tmp`, never
        // a truncated `ziel` that a later run would mistake for a complete, resumable copy.
        let temp = ziel.appendingPathExtension("tmp")
        try? FileManager.default.removeItem(at: temp)
        try FileManager.default.copyItem(at: quelle, to: temp)
        try FileManager.default.moveItem(at: temp, to: ziel)
        return ziel
    }

    private static func pruefeErfolg(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw MedienFehler.anfrage }
    }

    private static func dateiTyp(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mov", "mp4": "video/mp4"
        case "m4a", "caf", "wav": "audio/m4a"
        case "png": "image/png"
        default: "image/jpeg"
        }
    }
}

private struct FertigBody: Encodable { let teile: Int; let typ: String; let bytes: Int }
struct FehlendAntwort: Decodable { let teile: Int?; let fehlend: [Int]?; let vorhanden: [Int]? }
