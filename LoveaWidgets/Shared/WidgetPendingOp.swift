import Foundation

/// Eine wartende `habit.setzen`-Op aus `GymHeuteIntent` (Z-28.3) — eine Datei pro Op unter
/// `WidgetGruppe.pendingOrdner()`, Dateiname `<id>.json`. Absichtlich nur für `habit.setzen`
/// typisiert statt eines generischen Op-Umschlags: das ist die einzige Op-Art, die ein Widget-Intent
/// in dieser Runde sendet (ponytail — Aufwertung: ein generischer `{art,d}`-Umschlag, falls ein
/// künftiges Widget eine andere Op-Art braucht).
struct WidgetPendingOp: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var von: String // Person.rawValue
    /// ISO 8601 mit Sekundenbruchteilen, wie `Op`s eigener Encoder.
    var zeit: String
    var datum: String
    var wert: Int
}

/// Reine Logik ohne Dateizugriff — testbar ohne App Group/Sandbox.
enum WidgetPendingMerge {
    /// Ein Verzeichnis-Listing kann (Race zwischen Intent-Schreiben und App-Lesen, oder ein Merge-
    /// Aufruf, der über zwei `.active`-Wechsel hinweg noch nicht fertig geräumt hat) dieselbe `id`
    /// mehrfach liefern. `Raum`s Faltungen sind zwar selbst schon idempotent pro Op-`id`, aber es
    /// gibt keinen Grund, dieselbe Op zweimal in die Warteschlange zu reihen.
    static func eindeutig(_ pendings: [WidgetPendingOp]) -> [WidgetPendingOp] {
        var gesehen = Set<String>()
        return pendings.filter { gesehen.insert($0.id).inserted }
    }
}
