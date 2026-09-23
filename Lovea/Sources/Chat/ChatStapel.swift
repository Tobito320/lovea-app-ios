import Foundation

/// Instagram-style photo stacks (Block 18): consecutive photo/video-only messages from one person,
/// each at most 60 s after the previous one, render as one fanned stack. A tray send of several
/// photos is one `nachricht.neu` per photo (wire shape unchanged), so it always lands in one stack.
enum ChatStapel {
    static let fenster: TimeInterval = 60

    struct Gruppe: Identifiable {
        var nachrichten: [ChatModell.Nachricht]
        var id: String { nachrichten[0].id }
        var letzte: ChatModell.Nachricht { nachrichten[nachrichten.count - 1] }
    }

    static func istBild(_ n: ChatModell.Nachricht) -> Bool {
        !n.geloescht && n.snap == nil && (n.text ?? "").isEmpty && n.gif == nil && n.sticker == nil
            && n.spiel == nil && n.system == nil && n.einladung == nil && n.kapsel == nil && n.brief == nil
            && !n.medien.isEmpty && n.medien.allSatisfy { $0.typ == "foto" || $0.typ == "video" }
    }

    /// A reply may start a stack but never join one — its quote label would vanish.
    static func gruppieren(_ nachrichten: [ChatModell.Nachricht]) -> [Gruppe] {
        var gruppen: [Gruppe] = []
        for n in nachrichten {
            if let letzte = gruppen.last?.letzte, istBild(letzte), istBild(n), letzte.von == n.von,
               n.antwortAuf == nil, abs(n.zeit.timeIntervalSince(letzte.zeit)) <= fenster {
                gruppen[gruppen.count - 1].nachrichten.append(n)
            } else {
                gruppen.append(Gruppe(nachrichten: [n]))
            }
        }
        return gruppen
    }
}

/// Status line of the one row on the "Chats" screen, Snapchat vocabulary plus the text itself.
enum ChatVorschau {
    struct Zeile: Equatable {
        let symbol: String
        let text: String
        let neu: Bool
    }

    static func zeile(nachrichten: [ChatModell.Nachricht], ich: Person, gelesenVonPartner: Date?, gelesenVonMir: Date?, partnerTippt: Bool) -> Zeile {
        if partnerTippt { return Zeile(symbol: "ellipsis.bubble.fill", text: "Tippt …", neu: true) }
        guard let letzte = nachrichten.last(where: { !$0.geloescht }) else {
            return Zeile(symbol: "bubble.left", text: "Tippe zum Chatten", neu: false)
        }
        if letzte.von == ich {
            if letzte.snap != nil {
                return letzte.snapAngesehen
                    ? Zeile(symbol: "arrowtriangle.right", text: "Snap geöffnet", neu: false)
                    : Zeile(symbol: "arrowtriangle.right.fill", text: "Snap gesendet", neu: false)
            }
            let geoeffnet = (gelesenVonPartner ?? .distantPast) >= letzte.zeit
            return Zeile(symbol: geoeffnet ? "arrowtriangle.right" : "arrowtriangle.right.fill", text: (geoeffnet ? "Geöffnet · " : "Zugestellt · ") + inhalt(letzte), neu: false)
        }
        if letzte.snap != nil {
            return letzte.snapAngesehen
                ? Zeile(symbol: "square", text: "Snap angesehen", neu: false)
                : Zeile(symbol: "square.fill", text: "Neuer Snap", neu: true)
        }
        let ungelesen = letzte.zeit > (gelesenVonMir ?? .distantPast)
        return Zeile(symbol: ungelesen ? "bubble.left.fill" : "bubble.left", text: inhalt(letzte), neu: ungelesen)
    }

    static func inhalt(_ n: ChatModell.Nachricht) -> String {
        // Z-27.2: der Inhalt einer verschlossenen Zeitkapsel/eines Briefs darf nie als Vorschau,
        // Zitat oder Suchtreffer auftauchen — vor `n.text` geprüft, auch wenn beide gesetzt sind.
        if let kapsel = n.kapsel { return ChatModell.verschlossen(oeffnetAm: kapsel.oeffnetAm) ? "🔒 Zeitkapsel" : "🔓 Zeitkapsel geöffnet" }
        if let brief = n.brief { return "💌 Brief „\(brief.titel)“" }
        if let text = n.text, !text.isEmpty { return text }
        if n.snap != nil { return "Snap" }
        if let einladung = n.einladung { return "Zeichnung „\(einladung.name)“" }
        if let system = n.system { return system }
        if n.gif != nil { return "GIF" }
        if n.sticker != nil { return "Sticker" }
        if n.spiel != nil { return "Spiel" }
        let typ = n.medien.first?.typ
        if typ == "sprache" { return "Sprachnachricht" }
        if typ == "video" { return "Video" }
        if typ == "foto" { return n.medien.count > 1 ? "\(n.medien.count) Fotos" : "Foto" }
        return "Nachricht"
    }
}
