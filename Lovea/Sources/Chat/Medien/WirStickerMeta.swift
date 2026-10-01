import Foundation

/// R6: wer auf einem "Wir"-Sticker zu sehen ist — für die Personen-Chips im Reiter "Wir".
enum WirWer: String, CaseIterable, Identifiable, Sendable {
    case ahmed, annika, beide
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .ahmed: "Ahmed"
        case .annika: "Annika"
        case .beide: "Beide"
        }
    }
}

/// R6: Metadaten zu den mitgelieferten "Wir"-Stickern (`MitgelieferteSticker.alle`) — wer zu sehen
/// ist und welche Kontext-Tags passen, von Hand gepflegt (Bilder lassen sich nicht automatisch
/// auswerten). Fehlt ein Name hier, läuft er beim Filtern einfach leer mit (kein Absturz).
enum WirStickerMeta {
    static let daten: [String: (wer: WirWer, kontext: Set<String>)] = [
        "wir-annika-kuss-winken": (.annika, ["Liebe"]),
        "wir-annika-rosen": (.annika, ["Liebe"]),
        "wir-annika-kichern": (.annika, ["Lustig"]),
        "wir-annika-schuechtern": (.annika, ["Liebe"]),
        "wir-annika-finger-grinsen": (.annika, ["Lustig"]),
        "wir-annika-finger-sw": (.annika, ["Liebe"]),
        "wir-annika-frech": (.annika, ["Lustig"]),
        "wir-annika-schulterblick": (.annika, ["Liebe"]),
        "wir-annika-zunge": (.annika, ["Lustig"]),
        "wir-annika-augenrollen": (.annika, ["Lustig"]),
        "wir-annika-telefon": (.annika, ["Liebe"]),
        "wir-annika-cheers": (.annika, ["Unterwegs"]),
        "wir-kuss-echt": (.beide, ["Liebe"]),
        "wir-kuss": (.beide, ["Liebe"]),
        "wir-umarmung": (.beide, ["Liebe"]),
        "wir-selfie": (.beide, ["Unterwegs"]),
        "wir-kino": (.beide, ["Unterwegs"]),
        "wir-gym": (.beide, ["Gym"]),
        "wir-ich": (.beide, ["Liebe"]),
        "wir-du": (.beide, ["Liebe"]),
        "wir-zuhause": (.beide, ["Liebe"]),
        "wir-vermisse-dich": (.annika, ["Liebe", "Traurig"]),
        "wir-so-suess": (.ahmed, ["Liebe"]),
        "wir-lieblingsmensch": (.beide, ["Liebe", "Schlaf"]),
        "wir-nur-wir": (.beide, ["Liebe", "Schlaf"]),
        "wir-wir-immer": (.beide, ["Lustig"]),
        "wir-fuer-dich": (.ahmed, ["Liebe"]),
        "wir-danke": (.beide, ["Liebe"]),
        "wir-danke-dass-es-dich-gibt": (.beide, ["Liebe"]),
        "wir-du-bist-meine": (.beide, ["Liebe", "Schlaf"]),
        "wir-pass-auf-dich-auf": (.beide, ["Liebe"]),
        "wir-so-gluecklich": (.annika, ["Liebe"]),
        "wir-gluecklich": (.annika, ["Liebe", "Schlaf"]),
        "wir-mit-dir-besser": (.beide, ["Liebe", "Schlaf"]),
        "wir-zusammen-besser": (.beide, ["Liebe", "Schlaf"]),
        "wir-wenn-wir-zusammen": (.beide, ["Lustig"]),
        "wir-alles-wird-gut": (.beide, ["Liebe", "Schlaf"]),
        "wir-so-gut-aus": (.ahmed, ["Lustig"]),
        "wir-gute-nacht": (.beide, ["Schlaf"]),
        "wir-gute-nacht-bett": (.beide, ["Schlaf"]),
        "wir-schlafen-gehen": (.ahmed, ["Schlaf"]),
        "wir-noch-5-minuten": (.ahmed, ["Schlaf"]),
        "wir-nur-noch-5-minuten": (.ahmed, ["Schlaf"]),
        "wir-gelesen": (.ahmed, ["Schlaf"]),
        "wir-gleich-schreiben": (.beide, ["Lustig"]),
        "wir-wer-hat-geschrieben": (.annika, ["Lustig"]),
        "wir-schon-wieder-online": (.annika, ["Lustig"]),
        "wir-hmm": (.ahmed, ["Lustig"]),
        "wir-interessant": (.annika, ["Lustig"]),
        "wir-interessant-tasse": (.annika, ["Lustig", "Morgen"]),
        "wir-interessant-trinken": (.annika, ["Lustig"]),
        "wir-echt-jetzt": (.annika, ["Lustig"]),
        "wir-keine-ahnung": (.ahmed, ["Lustig"]),
        "wir-keine-ahnung-2": (.ahmed, ["Lustig"]),
        "wir-nicht-frech": (.annika, ["Lustig"]),
        "wir-essen": (.ahmed, ["Essen"]),
        "wir-wochenende": (.ahmed, ["Lustig"]),
        "wir-lernen-arbeit": (.ahmed, ["Arbeit"]),
        "wir-zu-viel-zu-tun": (.ahmed, ["Arbeit"]),
        "meme-drake": (.ahmed, ["Schlaf", "Liebe"]),
        "meme-this-is-fine": (.ahmed, ["Lustig"]),
        "meme-side-eye": (.annika, ["Lustig"]),
    ]

    static func wer(_ name: String) -> WirWer? { daten[name]?.wer }
    static func kontext(_ name: String) -> Set<String> { daten[name]?.kontext ?? [] }

    /// R7: Tags nur unter den Stickern eines Tabs (`wer`) — Kontext-Leiste zeigt keine Lücken.
    static func kontexte(fuer wer: WirWer) -> [String] {
        Set(daten.values.filter { $0.wer == wer }.flatMap(\.kontext)).sorted()
    }
}

/// R7: reine Filterfunktion für die Sticker-Tabs (Wir/Ahmed/Annika) — kein SwiftUI, einzeln testbar.
/// Jeder Tab ist fest an ein `wer` gebunden (kein "Alle" mehr). `kontext == nil` heißt "Alle" für den Tag.
enum WirStickerFilter {
    static func gefiltert(_ namen: [String], wer: WirWer, kontext: String?) -> [String] {
        namen.filter { name in
            guard WirStickerMeta.wer(name) == wer else { return false }
            if let kontext, !WirStickerMeta.kontext(name).contains(kontext) { return false }
            return true
        }
    }
}
