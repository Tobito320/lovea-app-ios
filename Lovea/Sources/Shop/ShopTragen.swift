import Foundation

/// Z-23.2: wear/unwear a `ShopArtikel` on a `FigurAussehen`, and gate the catalog by gender.
/// Lives in Shop/ (not Figuren/) on purpose — brief-F only touches Figuren/ for the one existing-bug
/// fix in `anziehen(_:String)`, everything shop-specific stays here.
extension ShopArtikel {
    /// `geschlecht`: "n" shows for both, "w"/"m" only for that person (Spec §4.3 "Weibliche Teile
    /// nur bei Annika, männliche nur bei Ahmed").
    func sichtbar(fuer person: Person) -> Bool { geschlecht == "n" || geschlecht == person.figurGeschlecht.rawValue }
}

extension FigurAussehen {
    /// Whether `artikel` is currently worn.
    func traegt(_ artikel: ShopArtikel) -> Bool {
        switch artikel.kategorie {
        case "tasche": return tasche == artikel.id
        case "tier": return tier == artikel.id
        case "mode": return traegtTeil(artikel.id)
        default: return false
        }
    }

    private func traegtTeil(_ id: String) -> Bool {
        guard let e = FigurAussehen.shopTeile[id] else { return false }
        switch e.feld {
        case .oberteil: return oberteil == e.index && oberteilfarbeHex == e.hex
        case .jacke: return jacke == e.index && jackenfarbeHex == e.hex
        case .hose: return hose == e.index && hosenfarbeHex == e.hex
        case .schuhe: return schuhe == e.index && schuhfarbeHex == e.hex
        case .brille: return brille == e.index
        }
    }

    /// Wears `artikel` — direct-field categories store the id, mode goes through the existing
    /// `anziehen(_:String)` (index + hex from `shopTeile`).
    mutating func anziehen(_ artikel: ShopArtikel) {
        switch artikel.kategorie {
        case "tasche": tasche = artikel.id
        case "tier": tier = artikel.id
        case "mode": anziehen(artikel.id)
        default: break
        }
    }

    /// Takes `artikel` back off. Direct-field categories clear to nil; mode shares a field
    /// with the free editor, so they revert to `person`'s standard look for just that one field.
    mutating func ausziehen(_ artikel: ShopArtikel, person: Person) {
        guard traegt(artikel) else { return }
        switch artikel.kategorie {
        case "tasche": tasche = nil
        case "tier": tier = nil
        case "mode": teilAblegen(artikel.id, person: person)
        default: break
        }
    }

    private mutating func teilAblegen(_ id: String, person: Person) {
        guard let e = FigurAussehen.shopTeile[id] else { return }
        let basis = FigurAussehen.standard(for: person)
        switch e.feld {
        case .oberteil: oberteil = basis.oberteil; oberteilfarbeHex = basis.oberteilfarbeHex
        case .jacke: jacke = basis.jacke; jackenfarbeHex = basis.jackenfarbeHex
        case .hose: hose = basis.hose; hosenfarbeHex = basis.hosenfarbeHex
        case .schuhe: schuhe = basis.schuhe; schuhfarbeHex = basis.schuhfarbeHex
        case .brille: brille = 0 // "Keine"
        }
    }

    /// p47: legt Teile ab, die es im Shop nicht mehr gibt, damit die Figur gültig bleibt. Uhr und Schmuck
    /// gibt es nicht mehr, Tasche und Haustier nur, wenn die ID entfernt wurde. Mode und Brille nur, wenn der
    /// Index dem Shop vorbehalten ist (der freie Editor kann ihn nicht wählen); freie Indizes bleiben.
    /// Reine Lesesicht, ohne Schreiben: beide Geräte kommen zum selben Bild.
    func ohneEntfernteTeile() -> FigurAussehen {
        var a = self
        a.uhr = nil
        a.schmuck = nil
        if let id = a.tasche, ShopErstattung.entfernt[id] != nil { a.tasche = nil }
        if let id = a.tier, ShopErstattung.entfernt[id] != nil { a.tier = nil }
        guard let person = a.person else { return a }
        for id in ShopErstattung.entfernt.keys where a.traegtTeil(id) {
            guard let e = FigurAussehen.shopTeile[id] else { continue }
            let nurShop: Bool
            switch e.feld {
            case .oberteil: nurShop = FigurAussehen.oberteileShop.contains(e.index)
            case .jacke: nurShop = FigurAussehen.jackenShop.contains(e.index)
            case .hose: nurShop = FigurAussehen.hosenShop.contains(e.index)
            case .schuhe: nurShop = FigurAussehen.schuheShop.contains(e.index)
            case .brille: nurShop = FigurAussehen.brillenShop.contains(e.index)
            }
            if nurShop { a.teilAblegen(id, person: person) }
        }
        return a
    }

    /// Live preview copy for the shop grid/big preview — `artikel` applied on top of this look,
    /// without touching `figur.aussehen` until the purchase (or the "Anziehen" toggle) confirms it.
    func mitVorschau(_ artikel: ShopArtikel) -> FigurAussehen {
        var a = self
        a.anziehen(artikel)
        return a
    }
}
