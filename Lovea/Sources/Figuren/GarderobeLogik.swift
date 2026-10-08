import Foundation

/// p65 C2: one shop piece in the wardrobe row under the free pieces of a clothing tab.
struct GarderobeStueck: Identifiable {
    let artikel: ShopArtikel
    let besitzt: Bool
    var id: String { artikel.id }
}

enum GarderobeLogik {
    /// The shop pieces of `feld` that `person` may see: owned ones first, then by price. Challenge rewards
    /// (`exklusiv`) only show once owned, since the wardrobe cannot buy them. Pieces without a figure field
    /// (bags, pets, room) never show here.
    static func shopStuecke(feld: ShopFeld, person: Person, katalog: [ShopArtikel] = ShopKatalog.alle, besitzt: (String) -> Bool) -> [GarderobeStueck] {
        katalog
            .filter { $0.sichtbar(fuer: person) && FigurAussehen.shopTeile[$0.id]?.feld == feld }
            .map { GarderobeStueck(artikel: $0, besitzt: besitzt($0.id)) }
            .filter { $0.besitzt || !$0.artikel.exklusiv }
            .sorted { ($0.besitzt ? 0 : 1, $0.artikel.preis, $0.artikel.id) < ($1.besitzt ? 0 : 1, $1.artikel.preis, $1.artikel.id) }
    }
}
