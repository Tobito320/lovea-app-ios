import Foundation

// Zwei Sicherungen gegen den verschwindenden Strich (Auftrag 02.10.). Die Entscheidungen sind reine
// Funktionen ohne Metal, damit sie als Unit-Test laufen. Engine und Verlauf rufen sie nur auf.

/// Darf ein Ladeergebnis (`CanvasEngine.reload`) die Ebenen ersetzen?
enum LadeEntscheidung {
    /// Nur wenn gerade kein eigener Strich läuft und seit dem Start des Ladens keiner gelandet ist.
    /// Sonst ist die Leinwand neuer als die Datei, und das Ergebnis würde den Strich überschreiben.
    static func darfUebernehmen(landungenBeiStart: Int, landungenJetzt: Int, strichLaeuft: Bool) -> Bool {
        !strichLaeuft && landungenJetzt == landungenBeiStart
    }
}

/// Hat der Umbau im gemeinsamen Verlauf einen eigenen, schon gelandeten Strich verloren?
enum UmbauPruefung {
    struct Stand: Equatable {
        var id: String
        /// Zurückgenommen (Undo): hat bewusst keine Pixel.
        var aus: Bool
        /// Hat Undo-Daten, also Pixel auf der Ebene.
        var gelandet: Bool
        /// Ebene da, eine Malebene und nicht für ihn gesperrt. Nur dann ist ein leeres Ergebnis ein Verlust
        /// und keine Regel (Z-13.3: gesperrte Ebene nimmt keinen Strich des anderen).
        var sollteLanden: Bool
    }

    /// Ids der Striche, die vor dem Umbau gelandet waren und danach nicht mehr, obwohl sie landen sollten.
    /// Verglichen wird nach id: `empfangen` fügt Einträge ein, `kuerzen` entfernt alte.
    static func verloren(vorher: [Stand], nachher: [Stand]) -> [String] {
        let jetzt = Dictionary(nachher.map { ($0.id, $0) }, uniquingKeysWith: { erster, _ in erster })
        return vorher.compactMap { alt in
            guard alt.gelandet, !alt.aus, let neu = jetzt[alt.id], !neu.aus, !neu.gelandet, neu.sollteLanden else { return nil }
            return alt.id
        }
    }

    enum Nachbesserung: Equatable {
        case fertig, gezielt, voll, aufgeben
    }

    /// Was nach einem Umbau zu tun ist. Erst ein gezielter Versuch ab dem ersten verlorenen Eintrag, dann einmal
    /// alles neu aufbauen (das kostet am meisten, darum nur einmal pro Verlauf), dann aufgeben: ein Fehler, der
    /// bleibt, soll nicht jeden Umbau verlängern.
    static func nachbesserung(verloren: [String], versuch: Int, vollSchonVersucht: Bool) -> Nachbesserung {
        guard !verloren.isEmpty else { return .fertig }
        switch versuch {
        case 0: return .gezielt
        case 1 where !vollSchonVersucht: return .voll
        default: return .aufgeben
        }
    }
}
