import Foundation

/// Z-23.1: one purchasable shop item. `preis` in points, `geschlecht` gates visibility ("w"/"m"
/// shown to that person only, "n" to both — Spec §4.3). `exklusiv` = monthly-challenge-only reward.
struct ShopArtikel: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let marke: String?
    let kategorie: String
    let preis: Int
    let geschlecht: String /* "w" | "m" | "n" */
    let exklusiv: Bool
}

/// Z-23.1: the shop catalog, decoded once from the bundled `katalog.json` (lazy `static let`).
/// Wearing/purchase logic lives elsewhere (BesitzLogik, Block 23.2) — this is data only.
enum ShopKatalog {
    static let alle: [ShopArtikel] = {
        guard let url = Bundle.main.url(forResource: "katalog", withExtension: "json")
            ?? Bundle.main.url(forResource: "katalog", withExtension: "json", subdirectory: "Shop"),
            let daten = try? Data(contentsOf: url),
            let artikel = try? JSONDecoder().decode([ShopArtikel].self, from: daten)
        else { return [] }
        return artikel
    }()

    private static let nachId: [String: ShopArtikel] = Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })

    static func artikel(_ id: String) -> ShopArtikel? { nachId[id] }
}
