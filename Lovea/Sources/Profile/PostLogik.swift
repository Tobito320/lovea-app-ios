import Foundation

/// p67 B: Post im Profil. Briefe und Sprachpost sind Chat-Nachrichten des Partners (kein eigener Op):
/// ein Brief beginnt mit `briefKopf` (so schreibt ihn das Profil) oder ist ein langer Text ohne Medium.
enum PostLogik {
    static let briefKopf = "Brief\n\n"
    static let langerText = 140

    static func istBrief(_ n: ChatModell.Nachricht) -> Bool {
        guard !n.geloescht, n.medien.isEmpty, n.snap == nil, n.gif == nil, n.sticker == nil, n.spiel == nil, n.system == nil,
              let text = n.text else { return false }
        return text.hasPrefix(briefKopf) || text.count >= langerText
    }

    static func istSprachpost(_ n: ChatModell.Nachricht) -> Bool {
        !n.geloescht && n.medien.first?.typ == "sprache"
    }

    static func briefe(_ alle: [ChatModell.Nachricht], von partner: Person) -> [ChatModell.Nachricht] {
        alle.filter { $0.von == partner && istBrief($0) }
    }

    static func sprachpost(_ alle: [ChatModell.Nachricht], von partner: Person) -> [ChatModell.Nachricht] {
        alle.filter { $0.von == partner && istSprachpost($0) }
    }

    /// Neu = nach dem Zeitpunkt, an dem der Briefkasten (bzw. das Telefon) zuletzt geöffnet wurde.
    static func neu(_ post: [ChatModell.Nachricht], seit: Date) -> Int {
        post.filter { $0.zeit > seit }.count
    }

    /// Brieftext ohne den Kopf, den das Profil beim Schreiben davorsetzt.
    static func lesetext(_ n: ChatModell.Nachricht) -> String {
        let text = n.text ?? ""
        return text.hasPrefix(briefKopf) ? String(text.dropFirst(briefKopf.count)) : text
    }

    static func briefText(_ eingabe: String) -> String? {
        let t = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : briefKopf + t
    }
}
