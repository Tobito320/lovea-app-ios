import Foundation
import Observation

/// Looks and live state of both figures. Folds `figur.aussehen` and `geste` ops and the ephemeral `zustand` messages.
/// Every screen that shows a figure reads from here; Block 7 (Anwesenheit) feeds the own state via `zustandSenden`.
@MainActor @Observable
final class FigurenModell {
    static let shared = FigurenModell()

    struct Zustand: Codable, Sendable {
        var haupt: FigurZustand
        var abzeichen: [String] = []
        var detail: String?
    }

    private(set) var aussehen: [Person: FigurAussehen] = [:]
    private(set) var zustand: [Person: Zustand] = [:]
    private(set) var geste: [Person: (art: FigurZustand, bis: Date)] = [:]
    /// Counts "herz" gestures per sender for the current Berlin day, for the profile.
    private(set) var herzHeute: [Person: Int] = [:]

    private init() {
        let raum = Raum.shared
        raum.beobachten(["figur.aussehen"]) { [weak self] op in
            if let a = op.daten(FigurAussehen.self) { self?.aussehen[op.von] = a }
        }
        raum.beobachten(["geste"]) { [weak self] op in
            guard let self, let art = op.daten([String: String].self)?["art"] else { return }
            if Calendar.berlin.isDateInToday(op.zeit), art == "herz" { herzHeute[op.von, default: 0] += 1 }
            // Only fresh gestures animate; replayed history just counts.
            guard op.von != raum.ich, Date().timeIntervalSince(op.zeit) < 30, let z = FigurZustand(rawValue: art) else { return }
            geste[op.von] = (z, Date().addingTimeInterval(4))
            Herzschlag.geste(art)
        }
        raum.fluechtigBeobachten("zustand") { [weak self] person, data in
            if let z = try? JSONDecoder().decode(Zustand.self, from: data) { self?.zustand[person] = z }
        }
    }

    func aussehen(_ p: Person) -> FigurAussehen { aussehen[p] ?? .standard(for: p) }

    /// What to draw for a person right now: fresh gesture > live state > offline.
    func anzeige(_ p: Person) -> Zustand {
        if let g = geste[p], g.bis > Date() { return Zustand(haupt: g.art) }
        if p != Raum.shared.ich, !Raum.shared.partnerDa { return Zustand(haupt: .offline, abzeichen: zustand[p]?.abzeichen ?? []) }
        return zustand[p] ?? Zustand(haupt: .ruhig)
    }

    func aussehenSichern(_ a: FigurAussehen) { Raum.shared.senden("figur.aussehen", a) }
    func gesteSenden(_ art: String) { Raum.shared.senden("geste", ["art": art]) }
    func zustandSenden(_ z: Zustand) {
        if let ich = Raum.shared.ich { zustand[ich] = z }
        Raum.shared.fluechtig("zustand", z)
    }
}

extension Calendar {
    static let berlin: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        c.firstWeekday = 2
        return c
    }()
}
