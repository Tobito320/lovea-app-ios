import Foundation

struct Frage: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var text: String
    var kategorie: String // "lustig" | "goals" | "zukunft" | "deep"
}

enum FrageDesTages {
    /// Bundle-Vorrat aus `Kalender/Inhalt/fragen.json` (127 Fragen der Web-App).
    static let vorrat: [Frage] = ladeVorrat()

    /// Wählt die Frage für `tag` (Berlin-Datum `yyyy-MM-dd`), stabil pro Tag.
    ///
    /// ponytail: Die Web-App merkt sich je Kalendertag, welche Frage gezeigt wurde (KV-Eintrag
    /// `tagesfrage/<iso>` in `server/fragen.mjs`), damit "erste unbenutzte, sonst am längsten
    /// nicht benutzte" exakt stimmt. `schnittstellen.md` kennt dafür keine Op (nur
    /// `frage.antwort`/`frage.eigene`), also rotiert diese reine Funktion stattdessen
    /// deterministisch durch den festen Vorrat: Tag 0 = erste Frage, nach `vorrat.count` Tagen
    /// geht es wieder von vorne los. Für einen unveränderten Vorrat ist das dieselbe Reihenfolge
    /// wie "erste unbenutzte, dann am längsten nicht benutzte" — nur ohne Server-Zustand nötig.
    /// Aufwertung: eine eigene Op (z. B. `frage.zugewiesen`), falls der Vorrat später wächst oder
    /// schrumpft und die Reihenfolge sich verschieben darf.
    static func waehlen(vorrat: [Frage], tag: String) -> Frage? {
        guard !vorrat.isEmpty else { return nil }
        let tageSeitReferenz = Datum.tageZwischen(referenz, tag)
        let index = ((tageSeitReferenz % vorrat.count) + vorrat.count) % vorrat.count
        return vorrat[index]
    }

    private static let referenz = "2026-01-01"

    private static func ladeVorrat() -> [Frage] {
        // Je nach XcodeGen-Gruppenart landet die Datei flach im Bundle oder unter ihrem
        // Quellordner — beide Pfade abklopfen statt einen zu erraten.
        guard let url = Inhalt.url(datei: "fragen", typ: "json"),
              let data = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([Frage].self, from: data)
        else { return [] }
        return liste
    }
}
