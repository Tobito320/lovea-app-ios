import Foundation
import Observation

// Intervallfasten wie YAZIO Pro (Ahmed, 27.09.): eigenes Modell mit eigener Op-Art `fasten.eintrag`
// (ein Fastenfenster) und `fasten.plan` (aktuelle Planwahl). Getrennt von der alten `fasten.setzen`
// in ErnaehrungModell/Ernaehrung.swift, die unangetastet bleibt.
// Hier Typen, Faltung, reine Logik und das Modell; die Oberfläche liegt in FastenView.swift.

// MARK: - Typen

/// Ein Fastenfenster. `ende == nil` heißt: läuft noch. `plan` speichert den Plan zum Start, damit ein
/// späterer Planwechsel alte, schon beendete Fenster nicht rückwirkend ändert. Op `fasten.eintrag`,
/// neueste gewinnt je `id`, Löschen über `geloescht`.
struct FastenEintrag: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var start: Date
    var ende: Date?
    var plan: String
    var geloescht: Bool?
}

/// Op `fasten.plan`: nur die aktuelle Auswahl, pro Person, neueste gewinnt.
struct FastenPlanD: Codable, Equatable, Sendable {
    var plan: String
}

/// YAZIO-Pläne. Die Stunden-Pläne fasten X von 24 Stunden. Die Tagespläne (5:2, 6:1, 1:1) sind kein
/// Stundenfenster, zählen hier aber wie gewünscht als 24-Stunden-Fastentag.
enum FastenPlan: String, CaseIterable, Identifiable, Codable, Sendable {
    case zwoelf = "12:12"
    case vierzehn = "14:10"
    case sechzehn = "16:8"
    case achtzehn = "18:6"
    case zwanzig = "20:4"
    case omad = "23:1"
    case sechsunddreissig = "36h"
    case fuenfZuZwei = "5:2"
    case sechsZuEins = "6:1"
    case jedenZweitenTag = "1:1"

    var id: String { rawValue }

    static let standard: FastenPlan = .sechzehn

    var name: String {
        switch self {
        case .omad: "23:1 (OMAD)"
        case .sechsunddreissig: "36 Stunden"
        case .jedenZweitenTag: "1:1"
        default: rawValue
        }
    }

    var beschreibung: String {
        switch self {
        case .zwoelf: "12 Stunden fasten, 12 Stunden essen. Leichter Einstieg."
        case .vierzehn: "14 Stunden fasten, 10 Stunden essen."
        case .sechzehn: "16 Stunden fasten, 8 Stunden essen. Der bekannteste Plan."
        case .achtzehn: "18 Stunden fasten, 6 Stunden essen."
        case .zwanzig: "20 Stunden fasten, 4 Stunden essen."
        case .omad: "23 Stunden fasten, eine Mahlzeit am Tag."
        case .sechsunddreissig: "36 Stunden am Stück fasten, z. B. vom Abendessen bis zum übernächsten Frühstück."
        case .fuenfZuZwei: "An 2 Tagen pro Woche höchstens 500 kcal (Frau) bzw. 600 kcal (Mann), an den restlichen 5 Tagen normal essen."
        case .sechsZuEins: "An 1 Tag pro Woche höchstens 500 kcal (Frau) bzw. 600 kcal (Mann), an den restlichen 6 Tagen normal essen."
        case .jedenZweitenTag: "Jeden zweiten Tag fasten oder stark reduziert essen."
        }
    }

    /// Fastenstunden fürs Ziel. Die Tagespläne zählen einen Fastentag als 24 Stunden.
    var stunden: Int {
        switch self {
        case .zwoelf: 12
        case .vierzehn: 14
        case .sechzehn: 16
        case .achtzehn: 18
        case .zwanzig: 20
        case .omad: 23
        case .sechsunddreissig: 36
        case .fuenfZuZwei, .sechsZuEins, .jedenZweitenTag: 24
        }
    }

    /// Tagesplan (5:2, 6:1, 1:1): kein Stundenfenster, sondern ein reduzierter Kalorientag.
    var istTagesplan: Bool { self == .fuenfZuZwei || self == .sechsZuEins || self == .jedenZweitenTag }
}

// MARK: - Modell

@MainActor @Observable
final class FastenModell {
    static let shared = FastenModell()
    private var faltung = FastenFaltung()

    private init() {
        Raum.shared.beobachten(FastenFaltung.arten) { [weak self] op in self?.faltung.anwenden(op) }
    }

    var ich: Person { Raum.shared.ich ?? .ahmed }

    func eintraege(_ p: Person) -> [FastenEintrag] { faltung.eintraege(p) }
    func laufend(_ p: Person) -> FastenEintrag? { faltung.laufend(p) }
    func plan(_ p: Person) -> FastenPlan { faltung.plan(p) }

    func planSetzen(_ plan: FastenPlan) { Raum.shared.senden("fasten.plan", FastenPlanD(plan: plan.rawValue)) }

    func starten(_ start: Date = Date()) {
        let eintrag = FastenEintrag(id: UUID().uuidString, start: start, ende: nil, plan: plan(ich).rawValue, geloescht: nil)
        Raum.shared.senden("fasten.eintrag", eintrag)
    }

    func beenden(_ eintrag: FastenEintrag, ende: Date = Date()) {
        var neu = eintrag
        neu.ende = ende
        Raum.shared.senden("fasten.eintrag", neu)
    }

    /// Start (laufendes Fenster) oder Start und Ende (beendetes) nachträglich ändern.
    func aendern(_ eintrag: FastenEintrag) { Raum.shared.senden("fasten.eintrag", eintrag) }

    func loeschen(_ eintrag: FastenEintrag) {
        var weg = eintrag
        weg.geloescht = true
        Raum.shared.senden("fasten.eintrag", weg)
    }
}

// MARK: - Faltung

struct FastenFaltung: Sendable {
    static let arten: Set<String> = ["fasten.eintrag", "fasten.plan"]

    private struct Stand<T: Sendable>: Sendable {
        var zeit: Date
        var wert: T
    }

    private var fasten: [Person: [String: Stand<FastenEintrag>]] = [:]
    private var planStand: [Person: Stand<FastenPlanD>] = [:]

    mutating func anwenden(_ op: Op) {
        switch op.art {
        case "fasten.eintrag":
            guard let e = op.daten(FastenEintrag.self), (fasten[op.von]?[e.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            fasten[op.von, default: [:]][e.id] = Stand(zeit: op.zeit, wert: e)
        case "fasten.plan":
            guard let d = op.daten(FastenPlanD.self), (planStand[op.von]?.zeit ?? .distantPast) <= op.zeit else { return }
            planStand[op.von] = Stand(zeit: op.zeit, wert: d)
        default:
            break
        }
    }

    /// Alle nicht gelöschten Fenster einer Person, neuester Start zuerst.
    func eintraege(_ p: Person) -> [FastenEintrag] {
        (fasten[p] ?? [:]).values.filter { $0.wert.geloescht != true }.map(\.wert).sorted { $0.start > $1.start }
    }

    /// Läuft gerade eines? Das mit dem neuesten Start ohne `ende`.
    func laufend(_ p: Person) -> FastenEintrag? { eintraege(p).first { $0.ende == nil } }

    func plan(_ p: Person) -> FastenPlan { planStand[p].map { FastenPlan(rawValue: $0.wert.plan) ?? .standard } ?? .standard }
}

// MARK: - Logik

enum FastenLogik {
    static func zielSekunden(_ plan: FastenPlan) -> TimeInterval { Double(plan.stunden) * 3600 }

    static func geplantesEnde(start: Date, plan: FastenPlan) -> Date { start.addingTimeInterval(zielSekunden(plan)) }

    /// 0…1, deckelt am Ziel (der Ring bleibt danach voll, die Zeit läuft weiter).
    static func fortschritt(start: Date, plan: FastenPlan, jetzt: Date) -> Double {
        guard zielSekunden(plan) > 0 else { return 0 }
        return min(1, max(0, jetzt.timeIntervalSince(start) / zielSekunden(plan)))
    }

    static func vergangen(start: Date, jetzt: Date) -> TimeInterval { max(0, jetzt.timeIntervalSince(start)) }

    /// "05:12:07".
    static func zeitText(_ sekunden: TimeInterval) -> String {
        let gesamt = max(0, Int(sekunden))
        return String(format: "%02d:%02d:%02d", gesamt / 3600, (gesamt % 3600) / 60, gesamt % 60)
    }

    /// "27.09., 20:00" in Europe/Berlin.
    static func zeitpunktText(_ datum: Date) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
            .day(.twoDigits).month(.twoDigits).hour().minute()
        return datum.formatted(stil)
    }

    static func planVon(_ e: FastenEintrag) -> FastenPlan { FastenPlan(rawValue: e.plan) ?? .standard }

    /// Dauer eines beendeten Fensters in Stunden, nil solange es läuft.
    static func dauerStunden(_ e: FastenEintrag) -> Double? {
        guard let ende = e.ende else { return nil }
        return ende.timeIntervalSince(e.start) / 3600
    }

    static func geschafft(_ e: FastenEintrag) -> Bool {
        guard let dauer = dauerStunden(e) else { return false }
        return dauer * 3600 >= zielSekunden(planVon(e))
    }

    /// Nur beendete Fenster, Reihenfolge bleibt erhalten (neuester Start zuerst wie `eintraege(_:)`).
    static func beendete(_ eintraege: [FastenEintrag]) -> [FastenEintrag] { eintraege.filter { $0.ende != nil } }

    static func durchschnittStunden(_ beendete: [FastenEintrag]) -> Double {
        let dauern = beendete.compactMap(dauerStunden)
        guard !dauern.isEmpty else { return 0 }
        return dauern.reduce(0, +) / Double(dauern.count)
    }

    static func laengstesStunden(_ beendete: [FastenEintrag]) -> Double { beendete.compactMap(dauerStunden).max() ?? 0 }

    /// Tage in Folge mit geschafftem Ziel, rückwärts vom jüngsten Fastentag. Der Tag zählt nach dem
    /// Start des Fensters, ein Fasten über Mitternacht bricht die Reihe deshalb nicht künstlich, und
    /// bei mehreren Fenstern am selben Tag reicht eines mit erreichtem Ziel.
    static func serie(_ eintraege: [FastenEintrag]) -> Int {
        var geschafftJeTag: [String: Bool] = [:]
        for e in beendete(eintraege) {
            let tag = Datum.text(e.start)
            geschafftJeTag[tag] = (geschafftJeTag[tag] ?? false) || geschafft(e)
        }
        guard var tag = geschafftJeTag.keys.max() else { return 0 }
        var laenge = 0
        while geschafftJeTag[tag] == true {
            laenge += 1
            tag = Datum.addTage(tag, -1)
        }
        return laenge
    }
}
