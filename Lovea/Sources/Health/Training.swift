import CoreLocation
import Foundation

/// One set. `failure` = until failure; `wdh` stays the target shown with it.
struct PlanSatz: Codable, Equatable, Sendable {
    var wdh: Int
    var kg: Double?
    var failure: Bool
}

/// One exercise of a training day. `uebung` is a catalog id, or `eigen` with `name` set.
/// Cardio (treadmill, stairs …) uses `minuten` instead of sets.
struct PlanUebung: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var uebung: String
    var name: String?
    var saetze: [PlanSatz]
    var minuten: Int?

    static let eigen = "eigen"

    var katalog: Uebung? { UebungsKatalog.nachId[uebung] }
    var anzeigeName: String { name ?? katalog?.name ?? "Übung" }
    var istCardio: Bool { minuten != nil }

    /// New plan entry: 3 × 10 for strength, 20 min for cardio.
    static func neu(_ u: Uebung) -> PlanUebung {
        PlanUebung(
            id: UUID().uuidString, uebung: u.id, name: nil,
            saetze: u.istCardio ? [] : Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: 3),
            minuten: u.istCardio ? 20 : nil
        )
    }

    static func eigene(_ name: String) -> PlanUebung {
        PlanUebung(id: UUID().uuidString, uebung: eigen, name: name, saetze: Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: 3), minuten: nil)
    }
}

struct TrainingsTag: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    /// 1 = Mo … 7 = So (`Datum.wochentag`). A weekday belongs to at most one day.
    var wochentage: [Int]
    var uebungen: [PlanUebung]
}

/// One person's plan, sent whole as `gym.plan` (newest wins). Weekdays without a day are rest days.
struct TrainingsPlan: Codable, Equatable, Sendable {
    var tage: [TrainingsTag]
    static let leer = TrainingsPlan(tage: [])
}

/// Body of `gym.checkin` (`tag`, `start`), `gym.uebung` (`plan` = PlanUebung.id, `uebung` = catalog id,
/// `status` "start" | "fertig" | "offen", `saetze` on "fertig"), `gym.checkout` (`ende`) and
/// `gym.loeschen`. Sending check-in or checkout again for the same session corrects its times.
struct GymD: Codable, Equatable, Sendable {
    var session: String
    var tag: String? = nil
    var start: Date? = nil
    var ende: Date? = nil
    var plan: String? = nil
    var uebung: String? = nil
    var status: String? = nil
    var saetze: [PlanSatz]? = nil
}

struct GymEintrag: Equatable, Sendable {
    var art: String
    var zeit: Date
    var d: GymD
}

/// One try at an exercise: started (or ticked directly, `start == nil`), ended, done or not.
struct UebungsLauf: Equatable, Sendable {
    var plan: String
    var uebung: String
    var start: Date?
    var ende: Date?
    var fertig: Bool
    var saetze: [PlanSatz]?

    var dauer: TimeInterval? {
        guard let start, let ende else { return nil }
        return ende.timeIntervalSince(start)
    }
}

struct GymSession: Identifiable, Equatable, Sendable {
    var id: String
    var tag: String?
    var start: Date
    var ende: Date?
    var laeufe: [UebungsLauf]

    func erledigt(_ plan: String) -> Bool { laeufe.contains { $0.plan == plan && $0.fertig } }

    /// The exercise started and not ended yet (nil once checked out).
    var aktiv: UebungsLauf? {
        guard ende == nil else { return nil }
        return laeufe.last { $0.start != nil && $0.ende == nil }
    }
}

enum TrainingLogik {
    /// Longer counts as unusual: the checkout asks, an open session stops counting as "im Gym",
    /// and the card offers "Auschecken vergessen?".
    static let langNach: TimeInterval = 3 * 3600
    static let wochentagName = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    /// All sessions of one person, newest start first. Deleted ones and ones without check-in are left out.
    static func sessions(_ eintraege: [GymEintrag]) -> [GymSession] {
        var nachSession: [String: [GymEintrag]] = [:]
        for e in eintraege.sorted(by: { $0.zeit < $1.zeit }) { nachSession[e.d.session, default: []].append(e) }
        return nachSession.compactMap { session($0.key, $0.value) }.sorted { $0.start > $1.start }
    }

    private static func session(_ id: String, _ liste: [GymEintrag]) -> GymSession? {
        guard !liste.contains(where: { $0.art == "gym.loeschen" }),
              let checkin = liste.last(where: { $0.art == "gym.checkin" && $0.d.start != nil }),
              let start = checkin.d.start else { return nil }
        let ende = liste.last(where: { $0.art == "gym.checkout" && $0.d.ende != nil })?.d.ende
        var s = GymSession(id: id, tag: checkin.d.tag, start: start, ende: ende, laeufe: [])
        for e in liste where e.art == "gym.uebung" {
            guard let plan = e.d.plan else { continue }
            switch e.d.status {
            case "start":
                if let i = s.laeufe.lastIndex(where: { $0.start != nil && $0.ende == nil }) { s.laeufe[i].ende = e.zeit }
                s.laeufe.append(UebungsLauf(plan: plan, uebung: e.d.uebung ?? "", start: e.zeit, ende: nil, fertig: false, saetze: nil))
            case "fertig":
                if let i = s.laeufe.lastIndex(where: { $0.plan == plan && $0.start != nil && $0.ende == nil }) {
                    s.laeufe[i].ende = e.zeit
                    s.laeufe[i].fertig = true
                    s.laeufe[i].saetze = e.d.saetze
                } else {
                    s.laeufe.append(UebungsLauf(plan: plan, uebung: e.d.uebung ?? "", start: nil, ende: e.zeit, fertig: true, saetze: e.d.saetze))
                }
            case "offen":
                for i in s.laeufe.indices where s.laeufe[i].plan == plan { s.laeufe[i].fertig = false }
            default:
                break
            }
        }
        return s
    }

    /// Checked in, not out, and started less than `langNach` ago.
    static func laufend(_ s: GymSession, jetzt: Date) -> Bool {
        s.ende == nil && jetzt.timeIntervalSince(s.start) < langNach
    }

    /// An open session past `langNach`, reminded about on its day and the day after.
    static func vergessen(_ sessions: [GymSession], jetzt: Date) -> GymSession? {
        let heute = Datum.text(jetzt)
        return sessions.first { s in
            s.ende == nil && jetzt.timeIntervalSince(s.start) >= langNach && heute <= Datum.addTage(Datum.text(s.start), 1)
        }
    }

    static func zuLang(start: Date, ende: Date) -> Bool { ende.timeIntervalSince(start) > langNach }

    /// The day planned for `datum`, nil on a rest day.
    static func tag(_ plan: TrainingsPlan, datum: String) -> TrainingsTag? {
        let w = Datum.wochentag(datum)
        return plan.tage.first { $0.wochentage.contains(w) }
    }

    /// First exercise in plan order not done yet.
    static func naechste(_ tag: TrainingsTag, _ s: GymSession) -> PlanUebung? {
        tag.uebungen.first { !s.erledigt($0.id) }
    }

    /// The plan with `tag` added or replaced; its weekdays are taken away from every other day.
    static func tagSetzen(_ plan: TrainingsPlan, _ tag: TrainingsTag) -> TrainingsPlan {
        var p = plan
        for i in p.tage.indices where p.tage[i].id != tag.id {
            p.tage[i].wochentage.removeAll { tag.wochentage.contains($0) }
        }
        if let i = p.tage.firstIndex(where: { $0.id == tag.id }) { p.tage[i] = tag } else { p.tage.append(tag) }
        return p
    }

    /// The sets just done become the plan values of that exercise.
    static func uebernehmen(_ plan: TrainingsPlan, planUebung: String, saetze: [PlanSatz]) -> TrainingsPlan {
        var p = plan
        for t in p.tage.indices {
            for u in p.tage[t].uebungen.indices where p.tage[t].uebungen[u].id == planUebung {
                p.tage[t].uebungen[u].saetze = saetze
            }
        }
        return p
    }

    /// True only when `ich` saved a gym and a fresh fix (under 3 min) lies outside all of them (radius + 50 m).
    static func nichtImGym(orte: [Ort], ich: Person, lat: Double?, lon: Double?, alter: TimeInterval?) -> Bool {
        let gyms = orte.filter { $0.person == ich && $0.kategorie == "gym" }
        guard !gyms.isEmpty, let lat, let lon, let alter, alter < 180 else { return false }
        let hier = CLLocation(latitude: lat, longitude: lon)
        return gyms.allSatisfy { hier.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon)) > $0.radius + 50 }
    }

    /// Which `CardioEintrag.geraet` fits a finished cardio exercise; nil if the Cardio form doesn't fit.
    static func cardioGeraet(_ u: Uebung?) -> String? {
        guard let u, u.istCardio else { return nil }
        let en = u.en.lowercased()
        if en.contains("stair") || en.contains("stepmill") { return "stairmaster" }
        if en.contains("treadmill") || en.contains("run") || en.contains("walk") { return "laufband" }
        return nil
    }

    /// "1:05 h", "42 min".
    static func dauerText(_ sekunden: TimeInterval) -> String {
        let minuten = max(0, Int(sekunden / 60))
        return minuten >= 60 ? String(format: "%d:%02d h", minuten / 60, minuten % 60) : "\(minuten) min"
    }

    /// "62,5", "60".
    static func kgText(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))
    }

    /// "3 × 10 · 60 kg", "3 Sätze · 40–50 kg · F", "20 min".
    static func saetzeText(_ u: PlanUebung) -> String {
        if let minuten = u.minuten { return "\(minuten) min" }
        let s = u.saetze
        guard let erster = s.first else { return "keine Sätze" }
        var teile = [Set(s.map(\.wdh)).count == 1 ? "\(s.count) × \(erster.wdh)" : "\(s.count) Sätze"]
        let kg = s.compactMap(\.kg)
        if let leicht = kg.min(), let schwer = kg.max() {
            teile.append(leicht == schwer ? "\(kgText(leicht)) kg" : "\(kgText(leicht))–\(kgText(schwer)) kg")
        }
        if s.contains(where: \.failure) { teile.append("F") }
        return teile.joined(separator: " · ")
    }

    /// "Mo, Mi, Fr", "kein Tag".
    static func wochentageText(_ tage: [Int]) -> String {
        let gueltig = Set(tage).filter { (1...7).contains($0) }.sorted()
        return gueltig.isEmpty ? "kein Tag" : gueltig.map { HabitLogik.wochentagKuerzel[$0 - 1] }.joined(separator: ", ")
    }

    /// "heute" or "gestern" (the forgotten-checkout hint only lives that long).
    static func tagText(_ datum: Date, jetzt: Date) -> String {
        Datum.text(datum) == Datum.text(jetzt) ? "heute" : "gestern"
    }
}

/// Pure fold of all `gym.*` ops. Idempotent by op id (own ops arrive twice: unconfirmed, then
/// confirmed). Plans: the newest `zeit` per person wins.
struct TrainingFaltung: Sendable {
    static let arten: Set<String> = ["gym.plan", "gym.checkin", "gym.uebung", "gym.checkout", "gym.loeschen"]

    private(set) var plaene: [Person: TrainingsPlan] = [:]
    private var planZeit: [Person: Date] = [:]
    private var eintraege: [Person: [String: GymEintrag]] = [:]

    mutating func anwenden(_ op: Op) {
        if op.art == "gym.plan" {
            guard let plan = op.daten(TrainingsPlan.self), (planZeit[op.von] ?? .distantPast) <= op.zeit else { return }
            plaene[op.von] = plan
            planZeit[op.von] = op.zeit
        } else if Self.arten.contains(op.art), let d = op.daten(GymD.self) {
            eintraege[op.von, default: [:]][op.id] = GymEintrag(art: op.art, zeit: op.zeit, d: d)
        }
    }

    // ponytail: derived on every read (a few hundred events per person); cache per person if lists lag.
    func sessions(_ p: Person) -> [GymSession] {
        TrainingLogik.sessions(Array((eintraege[p] ?? [:]).values))
    }
}
