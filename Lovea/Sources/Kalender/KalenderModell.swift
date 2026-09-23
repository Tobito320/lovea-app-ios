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
    private var faltung = SeqFaltung()
    /// Rohe Ops (Ankunftsreihenfolge), nur für reine Funktionen, die ihre eigene, reihenfolgefreie
    /// Faltung mitbringen (`Puenktlich.monatsKrone`).
    var alleOps: [Op] { faltung.ops }

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
        "muster.setzen", "muster.loeschen", "ausnahme.setzen", "ausnahme.loeschen", "termin.setzen", "termin.loeschen",
        "treffen.setzen", "treffen.loeschen", "notiz.setzen", "checkliste.setzen", "checkliste.loeschen",
        "stimmung.setzen", "puenktlich.setzen", "jahrestag.setzen",
    ]

    /// Z-42.1: fertige Monatsraster, neu erst, wenn sich Muster, Ausnahmen, Termine oder Treffen
    /// ändern (Notizen und Stimmung lassen sie stehen). Nicht beobachtet: das Füllen beim Rendern
    /// darf keine neue Render-Runde auslösen.
    @ObservationIgnored private var raster: (daten: KalenderDaten, monate: [String: MonatsRaster])?

    private init() {
        Raum.shared.beobachtenStapel(Self.arten) { [weak self] ops in
            guard let self else { return }
            var faltung = self.faltung
            self.zustand = Self.einarbeiten(ops, faltung: &faltung, zustand: self.zustand)
            self.faltung = faltung
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
        for op in ops { Self.op(op, in: &z, angewendet: &gesehen) }
        return z
    }

    /// I-1: Live-Weg des Modells. Neue Ops kommen oben drauf, außer die Reihenfolge nach `seq` hat
    /// sich verschoben (Echo einer eigenen Op, ältere Op nach neuerer). Dann wird neu gefaltet, so
    /// gewinnt auf beiden Handys die höhere `seq`.
    nonisolated static func einarbeiten(_ batch: [Op], faltung: inout SeqFaltung, zustand: Zustand) -> Zustand {
        guard let neu = faltung.aufnehmen(batch) else { return anwenden(faltung.sortiert) }
        var z = zustand
        var gesehen: Set<String> = []
        for op in neu { Self.op(op, in: &z, angewendet: &gesehen) }
        return z
    }

    private nonisolated static func op(_ op: Op, in z: inout Zustand, angewendet: inout Set<String>) {
        guard angewendet.insert(op.id).inserted else { return } // idempotent bei doppelter Zustellung
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
                z.daten.ausnahmen.removeAll(where: AusnahmeSchluessel(a).passt)
                z.daten.ausnahmen.append(a)
            }
        case "ausnahme.loeschen":
            if let schluessel = op.daten(AusnahmeSchluessel.self) { z.daten.ausnahmen.removeAll(where: schluessel.passt) }
        case "termin.setzen":
            if let t = op.daten(Termin.self) {
                z.daten.termine.removeAll { $0.id == t.id }
                z.daten.termine.append(t)
            }
        case "termin.loeschen":
            if let d = op.daten(MitId.self) { z.daten.termine.removeAll { $0.id == d.id } }
        case "treffen.setzen":
            if let d = op.daten(TreffenD.self) { treffenSetzen(op.von, op.zeit, d, in: &z) }
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
    }

    /// Review-Fokus 2: Bei unterschiedlichem `wasMachenWir` bleibt die vorige Fassung abrufbar.
    /// Die zuletzt angewendete Op gewinnt; `einarbeiten` sorgt dafür, dass das die mit der höheren
    /// `seq` ist (I-1).
    private nonisolated static func treffenSetzen(_ von: Person, _ zeit: Date, _ d: TreffenD, in z: inout Zustand) {
        let vorher = z.treffenText[d.datum]
        var vorherige = vorher?.vorherige
        // Z-42.2: nur ein Wechsel der Person hält die alte Fassung fest. Das Autosave schickt beim
        // Tippen mehrere Fassungen derselben Person, die sonst die Fassung des Partners verdrängen.
        // ponytail: dieselbe Person auf zwei Geräten zugleich (Annika iPhone + iPad) behält keine
        // vorige Fassung; Upgrade: das Gerät als Autor mitsenden.
        if let alt = vorher, alt.text != d.wasMachenWir, alt.von != von {
            vorherige = TreffenEintrag.Vorherige(von: alt.von, text: alt.text ?? "", zeit: alt.zeit)
        }
        // `uhrzeit` "" nimmt die Uhrzeit zurück; fehlt sie ganz („Machen wir"), bleibt die alte.
        let uhrzeit = d.uhrzeit == "" ? nil : (d.uhrzeit ?? vorher?.uhrzeit)
        let neu = TreffenEintrag(von: von, text: d.wasMachenWir, uhrzeit: uhrzeit, zeit: zeit, vorherige: vorherige)
        z.treffenText[d.datum] = neu
        z.daten.treffen.removeAll { $0.datum == d.datum }
        z.daten.treffen.append(Treffen(datum: d.datum, uhrzeit: neu.uhrzeit, wasMachenWir: neu.text))
    }

    // MARK: - Z-9.4 Startmuster

    /// Ohne Uhrzeiten, „ab“ 2026-09-21 (Woche A). Annika: Schule Mo–Fr. Ahmed: vier Muster
    /// (Schule Di+Mi Woche A, Mi Woche B, Arbeit Mo/Do/Fr A, Mo/Di/Do/Fr B) — 1:1 wie die
    /// bestehenden Wochenplan-Tests. Gesendet nur einmal pro Person, siehe `startmusterNoetig`.
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

    /// I-2: Startmuster gibt es nur einmal pro Person. Nicht, wenn sie schon einmal gesendet wurden
    /// (Flag), nicht, wenn im Log irgendein eigenes `muster.setzen`/`muster.loeschen` steht (auch
    /// "alle gelöscht" ist eine Entscheidung), und nicht, wenn schon Muster für mich da sind.
    nonisolated static func startmusterNoetig(ich: Person, ops: [Op], muster: [Muster], schonGesendet: Bool) -> Bool {
        guard !schonGesendet else { return false }
        let eigeneMusterOp = ops.contains { ($0.art == "muster.setzen" || $0.art == "muster.loeschen") && $0.von == ich }
        return !eigeneMusterOp && !muster.contains { $0.person == ich.rawValue }
    }

    /// Prüft erst nach dem ersten vollständigen Nachholen, sonst sieht ein neues Handy einen leeren Log.
    private func ersterStartMusterFallsNoetig() {
        Task { @MainActor [weak self] in
            guard Raum.shared.eingerichtet else { return }
            while !Raum.shared.nachgeholt {
                try? await Task.sleep(for: .seconds(1))
            }
            await Raum.shared.leer()
            guard let self, let ich = Raum.shared.ich else { return }
            let schluessel = "lovea.startmusterGesendet.\(ich.rawValue)"
            let noetig = Self.startmusterNoetig(
                ich: ich, ops: self.faltung.ops, muster: self.zustand.daten.muster,
                schonGesendet: UserDefaults.standard.bool(forKey: schluessel)
            )
            // Auch ohne Senden setzen: wer schon eigene Muster hat, bekommt nie wieder Startmuster.
            UserDefaults.standard.set(true, forKey: schluessel)
            guard noetig else { return }
            for muster in Self.standardMuster(fuer: ich) { Raum.shared.senden("muster.setzen", muster) }
        }
    }

    // MARK: - Home-Hilfen

    /// Z-42.1: das Raster des Monats, der am 1. `erster` (`yyyy-MM-dd`) beginnt, aus dem Speicher.
    func monatsRaster(_ erster: String) -> MonatsRaster {
        let daten = zustand.daten // gelesen, damit die Ansicht bei jeder Änderung neu rendert
        if raster?.daten != daten { raster = (daten, [:]) }
        if let fertig = raster?.monate[erster] { return fertig }
        let neu = MonatsRaster(erster: erster, daten: daten)
        raster?.monate[erster] = neu
        return neu
    }

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
private struct NotizD: Codable { var datum: String; var text: String }
private struct ChecklisteD: Codable { var datum: String; var id: String; var text: String; var erledigt: Bool }
private struct ChecklisteLoeschenD: Codable { var datum: String; var id: String }
private struct StimmungD: Codable { var datum: String; var stimmung: String; var brauche: String?; var satz: String? }
