import Foundation

/// Annikas fester Stundenplan (Ahmed, 27.09.; Quelle: ihre Schul-App KW40/41), ohne Wechselwoche.
/// ponytail: ein Schul-Block pro Tag mit der echten Zeit. Ein Muster je Stunde ginge über `titel`,
/// wären aber rund 30 Zeilen im Wochenplan-Editor; Lehrer und Raum hat `Muster` nicht. Upgrade:
/// ein Muster je Stunde, wenn Ahmed Fächer im Kalender sehen will.
/// Vertretung und Ausfall sind einmalig und bleiben `Ausnahme`n, nie Teil des Musters.
enum Stundenplan {
    private static let ab = "2026-09-21"

    /// Mo und Mi 07:50–14:45, Di, Do und Fr 07:50–13:00.
    static func annika() -> [Muster] {
        [
            Muster(id: "start-annika-schule-lang", person: "annika", typ: "schule", titel: "Schule", wochentage: [1, 3], wochen: "alle", start: "07:50", ende: "14:45", ab: ab),
            Muster(id: "start-annika-schule-kurz", person: "annika", typ: "schule", titel: "Schule", wochentage: [2, 4, 5], wochen: "alle", start: "07:50", ende: "13:00", ab: ab),
        ]
    }

    /// Das alte Startmuster aus Z-9.4: Schule Mo–Fr ohne Uhrzeit. Nur wo genau das noch steht,
    /// ersetzt der Stundenplan es.
    static func altesStartmusterAnnika() -> Muster {
        Muster(id: "start-annika-schule", person: "annika", typ: "schule", titel: "Schule", wochentage: [1, 2, 3, 4, 5], wochen: "alle", start: nil, ende: nil, ab: ab)
    }

    struct Umstellung {
        let loeschen: String
        let setzen: [Muster]
    }

    /// Nur auf Annikas eigenem Handy und nur, wenn ihre Muster genau das unveränderte alte Startmuster
    /// sind. Ein bearbeitetes, gelöschtes oder ergänztes Muster ist ihre Entscheidung und bleibt.
    static func umstellung(fuer ich: Person, muster: [Muster]) -> Umstellung? {
        guard ich == .annika else { return nil }
        let alt = altesStartmusterAnnika()
        guard muster.filter({ $0.person == ich.rawValue }) == [alt] else { return nil }
        return Umstellung(loeschen: alt.id, setzen: annika())
    }
}
