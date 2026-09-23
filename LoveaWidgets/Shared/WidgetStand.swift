import Foundation

/// Kleiner Stand für die Widgets (Z-28.2, Spec 10) — von der App nach jeder relevanten Änderung
/// geschrieben (gedrosselt, `WidgetStandSchreiber` im App-Target), von `LoveaWidgets` gelesen.
/// Personen als `String` (`"ahmed"`/`"annika"`, `Person.rawValue`) statt des App-Target-Typs
/// `Person` — diese Datei kompiliert in BEIDE Targets, siehe `WidgetDatum`.
struct WidgetStand: Codable, Sendable, Equatable {
    struct TagEintrag: Codable, Sendable, Equatable {
        var datum: String
        var erledigt: Bool
    }

    var eigenePerson: String

    /// `nil`/fehlender Schlüssel = "keine Daten" (Review-Fokus 4: nie 0 zeigen, das ein Duell verlieren lässt).
    var schritteHeute: [String: Int] = [:]
    var zielSchritte: [String: Int] = [:]

    /// Montag bis Sonntag der Woche, in der zuletzt geschrieben wurde (7 Einträge), wie `zielGym`/
    /// `ChallengeLogik`. Der Intent bestimmt "heute" selbst über `WidgetDatum.heute()`, statt sich
    /// auf den zuletzt geschriebenen Tag hier zu verlassen (der Stand kann seit der letzten
    /// Mitternacht ungeschrieben geblieben sein), und hängt einen fehlenden Tag notfalls an.
    var gymLetzte7: [String: [TagEintrag]] = [:]
    var zielGymWoche: [String: Int] = [:]

    var punkte: [String: Int] = [:]

    var gemeinsamZielWoche: Int?
    var gemeinsamSchritteWoche: Int?

    var naechstesTreffenDatum: String?
    var naechstesTreffenText: String?

    var partnerOrtName: String?
    /// 0...1, gerundet auf 5 % — kein Grund, den exakten Wert in eine Datei zu schreiben, die vom
    /// Betriebssystem für Widget-Updates zwischengespeichert wird.
    var partnerAkku: Double?
    /// Ob `WidgetGruppe.partnerFigurURL()`/`partnerFotoURL()` gerade eine gültige Datei enthalten —
    /// die Bilder selbst liegen unter festen Pfaden in der App Group, ein Dateicheck beim Rendern
    /// reicht, diese Flags sparen der Timeline nur den überflüssigen Disk-Zugriff für "gibt es nicht".
    var partnerFigurVorhanden = false
    var partnerFotoVorhanden = false
    /// `nil`, solange kein `WetterModell` existiert (Runde-2-Parallelblock G, siehe Bericht).
    var partnerWetter: String?

    var frageDesTages: String?
}
