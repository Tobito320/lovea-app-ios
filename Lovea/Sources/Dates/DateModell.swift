import Foundation

enum DateKategorie: String, Codable, CaseIterable, Sendable {
    case essen, aktivitaet, draussen, reisen, kreativ, zuhause, besonders

    var titel: String {
        switch self {
        case .essen: "Essen"
        case .aktivitaet: "Aktivität"
        case .draussen: "Draußen"
        case .reisen: "Reisen"
        case .kreativ: "Kreativ"
        case .zuhause: "Zuhause"
        case .besonders: "Besonders"
        }
    }
}

struct DateLink: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var url: String
    var titel: String?
}

/// Eine Date-Idee. Ganzes Objekt je Op `dates.idee`, last-writer-wins nach `geaendert`.
/// Löschen ist nur das Flag `geloescht`, so geht Rückgängig und der Stand bleibt auf beiden Handys gleich.
struct DateIdee: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var titel: String
    var kategorie: DateKategorie
    var erledigt: Bool
    /// yyyy-MM-dd
    var erledigtAm: String?
    /// Ein Name ohne Koordinate (bis zur Ortssuche) steht als lat 0 / lon 0, siehe `DateLogik.hatKoordinate`.
    var ort: PunktOrt?
    var links: [DateLink]
    var notiz: String?
    var geloescht: Bool
    var geaendert: Date
    var von: Person

    init(
        id: String, titel: String, kategorie: DateKategorie, erledigt: Bool = false, erledigtAm: String? = nil,
        ort: PunktOrt? = nil, links: [DateLink] = [], notiz: String? = nil, geloescht: Bool = false,
        geaendert: Date, von: Person
    ) {
        self.id = id
        self.titel = titel
        self.kategorie = kategorie
        self.erledigt = erledigt
        self.erledigtAm = erledigtAm
        self.ort = ort
        self.links = links
        self.notiz = notiz
        self.geloescht = geloescht
        self.geaendert = geaendert
        self.von = von
    }
}
