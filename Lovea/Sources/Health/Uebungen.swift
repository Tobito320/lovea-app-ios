import Foundation

/// One exercise of the bundled ExerciseDB set (`uebungen.json` next to this file, built by
/// `tools/uebungen-katalog.sh`). `id` is the ExerciseDB id: plans, `gym.uebung` ops and later the
/// figure use it.
struct Uebung: Codable, Identifiable, Sendable, Equatable {
    let id: String
    /// German name.
    let name: String
    /// ExerciseDB's English name, searchable too.
    let en: String
    /// Target muscle, German.
    let muskel: String
    /// Body part, German ("Brust", "Beine", "Cardio" …); the search filter.
    let koerper: String
    /// Equipment, German.
    let geraet: String
    /// Secondary muscles, German.
    let neben: [String]

    var istCardio: Bool { koerper == "Cardio" }
}

/// The catalog: 1,324 exercises, each with a 180p GIF at ExerciseDB (`UebungsMedien`), searchable
/// in German and English.
enum UebungsKatalog {
    static let alle: [Uebung] = laden(.main)
    static let nachId: [String: Uebung] = Dictionary(alle.map { ($0.id, $0) }, uniquingKeysWith: { erste, _ in erste })
    static let koerperteile: [String] = Array(Set(alle.map(\.koerper))).sorted()
    /// Normalized search text per id, computed once.
    private static let suchtexte: [String: String] = Dictionary(alle.map { ($0.id, suchtext($0)) }, uniquingKeysWith: { erste, _ in erste })

    static func laden(_ bundle: Bundle) -> [Uebung] {
        guard let url = bundle.url(forResource: "uebungen", withExtension: "json")
                ?? bundle.url(forResource: "uebungen", withExtension: "json", subdirectory: "Health"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Uebung].self, from: daten) else { return [] }
        return liste
    }

    /// Lowercased, accents and umlauts folded, "ae/oe/ue" read as "a/o/u", "ß" as "ss", hyphens as
    /// spaces: "Bankdrücken", "bankdruecken" and "Bankdrucken" all become "bankdrucken".
    static func normal(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ae", with: "a")
            .replacingOccurrences(of: "oe", with: "o")
            .replacingOccurrences(of: "ue", with: "u")
            .replacingOccurrences(of: "-", with: " ")
    }

    /// Every word must appear in name, English name, muscle, equipment or body part. Names starting
    /// with the first word come first, then shorter names. Empty text: everything by name.
    static func suchen(_ text: String, in liste: [Uebung] = alle) -> [Uebung] {
        let woerter = normal(text).split(separator: " ").map(String.init)
        guard let erstes = woerter.first else { return liste.sorted { $0.name < $1.name } }
        let treffer = liste.filter { u in
            let s = suchtexte[u.id] ?? suchtext(u)
            return woerter.allSatisfy { s.contains($0) }
        }
        return treffer.sorted { a, b in
            let vornA = normal(a.name).hasPrefix(erstes), vornB = normal(b.name).hasPrefix(erstes)
            if vornA != vornB { return vornA }
            if a.name.count != b.name.count { return a.name.count < b.name.count }
            return a.name < b.name
        }
    }

    private static func suchtext(_ u: Uebung) -> String {
        normal("\(u.name) \(u.en) \(u.muskel) \(u.geraet) \(u.koerper)")
    }
}

/// The exercise GIFs are not bundled (they belong to ExerciseDB and the repo can be public): each
/// one is fetched once from ExerciseDB's CDN and kept in Caches. The own plan's exercises are
/// fetched ahead (`vorladen`, from the Health card) so they play offline in the gym.
enum UebungsMedien {
    static let quelle = URL(string: "https://static.exercisedb.dev/media/")!
    static var ordner: URL { URL.cachesDirectory.appending(path: "Uebungen", directoryHint: .isDirectory) }

    static func lokal(_ id: String) -> URL { ordner.appending(path: "\(id).gif") }

    /// The local GIF, downloaded first if needed; nil offline without a copy (or an unknown id).
    // ponytail: Caches may be purged by iOS under storage pressure; the next view or `vorladen` fetches again.
    static func datei(_ id: String) async -> URL? {
        let ziel = lokal(id)
        if FileManager.default.fileExists(atPath: ziel.path) { return ziel }
        guard let (daten, antwort) = try? await URLSession.shared.data(from: quelle.appending(path: "\(id).gif")),
              (antwort as? HTTPURLResponse)?.statusCode == 200, daten.starts(with: Data("GIF".utf8)) else { return nil }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? daten.write(to: ziel, options: .atomic)
        return ziel
    }

    /// One after another, so a long plan doesn't hit the CDN all at once.
    static func vorladen(_ ids: [String]) async {
        for id in ids where id != PlanUebung.eigen {
            _ = await datei(id)
        }
    }
}
