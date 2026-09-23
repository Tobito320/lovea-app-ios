import Foundation

/// Z-27.3 "Heute vor …" (Spec 8/9): exactly 1 month, 3 months or 1 year ago, a photo/drawing or
/// message from that day — pure selection over `ChatModell.nachrichten`, Europe/Berlin calendar day.
enum HeuteVorLogik {
    enum Zeitraum: CaseIterable, Equatable, Sendable {
        case einMonat, dreiMonate, einJahr

        var titel: String {
            switch self {
            case .einMonat: "Vor 1 Monat"
            case .dreiMonate: "Vor 3 Monaten"
            case .einJahr: "Vor 1 Jahr"
            }
        }

        fileprivate var versatz: DateComponents {
            switch self {
            case .einMonat: DateComponents(month: -1)
            case .dreiMonate: DateComponents(month: -3)
            case .einJahr: DateComponents(year: -1)
            }
        }
    }

    /// First matching offset wins (1 Monat vor 3 Monaten vor 1 Jahr, wie in der Spec-Reihenfolge),
    /// newest message of that day if several qualify.
    /// `dateInterval(of:for:)` once per offset (not `isDate(_:inSameDayAs:)` per message, Z-16.2:
    /// this runs on every Home/Chat-tab render, potentially over 10,000 messages).
    static func auswahl(_ nachrichten: [ChatModell.Nachricht], jetzt: Date = Date()) -> (nachricht: ChatModell.Nachricht, zeitraum: Zeitraum)? {
        for zeitraum in Zeitraum.allCases {
            guard let zielTag = Calendar.berlin.date(byAdding: zeitraum.versatz, to: jetzt),
                  let tagesfenster = Calendar.berlin.dateInterval(of: .day, for: zielTag)
            else { continue }
            if let treffer = nachrichten
                .filter({ tagesfenster.contains($0.zeit) && istKandidat($0) })
                .max(by: { $0.zeit < $1.zeit }) {
                return (treffer, zeitraum)
            }
        }
        return nil
    }

    /// "ein Foto, eine Zeichnung oder eine Nachricht" — an ungelöschte, nicht-System/Spiel-Zeile mit
    /// Text oder einem Foto (eine geteilte Zeichnung kommt als Foto-Medium an, keine eigene Kennung).
    /// Zeitkapseln bleiben bis zur Öffnung draußen; nicht gespeicherte Snaps sind flüchtig.
    private static func istKandidat(_ n: ChatModell.Nachricht) -> Bool {
        guard !n.geloescht, n.system == nil, n.spiel == nil, n.einladung == nil else { return false }
        if let snap = n.snap, !(n.snapGespeichert || snap.bleibt) { return false }
        if n.kapsel != nil, ChatModell.verschlossen(n) { return false }
        let hatFoto = n.medien.contains { $0.typ == "foto" }
        let hatText = !(n.text ?? "").isEmpty
        return hatFoto || hatText
    }
}
