import Foundation

/// Reine Logik für die gemeinsamen Sammlungen im Zimmer (Worker H). Kein Zustand, keine Singletons, damit testbar.
enum ZimmerSammlungLogik {
    static let kalender: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4 // ISO 8601
        return c
    }()

    // MARK: Dankbarkeitsbaum

    /// Zählt Nachrichtentexte, die "danke" enthalten (Groß-/Kleinschreibung egal, "Dankeschön" zählt mit).
    static func dankeZaehlen(_ texte: [String?]) -> Int {
        texte.reduce(0) { $0 + (istDanke($1) ? 1 : 0) }
    }

    static func istDanke(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return false }
        return text.range(of: "danke", options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")) != nil
    }

    /// Herbst = September bis November.
    static func istHerbst(_ datum: Date) -> Bool {
        (9...11).contains(kalender.component(.month, from: datum))
    }

    /// Verteilt die Blätter: im Herbst fällt ein Drittel in den Erinnerungshaufen, sonst bleibt alles am Baum.
    static func blaetter(gesamt: Int, herbst: Bool) -> (baum: Int, haufen: Int) {
        let n = max(0, gesamt)
        guard herbst else { return (n, 0) }
        let haufen = n / 3
        return (n - haufen, haufen)
    }

    /// Wie viele Blätter wirklich gezeichnet werden (der Baum bleibt klein).
    static func sichtbar(_ n: Int, maximal: Int) -> Int { min(max(0, n), maximal) }

    // MARK: Mixtape

    /// ISO-Woche als Schlüssel, z. B. "2026-W41".
    static func woche(_ datum: Date) -> String {
        let t = kalender.dateComponents([.yearForWeekOfYear, .weekOfYear], from: datum)
        return String(format: "%04d-W%02d", t.yearForWeekOfYear ?? 0, t.weekOfYear ?? 0)
    }

    /// Nur Spotify-Links werden geöffnet. Alles andere ergibt `nil`.
    static func spotifyURL(_ text: String) -> URL? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 300, let url = URL(string: t), let schema = url.scheme?.lowercased() else { return nil }
        if schema == "spotify" { return url }
        guard schema == "https", let host = url.host?.lowercased() else { return nil }
        let ok = host == "open.spotify.com" || host == "spotify.link" || host.hasSuffix(".spotify.com")
        return ok ? url : nil
    }

    struct Kassette: Codable, Equatable, Identifiable {
        var woche: String
        var url: String
        var titel: String
        var id: String { woche }
    }

    static let kassettenMaximum = 8

    /// Ersetzt die Kassette derselben Woche, behält die neuesten `kassettenMaximum`.
    static func kassetteEinlegen(_ alt: [Kassette], neu: Kassette) -> [Kassette] {
        var liste = alt.filter { $0.woche != neu.woche }
        liste.append(neu)
        liste.sort { $0.woche < $1.woche }
        return Array(liste.suffix(kassettenMaximum))
    }

    // MARK: Rezeptkasten

    struct Rezept: Codable, Equatable, Identifiable {
        var id: String
        var titel: String
        var foto: Data? // kleines JPEG-Vorschaubild
    }

    static let rezepteMaximum = 12
    static let titelMaximum = 40

    static func bereinigt(_ text: String, maximal: Int) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return String(t.prefix(maximal))
    }

    /// Sterne eines Rezepts = verschiedene Kochtage (Einträge "id|tag" beider Personen).
    static func sterne(rezeptId: String, gekocht: [String]) -> Int {
        Set(gekocht.filter { $0.hasPrefix(rezeptId + "|") }).count
    }

    /// Fügt "id|tag" hinzu, falls für diesen Tag noch nicht vorhanden. Hält die Liste kurz.
    static func gekocht(_ alt: [String], rezeptId: String, tag: String) -> [String] {
        let marke = rezeptId + "|" + tag
        guard !alt.contains(marke) else { return alt }
        return Array((alt + [marke]).suffix(400))
    }

    // MARK: Wunschrolle

    struct Wunsch: Codable, Equatable, Identifiable {
        var id: String
        var text: String
    }

    static let wuenscheMaximum = 20

    /// Gemeinsam erledigt = beide haben den Punkt abgehakt.
    static func gemeinsamErledigt(_ meine: [String], _ partner: [String]) -> Set<String> {
        Set(meine).intersection(partner)
    }

    static func umschalten(_ liste: [String], id: String) -> [String] {
        liste.contains(id) ? liste.filter { $0 != id } : liste + [id]
    }

    /// Kühlschrank-Aufkleber: je erledigtem Punkt einer, höchstens `maximal`.
    static func aufkleber(erledigt: Int, maximal: Int = 6) -> Int { min(max(0, erledigt), maximal) }

    // MARK: Stimmungsregenbogen

    /// Die letzten `anzahl` Tage bis heute, ältester zuerst, als `yyyy-MM-dd`.
    static func letzteTage(heute: String, anzahl: Int = 7) -> [String] {
        guard let start = tagDatum(heute) else { return [] }
        return (0..<anzahl).reversed().compactMap { zurueck in
            kalender.date(byAdding: .day, value: -zurueck, to: start).map(tagText)
        }
    }

    /// Trägt die aktuelle Stimmung für heute ein, behält nur die letzten `behalten` Tage.
    static func verlaufEintragen(_ alt: [String: String], tag: String, art: String?, behalten: Int = 14) -> [String: String] {
        var neu = alt
        if let art { neu[tag] = art }
        guard neu.count > behalten else { return neu }
        for k in neu.keys.sorted().dropLast(behalten) { neu[k] = nil }
        return neu
    }

    /// Pro Tag die Stimmung (Rohwert) oder `nil`.
    static func bogen(_ verlauf: [String: String], tage: [String]) -> [String?] {
        tage.map { verlauf[$0] }
    }

    // MARK: Wachstumsleiste

    struct Marke: Equatable, Identifiable {
        var titel: String
        var tag: String
        var erreicht: Bool
        var id: String { tag + titel }
    }

    struct EigeneMarke: Codable, Equatable {
        var titel: String
        var tag: String
    }

    static let markenMaximum = 5

    /// Meilensteine ab `start` (Tage 100, 250, 500, 1000 und Jahrestage) plus eigene Marken ("Eingezogen", "Erste Reise").
    /// Gezeigt werden die letzten erreichten und die nächste offene.
    static func marken(heute: String, start: String, eigene: [EigeneMarke]) -> [Marke] {
        guard let s = tagDatum(start) else { return [] }
        func nach(tage: Int) -> String? { kalender.date(byAdding: .day, value: tage, to: s).map(tagText) }
        func nach(jahre: Int) -> String? { kalender.date(byAdding: .year, value: jahre, to: s).map(tagText) }
        var alle: [Marke] = [Marke(titel: "Zusammen", tag: start, erreicht: start <= heute)]
        for t in [100, 250, 500, 1000] {
            if let d = nach(tage: t) { alle.append(Marke(titel: "\(t) Tage", tag: d, erreicht: d <= heute)) }
        }
        for j in 1...3 {
            if let d = nach(jahre: j) { alle.append(Marke(titel: j == 1 ? "1 Jahr" : "\(j) Jahre", tag: d, erreicht: d <= heute)) }
        }
        for e in eigene where tagDatum(e.tag) != nil {
            alle.append(Marke(titel: e.titel, tag: e.tag, erreicht: e.tag <= heute))
        }
        alle.sort { $0.tag == $1.tag ? $0.titel < $1.titel : $0.tag < $1.tag }
        let erreicht = alle.filter(\.erreicht)
        let offen = alle.first { !$0.erreicht }
        return Array(erreicht.suffix(markenMaximum - 1)) + (offen.map { [$0] } ?? [])
    }

    // MARK: Tage

    static func tagDatum(_ tag: String) -> Date? {
        let t = tag.split(separator: "-").compactMap { Int($0) }
        guard t.count == 3 else { return nil }
        var c = DateComponents()
        c.year = t[0]; c.month = t[1]; c.day = t[2]; c.hour = 12
        return kalender.date(from: c)
    }

    static func tagText(_ datum: Date) -> String {
        let t = kalender.dateComponents([.year, .month, .day], from: datum)
        return String(format: "%04d-%02d-%02d", t.year ?? 0, t.month ?? 0, t.day ?? 0)
    }
}
