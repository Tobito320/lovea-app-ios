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
        case "uhr": return uhr == artikel.id
        case "schmuck": return schmuck == artikel.id
        case "pose": return pose == artikel.id
        case "tier": return tier == artikel.id
        case "mode", "brille":
            guard let e = FigurAussehen.shopTeile[artikel.id] else { return false }
            switch e.feld {
            case .oberteil: return oberteil == e.index && oberteilfarbeHex == e.hex
            case .jacke: return jacke == e.index && jackenfarbeHex == e.hex
            case .hose: return hose == e.index && hosenfarbeHex == e.hex
            case .schuhe: return schuhe == e.index && schuhfarbeHex == e.hex
            case .brille: return brille == e.index
            }
        default: return false // backdrop: kein Figur-Feld, siehe Profil.
        }
    }

    /// Wears `artikel` — direct-field categories store the id, mode/brille go through the existing
    /// `anziehen(_:String)` (index + hex from `shopTeile`).
    mutating func anziehen(_ artikel: ShopArtikel) {
        switch artikel.kategorie {
        case "tasche": tasche = artikel.id
        case "uhr": uhr = artikel.id
        case "schmuck": schmuck = artikel.id
        case "pose": pose = artikel.id
        case "tier": tier = artikel.id
        case "mode", "brille": anziehen(artikel.id)
        default: break
        }
    }

    /// Takes `artikel` back off. Direct-field categories clear to nil; mode/brille share a field
    /// with the free editor, so they revert to `person`'s standard look for just that one field.
    mutating func ausziehen(_ artikel: ShopArtikel, person: Person) {
        guard traegt(artikel) else { return }
        switch artikel.kategorie {
        case "tasche": tasche = nil
        case "uhr": uhr = nil
        case "schmuck": schmuck = nil
        case "pose": pose = nil
        case "tier": tier = nil
        case "mode", "brille":
            guard let e = FigurAussehen.shopTeile[artikel.id] else { return }
            let basis = FigurAussehen.standard(for: person)
            switch e.feld {
            case .oberteil: oberteil = basis.oberteil; oberteilfarbeHex = basis.oberteilfarbeHex
            case .jacke: jacke = basis.jacke; jackenfarbeHex = basis.jackenfarbeHex
            case .hose: hose = basis.hose; hosenfarbeHex = basis.hosenfarbeHex
            case .schuhe: schuhe = basis.schuhe; schuhfarbeHex = basis.schuhfarbeHex
            case .brille: brille = 0 // "Keine"
            }
        default: break
        }
    }

    /// Live preview copy for the shop grid/big preview — `artikel` applied on top of this look,
    /// without touching `figur.aussehen` until the purchase (or the "Anziehen" toggle) confirms it.
    func mitVorschau(_ artikel: ShopArtikel) -> FigurAussehen {
        var a = self
        a.anziehen(artikel)
        return a
    }
}
