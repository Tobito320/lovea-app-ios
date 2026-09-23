import SwiftUI
import UIKit

/// Z-33.1: what `nachricht.reaktion {id, emoji}` carries in `emoji` — an emoji, `"figur:<id>"` or
/// `"sticker:<assetName>"`. Older builds show the raw string, which is accepted.
enum Reaktion: Equatable, Sendable {
    case emoji(String), figur(String), sticker(String)

    init(_ wert: String) {
        if wert.hasPrefix("figur:") {
            self = .figur(String(wert.dropFirst("figur:".count)))
        } else if wert.hasPrefix("sticker:") {
            self = .sticker(String(wert.dropFirst("sticker:".count)))
        } else {
            self = .emoji(wert)
        }
    }

    var wert: String {
        switch self {
        case .emoji(let zeichen): zeichen
        case .figur(let id): "figur:" + id
        case .sticker(let name): "sticker:" + name
        }
    }

    /// Spoken by VoiceOver and shown in "who reacted".
    var beschreibung: String {
        switch self {
        case .emoji(let zeichen): zeichen
        case .figur(let id): FigurReaktionen.von(id)?.titel ?? "Figur"
        case .sticker: "Sticker"
        }
    }

    /// The emoji keyboard's first character — never a letter or digit typed on a switched keyboard.
    static func istEmoji(_ zeichen: Character) -> Bool {
        zeichen.unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || (zeichen.unicodeScalars.count > 1 && zeichen.unicodeScalars.first?.properties.isEmoji == true)
    }
}

/// One figure reaction. Single ones use the reacting person's figure and their `id` is the
/// `FigurZustand` raw value; couple ones (`paar`) show both figures.
struct FigurReaktion: Identifiable, Sendable {
    let id: String
    let titel: String
    let paar: Bool
}

/// Couple scene: Ahmed left, Annika right, like `FreundschaftsSticker`.
struct PaarPose: Sendable {
    let links: String
    let rechts: String
    var zugewandt = false
    var symbol: String?
}

enum FigurReaktionen {
    /// Spec 2.4: the long-press bar — lachen, verliebt, weinen, schockiert, Daumen, Kuss.
    static let schnell: [FigurReaktion] = ["lacht", "verliebt", "weint", "schockiert", "daumen", "kuss"].compactMap { FigurReaktionen.von($0) }

    static let alle: [FigurReaktion] = einzeln.map { FigurReaktion(id: $0.id, titel: $0.titel, paar: false) }
        + paare.map { FigurReaktion(id: $0.id, titel: $0.titel, paar: true) }

    static func von(_ id: String) -> FigurReaktion? { alle.first { $0.id == id } }

    static func paarPose(_ id: String) -> PaarPose? { paare.first { $0.id == id }?.pose }

    // Raw values rather than `FigurZustand` cases: a state an older figure build lacks falls back to
    // `.ruhig` when drawn instead of breaking the build.
    private static let einzeln: [(id: String, titel: String)] = [
        ("lacht", "Lachen"), ("verliebt", "Verliebt"), ("weint", "Weinen"), ("schockiert", "Schockiert"),
        ("daumen", "Daumen hoch"), ("kuss", "Kuss"), ("lachtTraenen", "Tränen lachen"), ("zwinkert", "Zwinkern"),
        ("herz", "Denk an dich"), ("feiert", "Feiern"), ("tanzt", "Tanzen"), ("ueberrascht", "Überrascht"),
        ("denkt", "Nachdenken"), ("verlegen", "Verlegen"), ("schmollt", "Schmollen"), ("sauer", "Sauer"),
        ("muede", "Müde"), ("naehe", "Umarmung"), ("anstossen", "Prost"), ("pokal", "Gewonnen"),
        ("imChat", "Hallo"), ("morgen", "Guten Morgen"), ("schlaeft", "Gute Nacht"), ("anstupsen", "Anstupsen"),
        ("worte", "Liebe Worte"), ("gut", "Freude"),
    ]

    private static let paare: [(id: String, titel: String, pose: PaarPose)] = [
        ("paar-kuss", "Küssen", PaarPose(links: "kuss", rechts: "kuss", zugewandt: true)),
        ("paar-herz", "Herz", PaarPose(links: "herz", rechts: "herz", symbol: "heart.fill")),
        ("paar-prost", "Anstoßen", PaarPose(links: "anstossen", rechts: "anstossen", zugewandt: true)),
        ("paar-lachen", "Zusammen lachen", PaarPose(links: "lachtTraenen", rechts: "lachtTraenen")),
        ("paar-kuscheln", "Kuscheln", PaarPose(links: "naehe", rechts: "naehe", symbol: "heart.fill")),
        ("paar-feiern", "Feiern", PaarPose(links: "feiert", rechts: "feiert", symbol: "party.popper.fill")),
        ("paar-tanzen", "Tanzen", PaarPose(links: "tanzt", rechts: "tanzt", zugewandt: true, symbol: "music.note")),
        ("paar-verliebt", "Verliebt", PaarPose(links: "verliebt", rechts: "verliebt", zugewandt: true, symbol: "heart.fill")),
        ("paar-nacht", "Gute Nacht", PaarPose(links: "schlaeft", rechts: "schlaeft", symbol: "moon.stars.fill")),
        ("paar-hallo", "High-Five", PaarPose(links: "imChat", rechts: "imChat", zugewandt: true, symbol: "sparkle")),
        ("paar-sieg", "Gewonnen", PaarPose(links: "pokal", rechts: "gut", symbol: "trophy.fill")),
        ("paar-morgen", "Guten Morgen", PaarPose(links: "morgen", rechts: "morgen", symbol: "sun.max.fill")),
    ]
}
