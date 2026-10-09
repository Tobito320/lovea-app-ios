import Foundation
import Observation

// Einkaufsliste wie YAZIO Pro, aber gemeinsam: Listen und Einträge gehören beiden Personen gleich,
// nicht nach `op.von` getrennt. Wer einen Eintrag angelegt hat, merkt sich `EinkaufFaltung` trotzdem,
// damit die Ansicht es klein anzeigen kann. Muster wie `Ernaehrung.swift` (Ops, Stand, neueste gewinnt).

// MARK: - Typen

/// Op `einkauf.liste`: eine Einkaufsliste, für beide sichtbar.
struct EinkaufListe: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var geloescht: Bool?
}

/// Op `einkauf.eintrag`: ein Eintrag in einer Liste, für beide sichtbar.
struct EinkaufEintrag: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var liste: String
    var text: String
    /// Freitext wie "250 g" oder "1 Portion (150 g)", nil ohne Menge.
    var menge: String?
    var erledigt: Bool
    /// Sortierschlüssel, aufsteigend. Neue Einträge bekommen den größten Wert der Liste + 1.
    var reihenfolge: Double
    var geloescht: Bool?
}

// MARK: - Faltung

struct EinkaufFaltung: Sendable {
    static let arten: Set<String> = ["einkauf.liste", "einkauf.eintrag"]

    private struct ListeStand: Sendable { var zeit: Date; var wert: EinkaufListe }
    private struct EintragStand: Sendable {
        var zeit: Date
        var wert: EinkaufEintrag
        /// Wer den Eintrag zuerst angelegt hat, bleibt auch bei späteren Änderungen von der anderen Person stehen.
        var erstelltVon: Person
        var erstelltZeit: Date
    }

    private var listenStaende: [String: ListeStand] = [:]
    private var eintragStaende: [String: EintragStand] = [:]

    mutating func anwenden(_ op: Op) {
        switch op.art {
        case "einkauf.liste":
            guard let l = op.daten(EinkaufListe.self), (listenStaende[l.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            listenStaende[l.id] = ListeStand(zeit: op.zeit, wert: l)
        case "einkauf.eintrag":
            guard let e = op.daten(EinkaufEintrag.self) else { return }
            if var bestehend = eintragStaende[e.id] {
                if op.zeit < bestehend.erstelltZeit { bestehend.erstelltVon = op.von; bestehend.erstelltZeit = op.zeit }
                if bestehend.zeit <= op.zeit { bestehend.zeit = op.zeit; bestehend.wert = e }
                eintragStaende[e.id] = bestehend
            } else {
                eintragStaende[e.id] = EintragStand(zeit: op.zeit, wert: e, erstelltVon: op.von, erstelltZeit: op.zeit)
            }
        default:
            break
        }
    }

    var listen: [EinkaufListe] {
        listenStaende.values.filter { $0.wert.geloescht != true }.map(\.wert)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func liste(_ id: String) -> EinkaufListe? { listenStaende[id]?.wert }

    func eintraege(_ liste: String) -> [EinkaufEintrag] {
        eintragStaende.values.filter { $0.wert.liste == liste && $0.wert.geloescht != true }.map(\.wert)
    }

    func erstelltVon(_ eintragId: String) -> Person? { eintragStaende[eintragId]?.erstelltVon }
}

// MARK: - Logik

enum EinkaufLogik {
    /// Offene zuerst, jede Gruppe nach `reihenfolge`; erledigte (durchgestrichen) rutschen ans Ende.
    static func sortiert(_ eintraege: [EinkaufEintrag]) -> [EinkaufEintrag] {
        eintraege.sorted { $0.erledigt != $1.erledigt ? !$0.erledigt : $0.reihenfolge < $1.reihenfolge }
    }

    /// Gleicher Text ohne Rücksicht auf Groß-/Kleinschreibung und Leerraum, für "nicht doppelt anlegen".
    static func gleicherText(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(b.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    /// Reihenfolge für einen neuen Eintrag: eins mehr als der größte Wert der Liste, 1 wenn leer.
    static func naechsteReihenfolge(_ eintraege: [EinkaufEintrag]) -> Double {
        (eintraege.map(\.reihenfolge).max() ?? 0) + 1
    }
}

// MARK: - Modell

/// Einkaufslisten beider Personen (`EinkaufFaltung`), analog zu `ErnaehrungModell`.
@MainActor @Observable
final class EinkaufModell {
    static let shared = EinkaufModell()
    private var faltung = EinkaufFaltung()

    private init() {
        Raum.shared.beobachten(EinkaufFaltung.arten) { [weak self] op in self?.faltung.anwenden(op) }
    }

    var ich: Person { Raum.shared.ich ?? .ahmed }

    // MARK: Lesen

    var listen: [EinkaufListe] { faltung.listen }
    func liste(_ id: String) -> EinkaufListe? { faltung.liste(id) }
    func eintraege(_ liste: String) -> [EinkaufEintrag] { EinkaufLogik.sortiert(faltung.eintraege(liste)) }
    func erstelltVon(_ eintragId: String) -> Person? { faltung.erstelltVon(eintragId) }

    // MARK: Schreiben

    /// Legt "Einkauf" an, wenn noch keine Liste existiert. Beim Öffnen der Übersicht aufrufen.
    func standardlisteSicherstellen() {
        guard listen.isEmpty else { return }
        listeAnlegen("Einkauf")
    }

    @discardableResult
    func listeAnlegen(_ name: String) -> EinkaufListe {
        let l = EinkaufListe(id: UUID().uuidString, name: name, geloescht: nil)
        Raum.shared.senden("einkauf.liste", l)
        return l
    }

    func listeUmbenennen(_ l: EinkaufListe, name: String) {
        var neu = l
        neu.name = name
        Raum.shared.senden("einkauf.liste", neu)
    }

    func listeLoeschen(_ l: EinkaufListe) {
        var weg = l
        weg.geloescht = true
        Raum.shared.senden("einkauf.liste", weg)
        for e in faltung.eintraege(l.id) { eintragLoeschen(e) }
    }

    /// Neuer Eintrag, oder ein vorhandener mit demselben Text wird wieder offen gesetzt statt doppelt angelegt.
    @discardableResult
    func hinzufuegen(_ text: String, menge: String? = nil, an liste: String) -> EinkaufEintrag {
        let titel = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let vorhanden = faltung.eintraege(liste).first(where: { EinkaufLogik.gleicherText($0.text, titel) }) {
            var wieder = vorhanden
            wieder.erledigt = false
            wieder.geloescht = nil
            if let menge { wieder.menge = menge }
            Raum.shared.senden("einkauf.eintrag", wieder)
            return wieder
        }
        let e = EinkaufEintrag(id: UUID().uuidString, liste: liste, text: titel, menge: menge, erledigt: false,
                               reihenfolge: EinkaufLogik.naechsteReihenfolge(faltung.eintraege(liste)), geloescht: nil)
        Raum.shared.senden("einkauf.eintrag", e)
        return e
    }

    /// Zutaten (etwa eines Rezepts) als Einträge, jede mit ihrer Menge als Text.
    func zutatenHinzufuegen(_ zutaten: [Zutat], an liste: String) {
        for z in zutaten {
            hinzufuegen(z.lebensmittel.anzeigeName, menge: ErnaehrungLogik.mengeText(z.menge, z.einheit, z.lebensmittel), an: liste)
        }
    }

    func aendern(_ e: EinkaufEintrag) { Raum.shared.senden("einkauf.eintrag", e) }

    func erledigtSetzen(_ e: EinkaufEintrag, _ an: Bool) {
        var neu = e
        neu.erledigt = an
        Raum.shared.senden("einkauf.eintrag", neu)
    }

    func eintragLoeschen(_ e: EinkaufEintrag) {
        var weg = e
        weg.geloescht = true
        Raum.shared.senden("einkauf.eintrag", weg)
    }

    func erledigteLoeschen(_ liste: String) {
        for e in faltung.eintraege(liste) where e.erledigt { eintragLoeschen(e) }
    }
}
