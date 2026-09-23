import Foundation
import Observation

/// Looks and live state of both figures. Folds `figur.aussehen` and `geste` ops and the ephemeral `zustand` messages.
/// Every screen that shows a figure reads from here; Block 7 (Anwesenheit) feeds the own state via `zustandSenden`.
@MainActor @Observable
final class FigurenModell {
    static let shared = FigurenModell()

    struct Zustand: Codable, Sendable, Equatable {
        var haupt: FigurZustand
        var abzeichen: [String] = []
        var detail: String?
    }

    private(set) var aussehen: [Person: FigurAussehen] = [:]
    private(set) var zustand: [Person: Zustand] = [:]
    private(set) var geste: [Person: (art: FigurZustand, bis: Date)] = [:]
    /// Counts "herz" gestures per sender for the current Berlin day, for the profile.
    private(set) var herzHeute: [Person: Int] = [:]
    /// Z-24.3: newest `kuss` op per sender, updated on EVERY delivery (live and replay alike, unlike
    /// `geste` above which only tracks the 4s-fresh window) — lets the profile show a missed kiss
    /// once, the next time it's opened.
    private(set) var letzterKuss: [Person: Date] = [:]
    /// Bumped whenever a kiss becomes live-visible (own send, optimistic echo; or a fresh partner
    /// receive) — a plain `Int` is a safe Equatable trigger for SwiftUI without relying on
    /// `FigurZustand`'s `RawRepresentable`-derived `==`.
    private(set) var kussEreignis = 0
    /// Z-7.2: last time the partner was seen (`da`), polled below — for "zuletzt online vor …"
    /// once `partnerDa` goes false. `Raum.partnerDa` itself carries no timestamp.
    private(set) var partnerZuletztGesehen: [Person: Date] = [:]
    /// Set by `BannerZentrale` (Z-7.3): called for a fresh, live `anstupsen`/`kuss`/`herz` from the partner.
    var aufFrischeGeste: ((Person, FigurZustand) -> Void)?
    /// Z-27.1: manual "Gute Nacht"/"Guten Morgen" override, per person -- the value is when it
    /// expires (12h after "nacht", or immediately cleared by a later "morgen"). Read in `anzeige(_:)`
    /// before the live `zustand`, so it wins on every screen (Home, Chat, Karte, Widget) without
    /// each of them touching `Anwesenheit`'s own Focus-derived `fokus` at all.
    private(set) var grussSchlaeft: [Person: Date] = [:]

    private init() {
        let raum = Raum.shared
        raum.beobachten(["figur.aussehen"]) { [weak self] op in
            guard var a = op.daten(FigurAussehen.self) else { return }
            // v1 ops (before Figuren v2) have no v2 keys: fill the new parts from the person's standard.
            if op.daten(V2Kennung.self)?.augenform == nil { a = .ausV1(a, fuer: op.von) }
            self?.aussehen[op.von] = a
        }
        raum.beobachten(["geste"]) { [weak self] op in
            guard let self, let art = op.daten([String: String].self)?["art"] else { return }
            if Calendar.berlin.isDateInToday(op.zeit), art == "herz" { herzHeute[op.von, default: 0] += 1 }
            if art == "kuss", (letzterKuss[op.von] ?? .distantPast) < op.zeit { letzterKuss[op.von] = op.zeit }
            // Only fresh gestures animate; replayed history just counts.
            guard op.von != raum.ich, Date().timeIntervalSince(op.zeit) < 30, let z = FigurZustand(rawValue: art) else { return }
            geste[op.von] = (z, Date().addingTimeInterval(4))
            Herzschlag.geste(art)
            if art == "kuss" { kussEreignis += 1 }
            aufFrischeGeste?(op.von, z)
        }
        raum.beobachten(["gruss"]) { [weak self] op in
            guard let self, let art = op.daten(GrussPayload.self)?.art else { return }
            if art == "nacht" { grussSchlaeft[op.von] = op.zeit.addingTimeInterval(12 * 3600) }
            else { grussSchlaeft.removeValue(forKey: op.von) }
        }
        raum.fluechtigBeobachten("zustand") { [weak self] person, data in
            if let z = try? JSONDecoder().decode(Zustand.self, from: data) { self?.zustand[person] = z }
        }
        // ponytail: polling instead of reacting to a `da` edge — `Raum` exposes `partnerDa` as a
        // plain property, not an event stream. 10s granularity is plenty for a "vor X Minuten" label.
        Task { @MainActor [weak self] in
            while let self {
                if raum.partnerDa, let partner = raum.ich?.partner { self.partnerZuletztGesehen[partner] = Date() }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    /// Z-7.2: "zuletzt online vor …" for the offline figure, `nil` before the partner was ever seen.
    func zuletztOnlineText(_ p: Person) -> String? {
        guard let zeit = partnerZuletztGesehen[p] else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return "zuletzt online \(formatter.localizedString(for: zeit, relativeTo: Date()))"
    }

    func aussehen(_ p: Person) -> FigurAussehen { aussehen[p] ?? .standard(for: p) }

    /// What to draw for a person right now: fresh gesture > "Gute Nacht" override > live state > offline.
    func anzeige(_ p: Person) -> Zustand {
        if let g = geste[p], g.bis > Date() { return Zustand(haupt: g.art) }
        if let bis = grussSchlaeft[p], bis > Date() { return Zustand(haupt: .schlaeft, abzeichen: zustand[p]?.abzeichen ?? []) }
        if p != Raum.shared.ich, !Raum.shared.partnerDa { return Zustand(haupt: .offline, abzeichen: zustand[p]?.abzeichen ?? []) }
        return zustand[p] ?? Zustand(haupt: .ruhig)
    }

    /// Z-24.3: replays a MISSED kiss's live visual once — the profile calls this after comparing
    /// `letzterKuss` against its own "seen" marker (UserDefaults). Reuses the same 4s `geste`
    /// window a fresh receive uses, so the figure/animation code needs no separate "replay" path.
    func kussReplay(_ von: Person) {
        geste[von] = (.kuss, Date().addingTimeInterval(4))
        kussEreignis += 1
    }

    func aussehenSichern(_ a: FigurAussehen) { Raum.shared.senden("figur.aussehen", a) }

    /// Z-24.3: for "kuss" this also echoes optimistically into `geste`/`letzterKuss` — the replay
    /// guard above (`op.von != raum.ich`) intentionally skips the sender's own round-tripped op, so
    /// without this the sender would never see/hear their own profile kiss animation.
    func gesteSenden(_ art: String) {
        Raum.shared.senden("geste", ["art": art])
        guard art == "kuss", let ich = Raum.shared.ich else { return }
        geste[ich] = (.kuss, Date().addingTimeInterval(4))
        letzterKuss[ich] = Date()
        kussEreignis += 1
    }

    /// Z-27.1: "Gute Nacht"/"Guten Morgen" (`gruss {art}`, schnittstellen.md) — own figure state,
    /// sweet push for the partner (server: `regeln.js` `grussRegel`).
    func grussSenden(_ art: String) { Raum.shared.senden("gruss", GrussPayload(art: art)) }

    /// Block 7 (Z-7.1) reinterpretation: screens still call this with their own activity as
    /// `haupt` (`.imChat`, `.tippt`, `.zeichnet`, … or `.ruhig`/`nil` when they leave) — it's now
    /// just an APP-ACTIVITY HINT. `Anwesenheit` merges it with device/place/time/mood and sends the
    /// actual `zustand` via `zustandVeroeffentlichen` below, throttled and only on change.
    func zustandSenden(_ z: Zustand) {
        Anwesenheit.shared.app(z.haupt)
    }

    /// Called by `Anwesenheit` once it folded the full own state — the only place that still
    /// touches `Raum` for `zustand`.
    func zustandVeroeffentlichen(_ z: Zustand) {
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

/// Only present in `figur.aussehen` ops written by Figuren v2.
private struct V2Kennung: Decodable {
    let augenform: Int?
}

private struct GrussPayload: Codable { let art: String }
