import Foundation

// "Wordle-Duell": reine Logik. Beide raten dasselbe deutsche Fünf-Buchstaben-Wort, das aus dem
// Datum der Einladung und der Partie folgt (kein Server, kein Schiedsrichter).
//
// Umlaute sind eigene Buchstaben (Ä, Ö, Ü), kein ß: So passt jedes Wort der Liste so, wie man es
// schreibt, und die QWERTZ-Tastatur hat Ü, Ö, Ä am Reihenende wie auf dem iPhone. Ohne Umlaute
// müsste "KÜSSE" als "KUSSE" getippt werden, das fühlt sich falsch an.

enum Wordle {
    static let laenge = 5
    static let versuche = 6
    static let tastatur = ["QWERTZUIOPÜ", "ASDFGHJKLÖÄ", "YXCVBNM"]

    /// Reihenfolge = Rang: ein Buchstabe zeigt immer die beste bisherige Farbe.
    enum Farbe: Int, Comparable, Sendable {
        case fehlt, vorhanden, richtig
        static func < (a: Farbe, b: Farbe) -> Bool { a.rawValue < b.rawValue }
    }

    // MARK: - Wörter

    struct Woerter: Sendable {
        let ziele: [String]
        let erlaubt: [String]
        let menge: Set<String>

        init(ziele: [String], erlaubt: [String]) {
            self.ziele = ziele.map(Wordle.norm)
            self.erlaubt = erlaubt.map(Wordle.norm)
            menge = Set(self.ziele).union(self.erlaubt)
        }
    }

    private struct Datei: Decodable {
        var ziele: [String]
        var erlaubt: [String]?
    }

    /// `wordle-woerter.json`: `ziele` (können das Tageswort sein) und `erlaubt` (nur als Tipp gültig).
    static func dekodieren(_ daten: Data) -> Woerter? {
        guard let d = try? JSONDecoder().decode(Datei.self, from: daten) else { return nil }
        return Woerter(ziele: d.ziele, erlaubt: d.erlaubt ?? [])
    }

    static func laden(bundle: Bundle = .main) -> Woerter {
        let url = bundle.url(forResource: "wordle-woerter", withExtension: "json")
            ?? bundle.url(forResource: "wordle-woerter", withExtension: "json", subdirectory: "Spiele")
        return url.flatMap { try? Data(contentsOf: $0) }.flatMap(dekodieren) ?? Woerter(ziele: [], erlaubt: [])
    }

    static let woerter: Woerter = laden()

    /// Großbuchstaben, ohne Leerraum.
    static func norm(_ wort: String) -> String {
        wort.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func gueltig(_ wort: String, in w: Woerter) -> Bool {
        let n = norm(wort)
        return n.count == laenge && w.menge.contains(n)
    }

    // MARK: - Tageswort

    /// "yyyy-MM-dd" in Berlin, gregorianisch: unabhängig von Sprache, Region und Kalender des Geräts.
    static func tag(_ datum: Date) -> String {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        let c = kalender.dateComponents([.year, .month, .day], from: datum)
        func zwei(_ n: Int?) -> String { (n ?? 0) < 10 ? "0\(n ?? 0)" : "\(n ?? 0)" }
        return "\(c.year ?? 0)-\(zwei(c.month))-\(zwei(c.day))"
    }

    /// Dasselbe Wort für beide, solange Tag und Partie gleich sind. Jede neue Partie bringt ein anderes.
    static func ziel(woerter w: Woerter, tag: String, partie: Int) -> String {
        guard !w.ziele.isEmpty else { return "" }
        let i = Int(Zufall.seed("\(tag)#\(partie)#wordle") % UInt64(w.ziele.count))
        return w.ziele[i]
    }

    // MARK: - Färbung

    /// Zwei Durchgänge, damit doppelte Buchstaben stimmen: erst alle richtigen Plätze, dann
    /// "vorhanden" nur, solange der Buchstabe im Ziel noch nicht verbraucht ist.
    static func bewerten(_ tipp: String, ziel: String) -> [Farbe] {
        let t = Array(norm(tipp)), z = Array(norm(ziel))
        var farben = [Farbe](repeating: .fehlt, count: t.count)
        guard t.count == z.count else { return farben }
        var uebrig: [Character: Int] = [:]
        for i in t.indices {
            if t[i] == z[i] {
                farben[i] = .richtig
            } else {
                uebrig[z[i], default: 0] += 1
            }
        }
        for i in t.indices where farben[i] != .richtig {
            if let n = uebrig[t[i]], n > 0 {
                farben[i] = .vorhanden
                uebrig[t[i]] = n - 1
            }
        }
        return farben
    }

    /// Beste Farbe je Buchstabe über alle Tipps (für die Tastatur). Ungetippte Buchstaben fehlen.
    static func tastaturFarben(tipps: [String], ziel: String) -> [Character: Farbe] {
        var m: [Character: Farbe] = [:]
        for tipp in tipps {
            for (b, f) in zip(Array(norm(tipp)), bewerten(tipp, ziel: ziel)) {
                if f > (m[b] ?? .fehlt) || m[b] == nil { m[b] = f }
            }
        }
        return m
    }

    // MARK: - Ergebnis und Sieger

    struct Lauf: Equatable, Sendable {
        var gewonnen: Bool
        /// Versuche bis zum Treffer, sonst alle bisherigen.
        var versuche: Int
        /// Millisekunden vom Start des Bretts bis zum letzten gezählten Tipp.
        var ms: Int
        var fertig: Bool
    }

    /// `zeiten[i]` ist die Zeit des i-ten Tipps. Tipps nach dem Treffer oder nach dem sechsten zählen nicht.
    static func lauf(tipps: [String], zeiten: [Int], ziel: String) -> Lauf {
        let z = norm(ziel)
        for (i, t) in tipps.prefix(versuche).enumerated() where norm(t) == z {
            return Lauf(gewonnen: true, versuche: i + 1, ms: zeiten.indices.contains(i) ? zeiten[i] : 0, fertig: true)
        }
        let n = min(tipps.count, versuche)
        let ms = n > 0 && zeiten.indices.contains(n - 1) ? zeiten[n - 1] : 0
        return Lauf(gewonnen: false, versuche: n, ms: ms, fertig: n >= versuche)
    }

    enum Ausgang: Equatable, Sendable {
        case offen
        case remis
        case sieg(Person)
    }

    /// Weniger Versuche gewinnt, bei Gleichstand die schnellere Zeit, sonst Remis. Entschieden
    /// wird früh, sobald der Gegner den Vorsprung nicht mehr aufholen kann.
    static func ausgang(ahmed: Lauf, annika: Lauf) -> Ausgang {
        let laeufe: [Person: Lauf] = [.ahmed: ahmed, .annika: annika]
        if ahmed.fertig && annika.fertig {
            switch (ahmed.gewonnen, annika.gewonnen) {
            case (false, false): return .remis
            case (true, false): return .sieg(.ahmed)
            case (false, true): return .sieg(.annika)
            case (true, true):
                if ahmed.versuche != annika.versuche { return .sieg(ahmed.versuche < annika.versuche ? .ahmed : .annika) }
                if ahmed.ms != annika.ms { return .sieg(ahmed.ms < annika.ms ? .ahmed : .annika) }
                return .remis
            }
        }
        // Einer hat gelöst, der andere rät noch mit m Versuchen. Er kann frühestens mit m + 1 lösen
        // und nur gewinnen, wenn das nicht mehr Versuche sind als beim Gegner.
        for p in [Person.ahmed, .annika] {
            guard let l = laeufe[p], let anderer = laeufe[p.partner], l.gewonnen, !anderer.fertig else { continue }
            if anderer.versuche >= l.versuche { return .sieg(p) }
        }
        return .offen
    }

    static func ende(ahmed: Lauf, annika: Lauf, ziel: String) -> PartieEnde? {
        let wort = norm(ziel)
        switch ausgang(ahmed: ahmed, annika: annika) {
        case .offen:
            return nil
        case .remis:
            let text = ahmed.gewonnen
                ? "Beide in \(ahmed.versuche) Versuchen, gleich schnell. Das Wort war \(wort)."
                : "Keiner hat es gelöst. Das Wort war \(wort)."
            return PartieEnde(punkte: SpielPunkte(), sieger: nil, text: text, titel: nil)
        case .sieg(let p):
            var punkte = SpielPunkte()
            punkte[p] = 1
            let mein = p == .ahmed ? ahmed : annika
            let sein = p == .ahmed ? annika : ahmed
            let danach = sein.gewonnen ? "gegen \(sein.versuche)" : "(der andere hat es nicht gelöst)"
            return PartieEnde(punkte: punkte, sieger: p, text: "\(wort) in \(mein.versuche) Versuchen \(danach).", titel: nil)
        }
    }
}
