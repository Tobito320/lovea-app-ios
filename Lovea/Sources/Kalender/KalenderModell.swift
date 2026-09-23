import Foundation
import Observation

/// Faltet alle Kalender- und Tag-Ops (`schnittstellen.md`) in einen `Zustand`. Registriert sich
/// mit `Raum.shared.beobachten` und legt beim allerersten Start eigene Startmuster an (Z-9.4).
/// `anwenden(_:)` ist eine reine, statische Faltung ohne `Raum` — so testet Z-10.1 den
/// "vorherige Fassung"-Fall ohne Sync-Infrastruktur.
@MainActor @Observable
final class KalenderModell {
    static let shared = KalenderModell()

    private(set) var zustand = Zustand()
    /// Rohe Ops, nur für reine Funktionen, die ihre eigene Faltung mitbringen (`Puenktlich.monatsKrone`).
    private(set) var alleOps: [Op] = []
    private var angewendet: Set<String> = []

    struct Zustand: Sendable {
        var daten = KalenderDaten()
        var treffenText: [String: TreffenEintrag] = [:]
        var checklisten: [String: [ChecklistEintrag]] = [:]
        var notizen: [String: [Person: String]] = [:]
        var stimmungen: [String: [Person: Stimmung]] = [:]
        /// `datum -> Bewerter(von) -> Wertung`. Der Bewerter bewertet immer seinen Partner.
        var puenktlich: [String: [Person: String]] = [:]
        var jahrestag: String?
    }

    struct TreffenEintrag: Sendable, Equatable {
        var von: Person
        var text: String?
        var uhrzeit: String?
        var zeit: Date
        var vorherige: Vorherige?

        struct Vorherige: Sendable, Equatable { var von: Person; var text: String; var zeit: Date }
    }

    struct ChecklistEintrag: Sendable, Equatable, Identifiable, Hashable {
        var id: String
        var text: String
        var erledigt: Bool
    }

    struct Stimmung: Sendable, Equatable {
        var stimmung: String // "gut" | "mittel" | "schlecht"
        var brauche: String? // "naehe" | "worte" | "ruhe"
        var satz: String?
    }

    static let arten: Set<String> = [
        "muster.setzen", "muster.loeschen", "ausnahme.setzen", "termin.setzen", "termin.loeschen",
        "treffen.setzen", "treffen.loeschen", "notiz.setzen", "checkliste.setzen", "checkliste.loeschen",
        "stimmung.setzen", "puenktlich.setzen", "jahrestag.setzen",
    ]

    private init() {
        Raum.shared.beobachtenStapel(Self.arten) { [weak self] ops in
            guard let self else { return }
            // `angewendet` markiert schon verarbeitete IDs (Faltung ist idempotent) — hier auch
            // genutzt, damit `alleOps` (für `Puenktlich.monatsKrone`) keine Op doppelt zählt.
            for op in ops {
                guard !self.angewendet.contains(op.id) else { continue }
                self.alleOps.append(op)
                self.zustand = Self.op(op, in: self.zustand, angewendet: &self.angewendet)
            }
        }
        ersterStartMusterFallsNoetig()
    }

    // MARK: - Faltung (testbar ohne Raum)
    // `nonisolated`, weil diese reinen Funktionen nur mit Werttypen arbeiten (kein `Raum`-Zugriff)
    // und Tests sie sonst als main-actor-isoliert (geerbt von der `@MainActor`-Klasse) nicht ohne
    // Weiteres synchron aufrufen könnten.

    nonisolated static func anwenden(_ ops: [Op]) -> Zustand {
        var z = Zustand()
        var gesehen: Set<String> = []
        for op in ops { z = Self.op(op, in: z, angewendet: &gesehen) }
        return z
    }

    private nonisolated static func op(_ op: Op, in zustand: Zustand, angewendet: inout Set<String>) -> Zustand {
        guard angewendet.insert(op.id).inserted else { return zustand } // idempotent bei doppelter Zustellung
        var z = zustand
        switch op.art {
        case "muster.setzen":
            if let m = op.daten(Muster.self) {
                z.daten.muster.removeAll { $0.id == m.id }
                z.daten.muster.append(m)
            }
        case "muster.loeschen":
            if let d = op.daten(MitId.self) { z.daten.muster.removeAll { $0.id == d.id } }
        case "ausnahme.setzen":
            if let a = op.daten(Ausnahme.self) {
                z.daten.ausnahmen.removeAll { $0.person == a.person && $0.datum == a.datum && $0.musterId == a.musterId }
                z.daten.ausnahmen.append(a)
            }
        case "termin.setzen":
            if let t = op.daten(Termin.self) {
                z.daten.termine.removeAll { $0.id == t.id }
                z.daten.termine.append(t)
            }
        case "termin.loeschen":
            if let d = op.daten(MitId.self) { z.daten.termine.removeAll { $0.id == d.id } }
        case "treffen.setzen":
            if let d = op.daten(TreffenD.self) { z = treffenSetzen(op.von, op.zeit, d, in: z) }
        case "treffen.loeschen":
            if let d = op.daten(MitDatum.self) {
                z.daten.treffen.removeAll { $0.datum == d.datum }
                z.treffenText[d.datum] = nil
            }
        case "notiz.setzen":
            if let d = op.daten(NotizD.self) { z.notizen[d.datum, default: [:]][op.von] = d.text }
        case "checkliste.setzen":
            if let d = op.daten(ChecklisteD.self) {
                var liste = z.checklisten[d.datum] ?? []
                liste.removeAll { $0.id == d.id }
                liste.append(ChecklistEintrag(id: d.id, text: d.text, erledigt: d.erledigt))
                z.checklisten[d.datum] = liste
            }
        case "checkliste.loeschen":
            if let d = op.daten(ChecklisteLoeschenD.self) { z.checklisten[d.datum]?.removeAll { $0.id == d.id } }
        case "stimmung.setzen":
            if let d = op.daten(StimmungD.self) {
                z.stimmungen[d.datum, default: [:]][op.von] = Stimmung(stimmung: d.stimmung, brauche: d.brauche, satz: d.satz)
            }
        case "puenktlich.setzen":
            if let d = op.daten(PuenktlichEintrag.self) { z.puenktlich[d.datum, default: [:]][op.von] = d.wert }
        case "jahrestag.setzen":
            if let d = op.daten(MitDatum.self) { z.jahrestag = d.datum }
        default:
            break
        }
        return z
    }

    /// Review-Fokus 2: Bei unterschiedlichem `wasMachenWir` bleibt die vorige Fassung abrufbar.
    /// Ops werden in Zustellreihenfolge angewendet (für bestätigte Ops = Reihenfolge nach `seq`),
    /// die zuletzt angewendete gewinnt.
    private nonisolated static func treffenSetzen(_ von: Person, _ zeit: Date, _ d: TreffenD, in zustand: Zustand) -> Zustand {
        var z = zustand
        let vorher = z.treffenText[d.datum]
        var vorherige = vorher?.vorherige
        if let alt = vorher, alt.text != d.wasMachenWir {
            vorherige = TreffenEintrag.Vorherige(von: alt.von, text: alt.text ?? "", zeit: alt.zeit)
        }
        let neu = TreffenEintrag(von: von, text: d.wasMachenWir, uhrzeit: d.uhrzeit ?? vorher?.uhrzeit, zeit: zeit, vorherige: vorherige)
        z.treffenText[d.datum] = neu
        z.daten.treffen.removeAll { $0.datum == d.datum }
        z.daten.treffen.append(Treffen(datum: d.datum, uhrzeit: neu.uhrzeit, wasMachenWir: neu.text))
        return z
    }

    // MARK: - Z-9.4 Startmuster

    /// Ohne Uhrzeiten, „ab“ 2026-09-21 (Woche A). Annika: Schule Mo–Fr. Ahmed: vier Muster
    /// (Schule Di+Mi Woche A, Mi Woche B, Arbeit Mo/Do/Fr A, Mo/Di/Do/Fr B) — 1:1 wie die
    /// bestehenden Wochenplan-Tests. Feste IDs machen ein doppeltes Anlegen ungefährlich (Fold
    /// überschreibt dasselbe Muster einfach noch einmal mit denselben Werten).
    nonisolated static func standardMuster(fuer person: Person) -> [Muster] {
        let ab = "2026-09-21"
        switch person {
        case .annika:
            return [
                Muster(id: "start-annika-schule", person: "annika", typ: "schule", titel: "Schule", wochentage: [1, 2, 3, 4, 5], wochen: "alle", start: nil, ende: nil, ab: ab),
            ]
        case .ahmed:
            return [
                Muster(id: "start-ahmed-schule-a", person: "ahmed", typ: "schule", titel: "Schule", wochentage: [2, 3], wochen: "A", start: nil, ende: nil, ab: ab),
                Muster(id: "start-ahmed-schule-b", person: "ahmed", typ: "schule", titel: "Schule", wochentage: [3], wochen: "B", start: nil, ende: nil, ab: ab),
                Muster(id: "start-ahmed-arbeit-a", person: "ahmed", typ: "arbeit", titel: "Arbeit", wochentage: [1, 4, 5], wochen: "A", start: nil, ende: nil, ab: ab),
                Muster(id: "start-ahmed-arbeit-b", person: "ahmed", typ: "arbeit", titel: "Arbeit", wochentage: [1, 2, 4, 5], wochen: "B", start: nil, ende: nil, ab: ab),
            ]
        }
    }

    // ponytail: Raum meldet nirgends "Anfangsseite geladen" — `leer()` wartet nur auf bereits
    // eingereihte Arbeit, nicht auf den Netzwerk-Umlauf selbst. Eine kurze Gnadenfrist deckt den
    // normalen Fall ab; feste IDs oben machen ein zu frühes, doppeltes Senden harmlos. Aufwertung:
    // Raum könnte ein explizites "erste Seite da"-Signal bekommen.
    private func ersterStartMusterFallsNoetig() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await Raum.shared.leer()
            try? await Task.sleep(for: .seconds(2))
            guard let ich = Raum.shared.ich else { return }
            guard !self.zustand.daten.muster.contains(where: { $0.person == ich.rawValue }) else { return }
            for muster in Self.standardMuster(fuer: ich) { Raum.shared.senden("muster.setzen", muster) }
        }
    }

    // MARK: - Home-Hilfen

    /// Nächster Treffen-Tag ab heute (heute eingeschlossen), für den Countdown auf Home.
    var naechstesTreffen: Treffen? {
        let heute = Datum.text(Date())
        return zustand.daten.treffen.filter { $0.datum >= heute }.sorted { $0.datum < $1.datum }.first
    }

    /// Ein noch nicht bewerteter Treffen-Tag der letzten 7 Tage, für die Pünktlich-Karte.
    func puenktlichKandidat() -> (datum: String, ueber: Person)? {
        guard let ich = Raum.shared.ich else { return nil }
        let heute = Datum.text(Date())
        let kandidaten = zustand.daten.treffen.map(\.datum).filter { $0 < heute && Datum.tageZwischen($0, heute) <= 7 }
        guard let tag = kandidaten.sorted(by: >).first(where: { zustand.puenktlich[$0]?[ich] == nil }) else { return nil }
        return (tag, ich.partner)
    }
}

// MARK: - Op-Körper (`d`), 1:1 aus schnittstellen.md

private struct MitId: Codable { var id: String }
private struct MitDatum: Codable { var datum: String }
private struct TreffenD: Codable { var datum: String; var uhrzeit: String?; var wasMachenWir: String? }
private struct NotizD: Codable { var datum: String; var text: String }
private struct ChecklisteD: Codable { var datum: String; var id: String; var text: String; var erledigt: Bool }
private struct ChecklisteLoeschenD: Codable { var datum: String; var id: String }
private struct StimmungD: Codable { var datum: String; var stimmung: String; var brauche: String?; var satz: String? }
