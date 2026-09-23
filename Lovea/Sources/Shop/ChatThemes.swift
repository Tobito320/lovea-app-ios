import SwiftUI

/// Z-23.3: the "chatTheme" shop category (≥6) — a gradient pair per theme plus a small preview.
/// Ids match `ShopKatalog` `chatTheme.*` entries. Picked under "Unser Chat", rendered as the chat
/// background in `ChatHintergrundAnsicht` (Brief I.1).
struct ChatTheme: Identifiable, Sendable {
    let id: String
    let name: String
    let von: FigurFarbe
    let bis: FigurFarbe

    var verlauf: LinearGradient {
        LinearGradient(colors: [von.farbe, bis.farbe], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum ChatThemes {
    static let alle: [ChatTheme] = [
        ChatTheme(id: "chatTheme.sonnenuntergang", name: "Sonnenuntergang", von: FigurFarbe(0xF08A4B), bis: FigurFarbe(0xFF3B5C)),
        ChatTheme(id: "chatTheme.mitternacht", name: "Mitternachtsblau", von: FigurFarbe(0x2C3E6B), bis: FigurFarbe(0x221C1C)),
        ChatTheme(id: "chatTheme.pastell", name: "Pastell-Traum", von: FigurFarbe(0xF7B6C8), bis: FigurFarbe(0x8ED8BE)),
        ChatTheme(id: "chatTheme.neon", name: "Neon-Glow", von: FigurFarbe(0x9B7BD8), bis: FigurFarbe(0x3F74B5)),
        ChatTheme(id: "chatTheme.rosegold", name: "Rosé Gold", von: FigurFarbe(0xF5C542), bis: FigurFarbe(0xF7B6C8)),
        ChatTheme(id: "chatTheme.wald", name: "Wald-Grün", von: FigurFarbe(0x3F7D52), bis: FigurFarbe(0x5DBB7A)),
    ]

    static func von(_ id: String) -> ChatTheme? { alle.first { $0.id == id } }
}

/// Small preview tile for the shop — the gradient plus a chat-bubble hint.
struct ChatThemePreviewView: View {
    let thema: ChatTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(thema.verlauf)
            .overlay(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.85))
                    .frame(width: 28, height: 14)
                    .padding(6)
            }
            .frame(width: 64, height: 44)
            .accessibilityLabel(thema.name)
    }
}
