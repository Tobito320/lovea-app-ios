import Foundation

// Pure logic for the living objects in the profile room (p62). No models, no clock of its own:
// everything takes its inputs, so `ZimmerLebenLogikTests` can check every case.

// MARK: - 1 Kalenderblatt

struct ZimmerTermin: Equatable, Sendable {
    var titel: String
    /// `yyyy-MM-dd`; a running multi-day appointment shows today.
    var tag: String
    var uhrzeit: String?
}

enum ZimmerKalenderblatt {
    /// The next appointment both share (a Treffen, or a Termin for both), today or later.
    static func naechster(_ daten: KalenderDaten, heute: String) -> ZimmerTermin? {
        let beide = Set(Person.allCases.map(\.rawValue))
        var kandidaten: [ZimmerTermin] = daten.treffen
            .filter { $0.datum >= heute }
            .map { t in
                let was = t.wasMachenWir ?? ""
                return ZimmerTermin(titel: was.isEmpty ? "Treffen" : was, tag: t.datum, uhrzeit: t.uhrzeit)
            }
        kandidaten += daten.termine
            .filter { beide.isSubset(of: $0.fuer) && $0.letzterTag >= heute }
            .map { ZimmerTermin(titel: $0.titel, tag: max($0.datum, heute), uhrzeit: $0.start(am: max($0.datum, heute))) }
        return kandidaten.min { ($0.tag, $0.uhrzeit ?? "") < ($1.tag, $1.uhrzeit ?? "") }
    }

    private static let monate = ["JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]

    /// "2026-10-14" -> ("OKT", "14"); anything unreadable -> ("", "").
    static func blatt(_ tag: String) -> (monat: String, tag: String) {
        let teile = tag.split(separator: "-")
        guard teile.count == 3, let m = Int(teile[1]), (1...12).contains(m), let t = Int(teile[2]) else { return ("", "") }
        return (monate[m - 1], String(t))
    }
}

// MARK: - 2 Fenster

/// What the window shows: the sky `ProfilSzene` already knows, plus whether it is dark out.
struct ZimmerHimmel: Equatable, Sendable {
    var wetter: ProfilSzene.Wetter
    var nacht: Bool

    init(wetter: ProfilSzene.Wetter, nacht: Bool) {
        self.wetter = wetter
        self.nacht = nacht
    }

    init(code: Int?, tag: Bool?, stunde: Int) {
        self.init(wetter: ProfilSzene.wetter(code: code), nacht: ProfilSzene.istNacht(tag: tag, stunde: stunde))
    }

    var text: String {
        switch wetter {
        case .sonne: nacht ? "Klare Nacht" : "Sonne"
        case .wolken: nacht ? "Wolkige Nacht" : "Wolken"
        case .regen: "Regen"
        case .schnee: "Schnee"
        }
    }
}

// MARK: - 7 Pokale

struct ZimmerPokal: Equatable, Sendable, Identifiable {
    enum Stufe: Int, Sendable { case bronze = 1, silber, gold }
    var art: SpielArt
    var ahmed: Int
    var annika: Int
    var id: SpielArt { art }
    /// Who leads this game; `nil` on a tie.
    var fuehrt: Person? { ahmed == annika ? nil : (ahmed > annika ? .ahmed : .annika) }
    var stufe: Stufe { Self.stufe(max(ahmed, annika)) }

    static func stufe(_ siege: Int) -> Stufe { siege >= 15 ? .gold : (siege >= 5 ? .silber : .bronze) }
}

enum ZimmerPokale {
    /// One cup per game with at least one win, the most won first. Ties keep the game order.
    static func aus(_ bilanz: [SpielArt: SpielPunkte]) -> [ZimmerPokal] {
        SpielArt.allCases.compactMap { art -> ZimmerPokal? in
            guard let p = bilanz[art], p.ahmed + p.annika > 0 else { return nil }
            return ZimmerPokal(art: art, ahmed: p.ahmed, annika: p.annika)
        }
        .enumerated()
        .sorted { ($1.element.ahmed + $1.element.annika, $0.offset) < ($0.element.ahmed + $0.element.annika, $1.offset) }
        .map(\.element)
    }
}

// MARK: - 8 Pflanze

struct ZimmerPflanzenStand: Equatable, Sendable {
    /// 0 seedling ... 4 in bloom.
    var stufe: Int
    /// One of them dropped out: the leaves droop.
    var haengt: Bool
    /// The shared streak in days (the weaker of the two).
    var serie: Int

    var text: String {
        if haengt { return "Die Blätter hängen: einer von euch ist raus. Macht zusammen weiter." }
        return serie > 0 ? "\(serie) Tage gemeinsame Serie" : "Haltet zusammen eine Gewohnheit durch, dann wächst sie."
    }

    static func stufe(serie: Int) -> Int {
        switch serie {
        case ..<1: 0
        case 1...2: 1
        case 3...6: 2
        case 7...13: 3
        default: 4
        }
    }

    /// `serien`: both streaks of every habit the two share. The plant grows with the best shared
    /// one (the weaker partner counts); when nobody has a shared streak but one still has a
    /// running one, the leaves droop.
    static func aus(_ serien: [(ahmed: Int, annika: Int)]) -> ZimmerPflanzenStand {
        let gemeinsam = serien.map { min($0.ahmed, $0.annika) }.max() ?? 0
        if gemeinsam > 0 { return ZimmerPflanzenStand(stufe: stufe(serie: gemeinsam), haengt: false, serie: gemeinsam) }
        let einer = serien.map { max($0.ahmed, $0.annika) }.max() ?? 0
        return ZimmerPflanzenStand(stufe: min(stufe(serie: einer), 3), haengt: einer > 0, serie: 0)
    }
}

// MARK: - 4 Pinnwand, 5 Rückblick

struct ZimmerPolaroid: Equatable, Sendable, Identifiable {
    var id: String
    var medienId: String
    var zeit: Date
}

enum ZimmerFotos {
    private static func foto(_ n: ChatModell.Nachricht) -> String? {
        guard !n.geloescht, n.system == nil, n.spiel == nil, n.einladung == nil else { return nil }
        return n.medien.first { $0.typ == "foto" }?.id
    }

    /// The last saved snaps with a photo, newest first.
    static func letzte(_ nachrichten: [ChatModell.Nachricht], anzahl: Int = 3) -> [ZimmerPolaroid] {
        nachrichten
            .filter { n in n.snap.map { n.snapGespeichert || $0.bleibt } ?? false }
            .compactMap { n in foto(n).map { ZimmerPolaroid(id: n.id, medienId: $0, zeit: n.zeit) } }
            .sorted { $0.zeit > $1.zeit }
            .prefix(anzahl)
            .map { $0 }
    }

    /// A photo from exactly one year ago today (newest of that day). Unsaved snaps are fleeting.
    static func vorEinemJahr(_ nachrichten: [ChatModell.Nachricht], jetzt: Date = Date()) -> ZimmerPolaroid? {
        guard let ziel = Calendar.berlin.date(byAdding: .year, value: -1, to: jetzt),
              let fenster = Calendar.berlin.dateInterval(of: .day, for: ziel) else { return nil }
        return nachrichten
            .filter { fenster.contains($0.zeit) && ($0.snap.map { s in $0.snapGespeichert || s.bleibt } ?? true) }
            .compactMap { n in foto(n).map { ZimmerPolaroid(id: n.id, medienId: $0, zeit: n.zeit) } }
            .max { $0.zeit < $1.zeit }
    }
}

// MARK: - 6 Fernseher: gemeinsame Film- und Serienliste

struct ZimmerFilm: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var titel: String
    var serie: Bool
    var gesehen: Bool
}

enum ZimmerFilme {
    /// What is on right now: the first one not seen yet.
    static func laeuft(_ liste: [ZimmerFilm]) -> ZimmerFilm? { liste.first { !$0.gesehen } }

    static func hinzufuegen(_ liste: [ZimmerFilm], titel: String, serie: Bool, id: String = UUID().uuidString) -> [ZimmerFilm] {
        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !liste.contains(where: { $0.titel.caseInsensitiveCompare(t) == .orderedSame }) else { return liste }
        return liste + [ZimmerFilm(id: id, titel: t, serie: serie, gesehen: false)]
    }

    static func umschalten(_ liste: [ZimmerFilm], id: String) -> [ZimmerFilm] {
        liste.map { f in
            var f = f
            if f.id == id { f.gesehen.toggle() }
            return f
        }
    }

    static func entfernen(_ liste: [ZimmerFilm], id: String) -> [ZimmerFilm] { liste.filter { $0.id != id } }
}

// MARK: - 9 Gemeinsames Ziel

struct ZimmerZiel: Codable, Equatable, Sendable {
    var titel: String
    /// Suitcase (a trip) instead of the jar.
    var koffer: Bool
    var ziel: Double
    var gespart: Double

    var anteil: Double { ziel > 0 ? min(1, max(0, gespart / ziel)) : 0 }
    var geschafft: Bool { ziel > 0 && gespart >= ziel }

    /// "120 von 500 €" without trailing zeros.
    var text: String { "\(Self.zahl(gespart)) von \(Self.zahl(ziel)) €" }

    private static func zahl(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d).replacingOccurrences(of: ".", with: ",")
    }
}
