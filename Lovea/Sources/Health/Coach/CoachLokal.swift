import Foundation

// Health-Coach, nur auf diesem Gerät: stabile Schlüssel, kleine Merklisten (Haken, Daumen, Gemerktes), Suche, Export
// und die Schnellfragen je nach Tageszeit. Reine Logik, nichts hier liest Modelle oder die Uhr.

enum CoachLokal {
    // MARK: - Schlüssel

    /// FNV-1a (64 Bit) über die UTF-8-Bytes, als Hex. `hashValue` ist je Start anders, dieser Wert bleibt gleich.
    static func stabilerHash(_ text: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return String(h, radix: 16)
    }

    /// Schlüssel für eine Nachricht: der Text ohne Rand. Er bleibt gleich, wenn aus dem lokalen Eintrag die Op vom
    /// Server wird (die Id wechselt dabei, der Text nicht).
    static func schluessel(_ text: String) -> String {
        stabilerHash(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Merklisten

    /// `eintrag` kommt ans Ende (an) oder fliegt raus (aus). Zu lange Listen verlieren die ältesten Einträge.
    static func setzen(_ liste: [String], _ eintrag: String, an: Bool, maximal: Int) -> [String] {
        var neu = liste.filter { $0 != eintrag }
        if an { neu.append(eintrag) }
        return Array(neu.suffix(max(maximal, 0)))
    }

    // MARK: - Fortschritt

    /// Anteil von `aktuell` an `ziel`, begrenzt auf 0 bis 1. Ohne gültiges Ziel 0.
    static func anteil(aktuell: Double, ziel: Double) -> Double {
        guard ziel > 0, aktuell.isFinite else { return 0 }
        return min(max(aktuell / ziel, 0), 1)
    }

    // MARK: - Schnellfragen

    static let wochenrueckblick = "Mach meinen Wochenrückblick"
    static let luecken = "Was habe ich heute noch nicht eingetragen?"

    /// Welche Fragen heute schon gestellt wurden (getrimmter Text der eigenen Nachrichten von heute).
    static func heuteGefragt(_ liste: [CoachNachricht], jetzt: Date, kalender: Calendar) -> Set<String> {
        var gefragt: Set<String> = []
        for nachricht in liste where nachricht.rolle == .du && kalender.isDate(nachricht.zeit, inSameDayAs: jetzt) {
            gefragt.insert(nachricht.text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return gefragt
    }

    /// Höchstens vier Fragen: je nach Tageszeit andere Reihenfolge, am Sonntag und Montag zuerst der Wochenrückblick,
    /// abends die Frage nach Lücken im Tag. Was heute schon gefragt wurde, fällt weg, solange noch etwas übrig bleibt.
    /// `wochentag` wie bei `Calendar`: 1 = Sonntag, 2 = Montag.
    static func schnellfragen(stunde: Int, wochentag: Int, schonGefragt: Set<String>) -> [String] {
        var basis: [String]
        switch CoachText.tageszeit(stunde: stunde) {
        case .morgen: basis = ["Was soll ich heute essen?", "Wie läuft mein Training?", "Tagesbericht"]
        case .tag: basis = ["Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"]
        case .abend: basis = ["Tagesbericht", luecken, "Wie läuft mein Training?"]
        case .nacht: basis = CoachRegeln.schnellfragen
        }
        if wochentag == 1 || wochentag == 2 { basis.insert(wochenrueckblick, at: 0) }
        let neu = basis.filter { !schonGefragt.contains($0) }
        return Array((neu.isEmpty ? basis : neu).prefix(4))
    }

    // MARK: - Suche und Sprung

    /// Nachrichten, deren Text (ohne Marker) den Begriff enthält, ohne Rücksicht auf Groß-/Kleinschreibung und Akzente.
    static func suche(_ liste: [CoachNachricht], begriff: String) -> [CoachNachricht] {
        let gesucht = begriff.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gesucht.isEmpty else { return [] }
        return liste.filter { nachricht in
            CoachMarker.zerlegen(nachricht.text).text.range(of: gesucht, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    struct Tag: Equatable {
        let id: String
        let zeit: Date
    }

    /// Die erste Nachricht jedes Tages, neueste zuerst, höchstens `maximal`. `liste` ist nach Zeit sortiert.
    static func tage(_ liste: [CoachNachricht], kalender: Calendar, maximal: Int = 10) -> [Tag] {
        var ergebnis: [Tag] = []
        var letzte: Date?
        for nachricht in liste {
            if let letzte, kalender.isDate(letzte, inSameDayAs: nachricht.zeit) { continue }
            ergebnis.append(Tag(id: nachricht.id, zeit: nachricht.zeit))
            letzte = nachricht.zeit
        }
        return Array(ergebnis.reversed().prefix(maximal))
    }

    // MARK: - Export

    /// Der Verlauf als Text: je Nachricht `[Zeit] Name: Text`, getrennt durch eine Leerzeile. Marker fallen weg.
    static func export(_ liste: [CoachNachricht], ich: String, zeit: (Date) -> String) -> String {
        liste.map { nachricht -> String in
            let text = nachricht.rolle == .du
                ? nachricht.text.trimmingCharacters(in: .whitespacesAndNewlines)
                : CoachMarker.zerlegen(nachricht.text).text
            return "[\(zeit(nachricht.zeit))] \(nachricht.rolle == .du ? ich : "Coach"): \(text)"
        }.joined(separator: "\n\n")
    }

    // MARK: - Erinnerungen

    /// Gleiche Zeit und gleicher Text ergeben dieselbe Kennung; eine zweite Erinnerung ersetzt die erste.
    static func erinnerungsKennung(stunde: Int, minute: Int, text: String) -> String {
        "coach.erinnerung.\(stunde).\(minute).\(schluessel(text))"
    }
}
