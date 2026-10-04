import Foundation

enum DateLinkAufnahme: Equatable {
    case neu(DateLink)
    case ungueltig
    case doppelt
}

/// Alles, was das Idee-Blatt entscheidet und speichert, ohne UI. So testbar ohne Blatt.
enum DateIdeeBearbeitung {
    struct Entwurf: Equatable {
        var titel: String
        var kategorie: DateKategorie
        var erledigt: Bool
        var notiz: String
        var ort: PunktOrt?
        var links: [DateLink]
    }

    /// Prüft eine getippte oder eingefügte Adresse gegen `DateLogik` und gegen die vorhandenen Links.
    static func linkAufnehmen(_ text: String, in links: [DateLink], id: String = UUID().uuidString) -> DateLinkAufnahme {
        guard let neu = DateLogik.link(aus: text, id: id) else { return .ungueltig }
        let schluessel = vergleich(neu.url)
        return links.contains { vergleich($0.url) == schluessel } ? .doppelt : .neu(neu)
    }

    /// Schema und Host klein, ohne Anker und ohne Schrägstrich am Ende: `Example.com/` ist `example.com`.
    static func vergleich(_ text: String) -> String {
        guard let url = DateLogik.normalisiert(text), var teile = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return text
        }
        teile.scheme = teile.scheme?.lowercased()
        teile.host = teile.host?.lowercased()
        teile.fragment = nil
        var s = teile.string ?? text
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// Schreibt nur, was sich geändert hat, damit ein bloßes "Fertig" keine Op an den Partner schickt.
    @MainActor
    static func speichern(_ entwurf: Entwurf, idee: DateIdee?, in speicher: DateSpeicher) {
        let titel = entwurf.titel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titel.isEmpty else { return }
        let text = entwurf.notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        let notiz: String? = text.isEmpty ? nil : text
        if let idee {
            if titel != idee.titel || entwurf.kategorie != idee.kategorie || notiz != idee.notiz
                || entwurf.ort != idee.ort || entwurf.links != idee.links {
                speicher.aendern(idee.id) {
                    $0.titel = titel
                    $0.kategorie = entwurf.kategorie
                    $0.notiz = notiz
                    $0.ort = entwurf.ort
                    $0.links = entwurf.links
                }
            }
            speicher.abhaken(idee.id, erledigt: entwurf.erledigt)
        } else if let neu = speicher.anlegen(
            titel: titel, kategorie: entwurf.kategorie, ort: entwurf.ort, links: entwurf.links, notiz: notiz
        ), entwurf.erledigt {
            speicher.abhaken(neu.id, erledigt: true)
        }
    }

    static func symbol(_ art: DateLinkArt) -> String {
        switch art {
        case .karte: "map"
        case .tiktok: "play.rectangle"
        case .instagram: "camera"
        case .andere: "link"
        }
    }
}
