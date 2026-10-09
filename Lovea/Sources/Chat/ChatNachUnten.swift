import SwiftUI

/// p66: the round "down" arrow in the open chat. Shown while the list is scrolled away from its
/// bottom; the badge counts partner messages that arrived meanwhile. This is a pure struct on
/// purpose — `NachrichtenListe` is private, and `ChatModell.ungelesen(fuer:)` would sit at 0 here
/// because `leseBestaetigen()` marks messages read as they arrive while the chat is open.
struct ChatNachUnten: Equatable {
    private(set) var amEnde = true
    private(set) var neu = 0
    /// Not before the list was at its bottom once or the user touched it: the first layout pass can
    /// report "not at the end" for a moment before the bottom anchor has settled (no flicker on open).
    private var bereit = false

    var sichtbar: Bool { bereit && !amEnde }

    mutating func lage(amEnde neuAmEnde: Bool) {
        amEnde = neuAmEnde
        if neuAmEnde {
            bereit = true
            neu = 0
        }
    }

    /// The user started to drag the list.
    mutating func nutzerZog() { bereit = true }

    mutating func eingetroffen(vomPartner anzahl: Int) {
        guard sichtbar, anzahl > 0 else { return }
        neu += anzahl
    }

    /// Partner messages among `neue` that count for the badge (own rows, grey system rows and
    /// deleted or hidden game rows do not).
    @MainActor static func vomPartner(_ neue: [ChatModell.Nachricht], ich: Person) -> Int {
        neue.filter { $0.von != ich && $0.system == nil && !$0.geloescht && ChatModell.sichtbar($0) }.count
    }

    /// Badge text: nothing at 0, capped at "99+".
    static func plakette(_ anzahl: Int) -> String? {
        anzahl <= 0 ? nil : (anzahl > 99 ? "99+" : "\(anzahl)")
    }
}

/// 44 pt round button, Material background, one accent (`loveaRose`) for the badge only.
struct ChatNachUntenKnopf: View {
    let neu: Int
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Image(systemName: "chevron.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if let text = ChatNachUnten.plakette(neu) {
                        Text(text)
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.loveaRose, in: Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nach unten")
        .accessibilityValue(neu > 0 ? "\(neu) neue Nachrichten" : "")
    }
}
