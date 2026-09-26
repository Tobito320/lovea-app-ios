import Foundation

/// Pure habit logic (Z-35.1, Spec 3.3). Days are `Datum` strings (Europe/Berlin).
///
/// `ziel` overrides the habit's own number where a person has a goal setting: for a counting habit
/// it is the daily target (Wasser: `ziel.wasser`), otherwise the weekly count of `.proWoche` (Gym:
/// `ziel.gym`). `nil` = use the habit's own `tagesziel` / `.proWoche(n)`. `HealthModell.habitZiel`
/// gives the right value per habit and person.
enum HabitLogik {
    static func erledigt(_ habit: Habit, wert: Int, ziel: Int?) -> Bool {
        habit.zaehlen ? wert >= tagesziel(habit, ziel) : wert > 0
    }

    /// 0…1 for week squares and rings: counting habits fill proportionally.
    static func anteil(_ habit: Habit, wert: Int, ziel: Int?) -> Double {
        guard habit.zaehlen else { return wert > 0 ? 1 : 0 }
        return min(1, Double(max(0, wert)) / Double(tagesziel(habit, ziel)))
    }

    /// Current streak ending today. "jeden Tag" counts days, "x pro Woche" weeks that reached the
    /// goal, fixed days only their due days (other days neither count nor break). Today (or this
    /// week) still open never breaks it. Walks back and stops at the first miss — cheap for tiles.
    static func serie(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String) -> Int {
        guard let start = start(habit, werte: werte, ziel: ziel, heute: heute) else { return 0 }
        let ende = einheit(habit, heute)
        var tag = ende
        var laenge = 0
        while tag >= start {
            if zaehlt(habit, tag) {
                if erfuellt(habit, werte: werte, ziel: ziel, einheit: tag) { laenge += 1 } else if tag != ende { break }
            }
            tag = Datum.addTage(tag, -schritt(habit))
        }
        return laenge
    }

    /// Longest streak ever (same rules). Scans the whole history — detail view only.
    static func besteSerie(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String) -> Int {
        guard let start = start(habit, werte: werte, ziel: ziel, heute: heute) else { return 0 }
        let ende = einheit(habit, heute)
        var tag = start
        var lauf = 0
        var beste = 0
        while tag <= ende {
            if zaehlt(habit, tag) {
                if erfuellt(habit, werte: werte, ziel: ziel, einheit: tag) {
                    lauf += 1
                    beste = max(beste, lauf)
                } else if tag != ende {
                    lauf = 0
                }
            }
            tag = Datum.addTage(tag, schritt(habit))
        }
        return beste
    }

    /// Done due days of the last 30 (incl. today) against what was due, 0…1. "x pro Woche" is due
    /// x/7 per day. Today still open is left out instead of counting against.
    // ponytail: fixed 30-day window, a habit created last week starts low. Start at creation if that bugs.
    static func quote30(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String) -> Double {
        let tage = (0..<30).map { Datum.addTage(heute, -$0) }.filter { zaehlt(habit, $0) }
        let geschafft = tage.filter { erledigt(habit, wert: werte[$0] ?? 0, ziel: ziel) }.count
        let heuteOffen = tage.contains(heute) && !erledigt(habit, wert: werte[heute] ?? 0, ziel: ziel)
        let soll: Double
        if case .proWoche(let n) = habit.haeufigkeit {
            soll = Double(wochenziel(habit, ziel, n)) * 30 / 7
        } else {
            soll = Double(tage.count - (heuteOffen ? 1 : 0))
        }
        guard soll > 0 else { return 0 }
        return min(1, Double(geschafft) / soll)
    }

    /// Monday…Sunday of the running week.
    static func wochenTage(heute: String) -> [String] {
        let montag = Datum.montagDerWoche(heute)
        return (0..<7).map { Datum.addTage(montag, $0) }
    }

    static let wochentagKuerzel = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    /// "jeden Tag", "3 Tage/Woche", "Mo, Mi, Fr" (Spec 3.3).
    static func haeufigkeitText(_ habit: Habit, ziel: Int?) -> String {
        switch habit.haeufigkeit {
        case .taeglich:
            return "jeden Tag"
        case .proWoche(let n):
            let anzahl = wochenziel(habit, ziel, n)
            return anzahl == 1 ? "1 Tag/Woche" : "\(anzahl) Tage/Woche"
        case .tage(let tage):
            let sortiert = Set(tage).filter { (1...7).contains($0) }.sorted()
            if sortiert.count == 7 { return "jeden Tag" }
            return sortiert.map { wochentagKuerzel[$0 - 1] }.joined(separator: ", ")
        }
    }

    // MARK: - Intern

    private static func tagesziel(_ habit: Habit, _ ziel: Int?) -> Int {
        max(1, (habit.zaehlen ? ziel : nil) ?? habit.tagesziel ?? 1)
    }

    private static func wochenziel(_ habit: Habit, _ ziel: Int?, _ n: Int) -> Int {
        max(1, (habit.zaehlen ? nil : ziel) ?? n)
    }

    private static func wochenweise(_ habit: Habit) -> Bool {
        if case .proWoche = habit.haeufigkeit { return true }
        return false
    }

    /// The unit a streak counts in: the day itself, or the Monday of its week for "x pro Woche".
    private static func einheit(_ habit: Habit, _ tag: String) -> String {
        wochenweise(habit) ? Datum.montagDerWoche(tag) : tag
    }

    private static func schritt(_ habit: Habit) -> Int { wochenweise(habit) ? 7 : 1 }

    /// Fixed days: only due days take part.
    private static func zaehlt(_ habit: Habit, _ tag: String) -> Bool {
        if case .tage(let tage) = habit.haeufigkeit { return tage.contains(Datum.wochentag(tag)) }
        return true
    }

    private static func erfuellt(_ habit: Habit, werte: [String: Int], ziel: Int?, einheit: String) -> Bool {
        guard case .proWoche(let n) = habit.haeufigkeit else {
            return erledigt(habit, wert: werte[einheit] ?? 0, ziel: ziel)
        }
        let geschafft = (0..<7).filter { erledigt(habit, wert: werte[Datum.addTage(einheit, $0)] ?? 0, ziel: ziel) }.count
        return geschafft >= wochenziel(habit, ziel, n)
    }

    /// First unit with anything done — nothing before it can be part of a streak.
    private static func start(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String) -> String? {
        werte.filter { $0.key <= heute && erledigt(habit, wert: $0.value, ziel: ziel) }.keys.min().map { einheit(habit, $0) }
    }
}

// MARK: - Faltung (Z-35.1)

/// `habit.setzen {art, datum, wert}` — `art` is the habit id (`"gym"`, `"wasser"`, `"h-<uuid>"`).
struct HabitSetzenD: Codable, Sendable { var art: String; var datum: String; var wert: Int }

/// `habit.ausblenden {id, aus}`
struct HabitAusblendenD: Codable, Sendable { var id: String; var aus: Bool }

/// Pure fold of the four habit ops, so tests feed real `Op`s without `Raum`. Every slot follows
/// `HealthFaltung.gewinner` (highest `seq` wins, arrival order doesn't matter).
struct HabitFaltung: Sendable {
    /// `habit.setzen` per habit id, then person and day — the same per-day fold Gym and Wasser always
    /// had, so the 80 `fitx:<datum>` ops and old `{art:"gym"|"wasser"}` ops land exactly as before.
    private(set) var werte: [String: [Person: [String: TagesEintrag<Int>]]] = [:]
    /// Winning definition per id; its op's `von` is the creator.
    private var definitionen: [String: TagesEintrag<Habit>] = [:]
    /// Lowest `seq` seen per id = creation order for sorting (unconfirmed = last).
    private var angelegt: [String: Int] = [:]
    /// Hidden per id and person: `habit.ausblenden` hides only for whoever sent it, so nobody can
    /// take a shared habit (Gym with Ahmed's FitX days) away from the other one.
    private var ausblendungen: [String: [Person: TagesEintrag<Bool>]] = [:]

    mutating func anwenden(_ op: Op) {
        let gesendet = Datum.text(op.zeit)
        switch op.art {
        case "habit.setzen":
            guard let d = op.daten(HabitSetzenD.self) else { return }
            HealthFaltung.aufnehmen(&werte[d.art, default: [:]], TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: gesendet, wert: d.wert, id: op.id))
        case "habit.anlegen", "habit.aendern":
            // Gym and Wasser are built in: their definition never changes through ops.
            guard var habit = op.daten(Habit.self), !habit.istEingebaut else { return }
            habit.von = op.von.rawValue
            HealthFaltung.gewinner(&definitionen[habit.id], TagesEintrag(seq: op.seq, von: op.von, datum: gesendet, gesendetAm: gesendet, wert: habit, id: op.id))
            angelegt[habit.id] = min(angelegt[habit.id] ?? .max, op.seq ?? .max)
        case "habit.ausblenden":
            guard let d = op.daten(HabitAusblendenD.self) else { return }
            HealthFaltung.gewinner(&ausblendungen[d.id, default: [:]][op.von], TagesEintrag(seq: op.seq, von: op.von, datum: gesendet, gesendetAm: gesendet, wert: d.aus, id: op.id))
        default:
            break
        }
    }

    /// Every habit incl. Gym and Wasser; `ausgeblendet` as seen by `ich`.
    func habits(ich: Person) -> [String: Habit] {
        var alle = Dictionary(uniqueKeysWithValues: Habit.eingebaut.map { ($0.id, $0) })
        for (id, eintrag) in definitionen { alle[id] = eintrag.wert }
        return alle.mapValues { habit in
            var habit = habit
            habit.ausgeblendet = ausblendungen[habit.id]?[ich]?.wert ?? false
            return habit
        }
    }

    /// Without hidden ones, "ich" habits only for their creator. Gym, Wasser, then creation order.
    func sichtbar(fuer ich: Person) -> [Habit] {
        habits(ich: ich).values
            .filter { !Habit.nurHeute.contains($0.id) && !$0.ausgeblendet && ($0.fuer != "ich" || $0.von == ich.rawValue) }
            .sorted { rang($0) < rang($1) }
    }

    private func rang(_ habit: Habit) -> (Int, String) {
        let eingebaut = Habit.eingebaut.firstIndex { $0.id == habit.id }.map { $0 - Habit.eingebaut.count }
        return (eingebaut ?? angelegt[habit.id] ?? .max, habit.id)
    }
}
