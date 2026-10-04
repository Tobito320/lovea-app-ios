import Foundation

struct DatesAbschnitt: Identifiable, Equatable {
    let kategorie: DateKategorie
    let ideen: [DateIdee]
    /// Zähler der ganzen Kategorie, nicht nur der Treffer des Filters.
    let erledigt: Int
    let gesamt: Int

    var id: String { kategorie.rawValue }
    var zaehler: String { "\(erledigt)/\(gesamt)" }
}

/// Die einzige Löschung, die noch zurückgenommen werden kann (Undo-Leiste).
struct DatesUndo: Equatable {
    static let dauer: TimeInterval = 5

    let ideeID: String
    let titel: String
    let beginn: Date

    func rest(_ jetzt: Date) -> Double {
        min(1, max(0, 1 - jetzt.timeIntervalSince(beginn) / Self.dauer))
    }

    func istOffen(_ jetzt: Date) -> Bool { rest(jetzt) > 0 }
}

enum DatesAnsichtLogik {
    static func abschnitte(_ ideen: [DateIdee], filter: DateFilter) -> [DatesAbschnitt] {
        let sichtbar = ideen.filter { !$0.geloescht }
        let treffer = DateLogik.filtern(sichtbar, filter)
        return DateKategorie.allCases.compactMap { kategorie in
            let hier = treffer.filter { $0.kategorie == kategorie }
            guard !hier.isEmpty else { return nil }
            let ganze = sichtbar.filter { $0.kategorie == kategorie }
            return DatesAbschnitt(kategorie: kategorie, ideen: hier, erledigt: ganze.filter(\.erledigt).count, gesamt: ganze.count)
        }
    }

    /// Zweiter Tipp auf den gleichen Status-Chip hebt ihn wieder auf.
    static func umschalten(_ filter: DateFilter, status: DateStatus) -> DateFilter {
        var neu = filter
        neu.status = filter.status == status ? .alle : status
        return neu
    }

    static func istGefiltert(_ filter: DateFilter) -> Bool {
        filter.kategorie != nil || filter.status != .alle || filter.ort != nil
    }

    static func ortZeile(_ idee: DateIdee) -> String? {
        let name = idee.ort?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty ?? true) ? nil : name
    }

    static func sprechtext(_ idee: DateIdee) -> String {
        var teile = [idee.titel, idee.erledigt ? "erledigt" : "offen"]
        if let ort = ortZeile(idee) { teile.append(ort) }
        if !idee.links.isEmpty { teile.append(idee.links.count == 1 ? "1 Link" : "\(idee.links.count) Links") }
        return teile.joined(separator: ", ")
    }
}
