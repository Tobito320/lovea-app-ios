import CoreLocation
import Foundation

/// One set. `failure` = until failure; `wdh` stays the target shown with it.
struct PlanSatz: Codable, Equatable, Sendable {
    var wdh: Int
    var kg: Double?
    var failure: Bool
    /// "w" Aufwärmen, "d" Dropsatz, nil normal. Versagen bleibt `failure`, alte Builds lesen es so.
    var typ: String? = nil
    var rpe: Double? = nil
    /// Nur im laufenden Training (`gym.uebung` mit status "satz"): abgehakt, Dauer des Satzes und
    /// die Pause danach in Sekunden. Alles optional: alte Ops und Pläne haben die Felder nicht.
    var ok: Bool? = nil
    var sek: Double? = nil
    var pause: Double? = nil

    /// "W", "D", "F" statt der Satznummer; nil für einen normalen Satz.
    var kuerzel: String? { typ == "w" ? "W" : typ == "d" ? "D" : failure ? "F" : nil }
    /// Aufwärmsätze zählen nicht für Volumen, Rekorde und "Sätze diese Woche".
    var zaehlt: Bool { ok == true && typ != "w" }
    /// Ohne Haken und Zeiten, so wie der Satz im Plan steht.
    var alsPlan: PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: failure, typ: typ) }

    /// "" normal, "w", "d", "f".
    mutating func setzeTyp(_ t: String) {
        typ = t == "w" || t == "d" ? t : nil
        failure = t == "f"
    }
}

/// One exercise of a training day. `uebung` is a catalog id, or `eigen` with `name` set.
/// Cardio (treadmill, stairs …) uses `minuten` instead of sets.
struct PlanUebung: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var uebung: String
    var name: String?
    var saetze: [PlanSatz]
    var minuten: Int?
    /// Bleibt an der Übung und steht beim nächsten Training wieder da ("Sitz auf Stufe 4").
    var notiz: String? = nil
    /// Pausenzeit in Sekunden; nil = `WorkoutLogik.standardPause`, 0 = ohne Ziel.
    var pause: Int? = nil

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

/// One person's plan, sent whole as `gym.plan` (newest wins). A weekday is a training day, a rest
/// day (`ruhetage`) or still open (`RuhetagLogik`).
struct TrainingsPlan: Codable, Equatable, Sendable {
    var tage: [TrainingsTag]
    /// Weekdays marked as rest days, 1 = Mo … 7 = So. Optional: plans from the first build have none.
    var ruhetage: [Int]? = nil
    static let leer = TrainingsPlan(tage: [])
}

/// Farbe je Trainingstag (Ahmed, 27.09.: jeder Tag anders). Feste Tage der Reihe nach aus der
/// Palette, flexible Tage (ohne Wochentag, an jedem Tag trainierbar) immer Lila.
enum TagFarbe {
    static let anzahl = 5
    static let flexibel = anzahl

    /// Index in die Palette: 0..<anzahl für feste Tage, `flexibel` für Tage ohne Wochentag.
    static func index(_ tag: TrainingsTag, in plan: TrainingsPlan) -> Int {
        guard !tag.wochentage.isEmpty else { return flexibel }
        let feste = plan.tage.filter { !$0.wochentage.isEmpty }
        return (feste.firstIndex { $0.id == tag.id } ?? 0) % anzahl
    }
}

/// Body of `gym.checkin` (`tag`, `start`), `gym.uebung` (`plan` = PlanUebung.id, `uebung` = catalog id,
/// `status` "start" | "fertig" | "offen", `saetze` on "fertig"), `gym.checkout` (`ende`) and
/// `gym.loeschen`. Sending check-in or checkout again for the same session corrects its times.
/// Wie Hevy: status "satz" trägt den ganzen Stand der Satzzeilen einer Übung (neuester gilt, bei
/// jedem Haken gesendet), "weg" nimmt eine im Training dazugekommene Übung wieder heraus. `name`
/// gehört zu einer eigenen Übung, die nicht im Plantag steht.
struct GymD: Codable, Equatable, Sendable {
    var session: String
    var tag: String? = nil
    var start: Date? = nil
    var ende: Date? = nil
    var plan: String? = nil
    var uebung: String? = nil
    var status: String? = nil
    var saetze: [PlanSatz]? = nil
    var name: String? = nil
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
    /// Die gezählten Sätze (abgehakt, ohne Aufwärmen). Körper, Verlauf und Hinweise rechnen damit.
    var saetze: [PlanSatz]?
    /// Alle Satzzeilen aus status "satz", auch offene und Aufwärmsätze; nil bei alten Einheiten.
    var stand: [PlanSatz]? = nil
    var name: String? = nil

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

    /// Mit Satzzeilen (wie Hevy) erst, wenn alle abgehakt sind; alte Einheiten über `fertig`.
    func erledigt(_ plan: String) -> Bool {
        laeufe.contains { l in
            guard l.plan == plan else { return false }
            if let stand = l.stand { return !stand.isEmpty && stand.allSatisfy { $0.ok == true } }
            return l.fertig
        }
    }

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
        // Checkout mit status "wieder" = Auschecken rückgängig, die Einheit läuft weiter.
        let ende = liste.last(where: { $0.art == "gym.checkout" && ($0.d.ende != nil || $0.d.status == "wieder") })?.d.ende
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
            case "satz":
                let stand = e.d.saetze ?? []
                let gezaehlt = stand.filter(\.zaehlt)
                let i: Int
                if let da = s.laeufe.lastIndex(where: { $0.plan == plan }) {
                    i = da
                } else {
                    s.laeufe.append(UebungsLauf(plan: plan, uebung: e.d.uebung ?? "", start: e.zeit, ende: nil, fertig: false, saetze: nil, name: e.d.name))
                    i = s.laeufe.count - 1
                }
                // Nur eine Übung läuft: alle anderen offenen enden hier (die Figur zeigt `aktiv`).
                for j in s.laeufe.indices where j != i && s.laeufe[j].start != nil && s.laeufe[j].ende == nil { s.laeufe[j].ende = e.zeit }
                s.laeufe[i].stand = stand
                s.laeufe[i].saetze = gezaehlt.isEmpty ? nil : gezaehlt
                s.laeufe[i].fertig = !gezaehlt.isEmpty
                if s.laeufe[i].start == nil { s.laeufe[i].start = e.zeit }
                s.laeufe[i].ende = !stand.isEmpty && stand.allSatisfy({ $0.ok == true }) ? e.zeit : nil
            case "weg":
                s.laeufe.removeAll { $0.plan == plan }
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
    /// Übungen in einen anderen Tag kopieren (Ahmed, 27.09.: Muskeln 2× pro Woche): neue ids, Sätze
    /// und Gewichte wahlweise mit, sonst frisch wie beim Hinzufügen (3 × 10, Cardio 20 min).
    static func kopien(_ uebungen: [PlanUebung], mitSaetzen: Bool) -> [PlanUebung] {
        uebungen.map { u in
            var neu = u
            neu.id = UUID().uuidString
            if !mitSaetzen {
                neu.saetze = u.istCardio ? [] : Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: 3)
                neu.minuten = u.istCardio ? 20 : nil
            }
            return neu
        }
    }

    static func tagSetzen(_ plan: TrainingsPlan, _ tag: TrainingsTag) -> TrainingsPlan {
        var p = plan
        for i in p.tage.indices where p.tage[i].id != tag.id {
            p.tage[i].wochentage.removeAll { tag.wochentage.contains($0) }
        }
        p.ruhetage = p.ruhetage.map { ruhe in ruhe.filter { !tag.wochentage.contains($0) } }
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

    /// Eine Plan-Übung ändern (Notiz, Pausenzeit), egal in welchem Tag sie steht.
    static func aendern(_ plan: TrainingsPlan, planUebung: String, _ f: (inout PlanUebung) -> Void) -> TrainingsPlan {
        var p = plan
        for t in p.tage.indices {
            for u in p.tage[t].uebungen.indices where p.tage[t].uebungen[u].id == planUebung { f(&p.tage[t].uebungen[u]) }
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
