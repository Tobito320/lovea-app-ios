import Foundation
import Observation

/// Per-person chat settings folded from `einstellung.setzen` (schnittstellen.md: "pro `von`").
/// Only owns the `favoriten` and `hintergrund` keys (Z-5.3/Z-5.4) — other keys (`flamme`,
/// `mitteilungen.*`, `wochenplan.zeiten`, …) belong to other blocks and are ignored here.
/// Not registered anywhere yet: Block 5's report asks the app controller to add
/// `ChatEinstellungen.shared` next to the other folds in `LoveaApp.swift`. Until then this still
/// works standalone — `beobachten` replays full history to any observer as soon as one exists.
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

    enum HintergrundArt: String, Codable, Equatable, Sendable { case farbe, foto, zeichnung }

    struct Hintergrund: Codable, Equatable, Sendable {
        var art: HintergrundArt
        var farbe: RGBAColor?
        var medienId: String?
        var abgedunkelt = false

        static let standard = Hintergrund(art: .farbe, farbe: nil, medienId: nil, abgedunkelt: false)
    }

    private(set) var favoritenProPerson: [Person: [FavoritEintrag]] = [:]
    private(set) var hintergrundProPerson: [Person: Hintergrund] = [:]
    private let registrieren: Bool

    init(registrieren: Bool = true) {
        self.registrieren = registrieren
        guard registrieren else { return }
        Raum.shared.beobachten(["einstellung.setzen"]) { [weak self] op in self?.anwendenEins(op) }
    }

    func anwenden(_ ops: [Op]) { for op in ops { anwendenEins(op) } }

    private func anwendenEins(_ op: Op) {
        guard let schluessel = op.daten(SchluesselHuelle.self)?.schluessel else { return }
        switch schluessel {
        case "favoriten":
            guard let p = op.daten(EinstellungPayload<[FavoritEintrag]>.self) else { return }
            favoritenProPerson[op.von] = p.wert
        case "hintergrund":
            guard let p = op.daten(EinstellungPayload<Hintergrund>.self) else { return }
            hintergrundProPerson[op.von] = p.wert
        default:
            break
        }
    }

    func favoriten(_ ich: Person) -> [FavoritEintrag] { favoritenProPerson[ich] ?? [] }
    func hintergrund(_ ich: Person) -> Hintergrund { hintergrundProPerson[ich] ?? .standard }

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

    func hintergrundSetzen(_ neu: Hintergrund, ich: Person) {
        hintergrundProPerson[ich] = neu
        Raum.shared.senden("einstellung.setzen", EinstellungPayload(schluessel: "hintergrund", wert: neu))
    }
}

/// Generic `einstellung.setzen` wire shape (schnittstellen.md: `{schluessel, wert}`) — `wert`'s
/// type depends on `schluessel`, so decoding always peeks at `schluessel` first via `SchluesselHuelle`.
struct EinstellungPayload<Wert: Codable & Sendable>: Codable, Sendable {
    let schluessel: String
    let wert: Wert
}

private struct SchluesselHuelle: Decodable { let schluessel: String }
