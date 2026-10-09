import Foundation

/// Unser Zimmer, Worker I: Sync-Werte (`zimmer.*`) für Schublade, Zettel, Decken und Tage.
/// Jede Person schreibt nur ihre eigenen Schlüssel, beide lesen beide.
@MainActor
enum ZimmerNaeheDaten {
    typealias Zettel = ZimmerNaeheLogik.Zettel

    static let haltKey = "zimmer.schubladeHalt"
    static let zettelKey = "zimmer.zettel"
    static let deckenKey = "zimmer.decken"
    static let tageKey = "zimmer.tage"

    static var ich: Person { RDaten.ich }

    static func halt(von person: Person) -> Date? { RDaten.datum(haltKey, von: person) }

    static func zettel(von person: Person) -> [Zettel] {
        RDaten.lesen(zettelKey, von: person, als: [Zettel].self) ?? []
    }

    /// Alle Zettel beider, die der Partner zuerst.
    static func alleZettel() -> [Zettel] { zettel(von: ich.partner) + zettel(von: ich) }

    static func zettelSchreiben(_ text: String) {
        let neu = ZimmerNaeheLogik.zettelHinzu(zettel(von: ich), text: text, id: UUID().uuidString)
        RDaten.schreiben(zettelKey, neu)
    }

    static func decken(von person: Person) -> Int { Int(RDaten.zahl(deckenKey, von: person) ?? 0) }

    static func tage(von person: Person) -> [String] {
        RDaten.lesen(tageKey, von: person, als: [String].self) ?? []
    }

    /// Heute für mich eintragen, nur wenn es noch fehlt.
    static func heuteEintragen() {
        let heute = RDaten.heute
        let alt = tage(von: ich)
        guard !alt.contains(heute) else { return }
        RDaten.schreiben(tageKey, ZimmerNaeheLogik.tagHinzu(alt, heute: heute))
    }
}
