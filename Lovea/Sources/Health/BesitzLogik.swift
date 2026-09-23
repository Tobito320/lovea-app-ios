import Foundation

/// Pure Shop-ownership logic (Z-23.1, Spec 4.3). Folds `shop.kauf {id, artikel, fuer, verdient?}` ops in
/// `seq` order. The catalog (`ShopKatalog`, built by another block) isn't a dependency here — price comes
/// in as a `(String) -> Int?` closure, `nil` meaning "no such article, reject".
enum BesitzLogik {
    struct Kauf: Sendable {
        var seq: Int?
        var id: String
        /// Who spent the points — always pays, even when gifting (`fuer != von`).
        var von: Person
        var artikel: String
        /// Who ends up owning it — the partner on a gift, else equal to `von`.
        var fuer: Person
        /// `Op.zeit` (Brief I.2) — the negative "Wofür?" row uses this as its date. Defaulted so
        /// existing call sites/tests that don't care about the date keep compiling.
        var zeit: Date = .distantPast
        /// Final-Review I-1: the buyer's lifetime EARNED total (not the spendable balance) at the
        /// moment of buying, carried in the op. `nil` on ops sent before this field existed.
        var verdient: Int? = nil
    }

    struct Ergebnis: Sendable, Equatable {
        var besitz: [Person: Set<String>] = [:]
        /// Op ids rejected: no such article, or would have taken the buyer's balance below 0.
        var abgelehnt: Set<String> = []
        /// Points spent per BUYER (`von`), not per owner — what `kaufen(...)` checks the next
        /// purchase against.
        var ausgegeben: [Person: Int] = [:]

        func besitzt(_ artikel: String, _ person: Person) -> Bool { besitz[person]?.contains(artikel) ?? false }
    }

    /// Strictly in `seq` order (unconfirmed last): of two simultaneous purchases by the same person
    /// that together would go negative, the earlier one wins (Review-Fokus 3). Final-Review I-1: each
    /// purchase is judged against `kauf.verdient` (what the buyer had earned when buying) minus what
    /// earlier accepted purchases spent — only data at or before its own `seq`. So a verdict never
    /// changes later: a rejected purchase stays rejected when more points come in, an accepted one
    /// stays owned when points later drop (Gym unticked, Duel flipped), and both phones agree.
    /// `verdient` (today's lifetime total) is only the fallback for old ops without the field.
    static func auswerten(_ kaeufe: [Kauf], verdient: [Person: Int], preis: (String) -> Int?) -> Ergebnis {
        let sortiert = kaeufe.sorted { ($0.seq ?? .max, $0.id) < ($1.seq ?? .max, $1.id) }
        var gesehen = Set<String>()
        var eindeutig: [Kauf] = []
        for kauf in sortiert where gesehen.insert(kauf.id).inserted { eindeutig.append(kauf) }

        var ergebnis = Ergebnis()
        for kauf in eindeutig {
            guard let preisWert = preis(kauf.artikel) else { ergebnis.abgelehnt.insert(kauf.id); continue }
            let bisher = ergebnis.ausgegeben[kauf.von, default: 0]
            let verfuegbar = (kauf.verdient ?? verdient[kauf.von] ?? 0) - bisher
            guard verfuegbar >= preisWert else { ergebnis.abgelehnt.insert(kauf.id); continue }
            ergebnis.ausgegeben[kauf.von, default: 0] = bisher + preisWert
            ergebnis.besitz[kauf.fuer, default: []].insert(kauf.artikel)
        }
        return ergebnis
    }

    /// Final-Review I-5 (Spec 4.2 "Gemeinsam Monat: ... und ein exklusives Shop-Teil"): the n-th
    /// completed month unlocks the n-th exclusive article (catalog order) for BOTH, for free.
    // ponytail: once every exclusive article is handed out, further months only give the +500 —
    // add more `exklusiv` entries to katalog.json to keep the reward going.
    static func exklusivFrei(erreichteMonate: Int, exklusiv: [String]) -> Set<String> {
        Set(exklusiv.prefix(max(0, erreichteMonate)))
    }
}
