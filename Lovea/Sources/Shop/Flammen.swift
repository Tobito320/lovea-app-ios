import SwiftUI

/// Z-23.3: the "flamme" shop category (≥8). `EinstellungenModell.shared.string("flamme", default:
/// "🔥")` already renders whatever's stored as plain text (see `ChatKopfzeile`) — so `symbol` here
/// is the exact value Block 23.2 writes on purchase, no extra mapping needed. Ids match `ShopKatalog`.
struct Flamme: Identifiable, Sendable {
    let id: String
    let name: String
    let symbol: String
}

enum Flammen {
    static let alle: [Flamme] = [
        Flamme(id: "flamme.klassisch", name: "Klassisch", symbol: "🔥"),
        Flamme(id: "flamme.blau", name: "Blau", symbol: "💙"),
        Flamme(id: "flamme.lila", name: "Lila", symbol: "💜"),
        Flamme(id: "flamme.blitz", name: "Blitz", symbol: "⚡"),
        Flamme(id: "flamme.stern", name: "Stern", symbol: "🌟"),
        Flamme(id: "flamme.herz", name: "Herz", symbol: "❤️‍🔥"),
        Flamme(id: "flamme.eis", name: "Eiskalt", symbol: "🧊"),
        Flamme(id: "flamme.diamant", name: "Diamant", symbol: "💎"),
    ]

    static func von(_ id: String) -> Flamme? { alle.first { $0.id == id } }
}

/// Small preview tile for the shop.
struct FlammenPreviewView: View {
    let flamme: Flamme

    var body: some View {
        Text(flamme.symbol)
            .font(.system(size: 30))
            .frame(width: 44, height: 44)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(flamme.name)
    }
}
