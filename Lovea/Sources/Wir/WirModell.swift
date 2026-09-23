import Foundation
import Observation

struct DateIdee: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var text: String
}

/// Faltet die „Wir"-Ops (`schnittstellen.md`) in einen `Zustand`. `anwenden(_:)` ist eine reine,
/// statische Faltung ohne `Raum`, testbar wie `KalenderModell.anwenden`.
@MainActor @Observable
final class WirModell {
    static let shared = WirModell()

    private(set) var zustand = Zustand()
    private var faltung = SeqFaltung()

    /// Bundle-Vorrat aus `Kalender/Inhalt/dates.json` (40 Ideen der Web-App).
    nonisolated static let ideenVorrat: [DateIdee] = {
        guard let url = Inhalt.url(datei: "dates", typ: "json"),
              let data = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([DateIdee].self, from: data)
        else { return [] }
        return liste
    }()

    struct Zustand: Sendable {
        var antworten: [String: [Person: FrageAntwort]] = [:] // frageId -> Person -> Antwort
        var eigeneFragen: [EigeneFrage] = []
        var themen: [Thema] = []
        var liste: [ListenEintrag] = []
        var ideen: [Idee] = [] // per `idee.neu` dazugekommene, zusätzlich zum Bundle-Vorrat
        var gezogen: [String] = [] // Reihenfolge der `wuerfel.gezogen`-Ergebnisse (ideeId)
    }

    struct FrageAntwort: Sendable, Equatable { var text: String; var zeit: Date }
    struct EigeneFrage: Sendable, Equatable, Identifiable, Hashable { var id: String; var text: String; var von: Person; var zeit: Date }
    struct Thema: Sendable, Equatable, Identifiable, Hashable { var id: String; var text: String; var von: Person; var besprochen: String? }
    struct ListenEintrag: Sendable, Equatable, Identifiable, Hashable { var id: String; var text: String; var von: Person; var geschafft: Bool }
    struct Idee: Sendable, Equatable, Identifiable, Hashable { var id: String; var text: String; var von: Person }

    static let arten: Set<String> = ["frage.antwort", "frage.eigene", "thema.setzen", "liste.setzen", "liste.loeschen", "idee.neu", "wuerfel.gezogen"]

    private init() {
        Raum.shared.beobachtenStapel(Self.arten) { [weak self] ops in
            guard let self else { return }
            var faltung = self.faltung
            self.zustand = Self.einarbeiten(ops, faltung: &faltung, zustand: self.zustand)
            self.faltung = faltung
        }
    }

    nonisolated static func anwenden(_ ops: [Op]) -> Zustand {
        var z = Zustand()
        var gesehen: Set<String> = []
        for op in ops { Self.op(op, in: &z, angewendet: &gesehen) }
        return z
    }

    /// I-1: wie `KalenderModell.einarbeiten` — neu falten, sobald sich die `seq`-Reihenfolge
    /// verschiebt, damit auf beiden Handys die höhere `seq` gewinnt.
    nonisolated static func einarbeiten(_ batch: [Op], faltung: inout SeqFaltung, zustand: Zustand) -> Zustand {
        guard let neu = faltung.aufnehmen(batch) else { return anwenden(faltung.sortiert) }
        var z = zustand
        var gesehen: Set<String> = []
        for op in neu { Self.op(op, in: &z, angewendet: &gesehen) }
        return z
    }

    private nonisolated static func op(_ op: Op, in z: inout Zustand, angewendet: inout Set<String>) {
        guard angewendet.insert(op.id).inserted else { return }
        switch op.art {
        case "frage.antwort":
            if let d = op.daten(FrageAntwortD.self) { z.antworten[d.frageId, default: [:]][op.von] = FrageAntwort(text: d.text, zeit: op.zeit) }
        case "frage.eigene":
            if let d = op.daten(FrageEigeneD.self) {
                z.eigeneFragen.removeAll { $0.id == d.id }
                z.eigeneFragen.append(EigeneFrage(id: d.id, text: d.text, von: op.von, zeit: op.zeit))
            }
        case "thema.setzen":
            if let d = op.daten(ThemaD.self) {
                z.themen.removeAll { $0.id == d.id }
                z.themen.append(Thema(id: d.id, text: d.text, von: op.von, besprochen: d.besprochen))
            }
        case "liste.setzen":
            if let d = op.daten(ListeD.self) {
                z.liste.removeAll { $0.id == d.id }
                z.liste.append(ListenEintrag(id: d.id, text: d.text, von: op.von, geschafft: d.geschafft))
            }
        case "liste.loeschen":
            if let d = op.daten(MitId.self) { z.liste.removeAll { $0.id == d.id } }
        case "idee.neu":
            if let d = op.daten(IdeeD.self), !z.ideen.contains(where: { $0.id == d.id }) {
                z.ideen.append(Idee(id: d.id, text: d.text, von: op.von))
            }
        case "wuerfel.gezogen":
            if let d = op.daten(WuerfelD.self) { z.gezogen.append(d.ideeId) }
        default:
            break
        }
    }

    // MARK: - Frage des Tages

    var heute: Frage? { FrageDesTages.waehlen(vorrat: FrageDesTages.vorrat, tag: Datum.text(Date())) }

    func meineAntwort(_ frageId: String) -> String? { Raum.shared.ich.flatMap { zustand.antworten[frageId]?[$0]?.text } }

    /// Verdeckt, bis beide geantwortet haben (Spec 8.3).
    func partnerAntwort(_ frageId: String) -> String? {
        guard let ich = Raum.shared.ich, zustand.antworten[frageId]?[ich] != nil else { return nil }
        return zustand.antworten[frageId]?[ich.partner]?.text
    }

    func antworten(_ frageId: String, text: String) {
        Raum.shared.senden("frage.antwort", FrageAntwortD(frageId: frageId, text: text))
    }

    func eigeneFrageStellen(_ text: String) {
        Raum.shared.senden("frage.eigene", FrageEigeneD(id: UUID().uuidString, text: text, kategorie: nil))
    }

    struct FruehereFrage: Identifiable { var frage: Frage; var meine: String?; var deine: String?; var id: String { frage.id } }

    /// Frühere, bereits beantwortete Fragen (aus dem Vorrat, neueste zuerst).
    var fruehereFragen: [FruehereFrage] {
        let heuteId = heute?.id
        let vorratNachId = Dictionary(uniqueKeysWithValues: FrageDesTages.vorrat.map { ($0.id, $0) })
        return zustand.antworten.keys
            .filter { $0 != heuteId }
            .compactMap { vorratNachId[$0] }
            .sorted { (zustand.antworten[$0.id]?.values.map(\.zeit).max() ?? .distantPast) > (zustand.antworten[$1.id]?.values.map(\.zeit).max() ?? .distantPast) }
            .map { FruehereFrage(frage: $0, meine: meineAntwort($0.id), deine: partnerAntwort($0.id)) }
    }

    // MARK: - Unsere Liste und Würfel (Z-10.5)

    struct WuerfelEintrag: Identifiable, Hashable { var id: String; var text: String }

    func listeHinzufuegen(_ text: String) {
        Raum.shared.senden("liste.setzen", ListeD(id: UUID().uuidString, text: text, geschafft: false))
    }

    func listeAbhaken(_ eintrag: ListenEintrag, geschafft: Bool) {
        Raum.shared.senden("liste.setzen", ListeD(id: eintrag.id, text: eintrag.text, geschafft: geschafft))
    }

    /// Offene Listen-Einträge und Ideen (Bundle + eigene), ohne die letzten 5 gezogenen.
    var wuerfelPool: [WuerfelEintrag] {
        let offen = zustand.liste.filter { !$0.geschafft }.map { WuerfelEintrag(id: $0.id, text: $0.text) }
        let ideen = Self.ideenVorrat.map { WuerfelEintrag(id: $0.id, text: $0.text) } + zustand.ideen.map { WuerfelEintrag(id: $0.id, text: $0.text) }
        let letzte5 = Set(zustand.gezogen.suffix(5))
        let alle = offen + ideen
        let frisch = alle.filter { !letzte5.contains($0.id) }
        return frisch.isEmpty ? alle : frisch // ist alles kürzlich dran gewesen, trotzdem etwas zeigen
    }

    @discardableResult
    func wuerfeln() -> WuerfelEintrag? {
        guard let treffer = wuerfelPool.randomElement() else { return nil }
        Raum.shared.senden("wuerfel.gezogen", WuerfelD(ideeId: treffer.id))
        return treffer
    }

    /// „Machen wir": trägt den gewürfelten/gewählten Text als Treffen ein.
    func machenWir(text: String, datum: String, uhrzeit: String?) {
        Raum.shared.senden("treffen.setzen", TreffenSendeD(datum: datum, uhrzeit: uhrzeit, wasMachenWir: text))
    }
}

// MARK: - Op-Körper (`d`), 1:1 aus schnittstellen.md

private struct MitId: Codable { var id: String }
private struct FrageAntwortD: Codable { var frageId: String; var text: String }
private struct FrageEigeneD: Codable { var id: String; var text: String; var kategorie: String? }
private struct ThemaD: Codable { var id: String; var text: String; var besprochen: String? }
private struct ListeD: Codable { var id: String; var text: String; var geschafft: Bool }
private struct IdeeD: Codable { var id: String; var text: String }
private struct WuerfelD: Codable { var ideeId: String }
private struct TreffenSendeD: Codable { var datum: String; var uhrzeit: String?; var wasMachenWir: String? }
