import Foundation

/// p65 D: the free kit of one person, five pieces. Everything else is shop-only (`oberteileShop` etc.).
/// Colors stay free for the kit, so "All Black", "All White" and "Pink" cost nothing.
struct Grundausstattung: Equatable, Sendable {
    let oberteile: Set<Int>
    let hosen: Set<Int>
    let schuhe: Set<Int>

    var anzahl: Int { oberteile.count + hosen.count + schuhe.count }
}

extension FigurAussehen {
    /// "Oben ohne" is no piece of clothing, so it stays free for whoever may pick it.
    static let keinOberteil = 33

    /// Ahmed: Hoodie, T-Shirt schwarz, Jeans dunkel, Baggy Jeans hellgrau, Sneaker weiß.
    /// Annika: Hoodie, Top, Jeans dunkel, Rock, High-Top. Each person gets exactly one free pair of shoes,
    /// enforced by the gender tags of `schuheGeschlecht`.
    static func grundausstattung(fuer person: Person) -> Grundausstattung {
        switch person {
        case .ahmed: Grundausstattung(oberteile: [1, 32], hosen: [1, 18], schuhe: [15])
        case .annika: Grundausstattung(oberteile: [1, 4], hosen: [1, 7], schuhe: [1])
        }
    }

    /// What either person may wear for free; the shop sets are everything else.
    static let freieOberteile: Set<Int> = Person.allCases.reduce(into: Set<Int>()) { $0.formUnion(grundausstattung(fuer: $1).oberteile) }
    static let freieHosen: Set<Int> = Person.allCases.reduce(into: Set<Int>()) { $0.formUnion(grundausstattung(fuer: $1).hosen) }
    static let freieSchuhe: Set<Int> = Person.allCases.reduce(into: Set<Int>()) { $0.formUnion(grundausstattung(fuer: $1).schuhe) }
}
