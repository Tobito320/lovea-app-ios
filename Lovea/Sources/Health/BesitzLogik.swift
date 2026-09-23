import Foundation

/// Pure Shop-ownership logic (Z-23.1, Spec 4.3). Folds `shop.kauf {id, artikel, fuer}` ops in `seq`
/// order. The catalog (`ShopKatalog`, built by another block) isn't a dependency here — price comes
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

    /// `verdient`: total points ever earned per person (from `PunkteLogik`/`ChallengeLogik`), the
    /// balance a purchase draws down from. Processing happens strictly in `seq` order (unconfirmed
    /// last) so that of two simultaneous purchases by the same person that together would go
    /// negative, the earlier one wins (Review-Fokus 3) — deterministic and identical on both devices.
    static func auswerten(_ kaeufe: [Kauf], verdient: [Person: Int], preis: (String) -> Int?) -> Ergebnis {
        let sortiert = kaeufe.sorted { ($0.seq ?? .max, $0.id) < ($1.seq ?? .max, $1.id) }
        var gesehen = Set<String>()
        var eindeutig: [Kauf] = []
        for kauf in sortiert where gesehen.insert(kauf.id).inserted { eindeutig.append(kauf) }

        var ergebnis = Ergebnis()
        for kauf in eindeutig {
            guard let preisWert = preis(kauf.artikel) else { ergebnis.abgelehnt.insert(kauf.id); continue }
            let bisher = ergebnis.ausgegeben[kauf.von, default: 0]
            let verfuegbar = (verdient[kauf.von] ?? 0) - bisher
            guard verfuegbar >= preisWert else { ergebnis.abgelehnt.insert(kauf.id); continue }
            ergebnis.ausgegeben[kauf.von, default: 0] = bisher + preisWert
            ergebnis.besitz[kauf.fuer, default: []].insert(kauf.artikel)
        }
        return ergebnis
    }
}
