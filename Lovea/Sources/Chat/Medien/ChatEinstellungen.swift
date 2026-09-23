import Foundation
import Observation

/// Per-person chat settings folded from `einstellung.setzen` (schnittstellen.md: "pro `von`").
/// Only owns the `favoriten` key (Z-5.3) — other keys (`chat.backdrop`, `mitteilungen.*`, …) belong
/// to other folds, and the old per-person `hintergrund` (replaced by the shared backdrop, Z-34.1)
/// is simply ignored now.
@MainActor
@Observable
final class ChatEinstellungen {
    static let shared = ChatEinstellungen()

    /// A favorited GIF or sticker (Z-5.3), whole list per person is replace-on-write — simplest
    /// correct merge for a short list edited from one device at a time.
    // ponytail: no per-item CRDT, last `einstellung.setzen{favoriten}` from a person wins outright.
    struct FavoritEintrag: Codable, Equatable, Sendable, Identifiable {
        enum Art: String, Codable, Equatable, Sendable { case gif, sticker }
        var art: Art
        var wert: String // gif: URL; sticker: medienId
        var breite: Double?
        var hoehe: Double?
        var id: String { "\(art.rawValue):\(wert)" }
    }

    private(set) var favoritenProPerson: [Person: [FavoritEintrag]] = [:]
    private let registrieren: Bool

    init(registrieren: Bool = true) {
        self.registrieren = registrieren
        guard registrieren else { return }
        Raum.shared.beobachten(["einstellung.setzen"]) { [weak self] op in self?.anwendenEins(op) }
    }

    func anwenden(_ ops: [Op]) { for op in ops { anwendenEins(op) } }

    private func anwendenEins(_ op: Op) {
        guard op.daten(SchluesselHuelle.self)?.schluessel == "favoriten",
              let p = op.daten(EinstellungPayload<[FavoritEintrag]>.self) else { return }
        favoritenProPerson[op.von] = p.wert
    }

    func favoriten(_ ich: Person) -> [FavoritEintrag] { favoritenProPerson[ich] ?? [] }

    func favoritSchalten(_ eintrag: FavoritEintrag, ich: Person) {
        var liste = favoriten(ich)
        if let index = liste.firstIndex(where: { $0.id == eintrag.id }) {
            liste.remove(at: index)
        } else {
            liste.append(eintrag)
        }
        favoritenProPerson[ich] = liste // optimistic, matches the echo that follows
        Raum.shared.senden("einstellung.setzen", EinstellungPayload(schluessel: "favoriten", wert: liste))
    }
}

/// Generic `einstellung.setzen` wire shape (schnittstellen.md: `{schluessel, wert}`) — `wert`'s
/// type depends on `schluessel`, so decoding always peeks at `schluessel` first via `SchluesselHuelle`.
struct EinstellungPayload<Wert: Codable & Sendable>: Codable, Sendable {
    let schluessel: String
    let wert: Wert
}

private struct SchluesselHuelle: Decodable { let schluessel: String }
