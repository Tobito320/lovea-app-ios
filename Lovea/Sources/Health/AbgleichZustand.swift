/// Reiner Zustand ohne ActivityKit — testbar. Build 78 (Ahmed: beim Replay feuern `TrainingModell`s
/// und `ErnaehrungModell`s Op-Beobachter `GymLive`/`EssenLive.abgleichen()` für JEDEN einzelnen Op,
/// bei hunderten Ops also hunderte serialisierte ActivityKit-Anfragen am Stück — Hauptverdächtiger
/// für den sofortigen Absturz). `GymLive`/`EssenLive` queuen bei einem laufenden Durchlauf keinen
/// weiteren Task mehr, sondern merken sich nur "nochmal nötig" und hängen das direkt an den
/// laufenden Durchlauf an — der tatsächliche Zielzustand wird dabei erst bei der Ausführung
/// berechnet (nicht beim Aufruf), siehe `GymLive.lauf`/`EssenLive.lauf`.
enum AbgleichZustand: Equatable {
    case leer
    case laeuft
    case laeuftSchmutzig

    /// Ein neuer `abgleichen()`-Aufruf kommt rein. `starten`: ob dafür ein neuer Task losgeschickt
    /// werden muss (nur aus `.leer` — sonst hängt sich der Aufruf an den laufenden Durchlauf an).
    static func aufruf(_ jetzt: AbgleichZustand) -> (starten: Bool, neu: AbgleichZustand) {
        switch jetzt {
        case .leer: return (true, .laeuft)
        case .laeuft, .laeuftSchmutzig: return (false, .laeuftSchmutzig)
        }
    }

    /// Ein Durchlauf ist fertig. `nochmal`: ob sofort noch einer folgen muss (es kam während des
    /// Laufens mindestens ein weiterer Aufruf).
    static func fertig(_ jetzt: AbgleichZustand) -> (nochmal: Bool, neu: AbgleichZustand) {
        switch jetzt {
        case .laeuftSchmutzig: return (true, .laeuft)
        case .leer, .laeuft: return (false, .leer)
        }
    }
}
