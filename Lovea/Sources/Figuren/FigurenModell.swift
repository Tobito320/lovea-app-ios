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
    /// audit-szene #4: when the CURRENT `zustand[p]` value was truly sent, per the server's `seit`
    /// (see `zustandSeitAusPayload`) — lets `partnerZustandVerfallenLassen` tell a genuinely frozen
    /// state from a fresh one, even across our own reconnects/relaunches that just replay it again.
    private var zustandSeit: [Person: Date] = [:]
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
    /// Z-27.1 / Brief G fix: newest "Gute Nacht" and "Guten Morgen" per person; `Anwesenheit` feeds
    /// the own ones into the one sleep decision (`SchlafLogik`), the partner shares the result.
    private(set) var gruss: [Person: (nacht: Date?, morgen: Date?)] = [:]

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
            var g = gruss[op.von] ?? (nacht: nil, morgen: nil)
            if art == "nacht" { g.nacht = max(g.nacht ?? .distantPast, op.zeit) }
            if art == "morgen" { g.morgen = max(g.morgen ?? .distantPast, op.zeit) }
            gruss[op.von] = g
        }
        raum.fluechtigBeobachten("zustand") { [weak self] person, data in
            guard let self, let z = try? JSONDecoder().decode(Zustand.self, from: data) else { return }
            // audit-szene #4: the server rides a `seit` timestamp along with `d` (both on a live
            // broadcast and a reconnect replay, `raum.js` `#flVerarbeiten`/`webSocketOpen`) — when
            // THIS exact value was truly sent, not when we happened to receive it. Trusting it (over
            // a local receive-time stamp) is what makes a replay of an old "schläft" on OUR OWN
            // reconnect not look fresh. `seit` is missing only for a merker row written before this
            // field existed; the equality check is a one-time bridge for that.
            if let seit = Self.zustandSeitAusPayload(data) {
                self.zustandSeit[person] = seit
            } else if self.zustand[person] != z {
                self.zustandSeit[person] = Date()
            }
            self.zustand[person] = z
            self.partnerZustandVerfallenLassen()
        }
        // ponytail: polling instead of reacting to a `da` edge — `Raum` exposes `partnerDa` as a
        // plain property, not an event stream. 10s granularity is plenty for a "vor X Minuten" label.
        Task { @MainActor [weak self] in
            while let self {
                if raum.partnerDa, let partner = raum.ich?.partner { self.partnerZuletztGesehen[partner] = Date() }
                self.partnerZustandVerfallenLassen()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    /// audit-szene #4: "schläft"/"sitzt im Bett" stuck forever once the partner's phone goes
    /// silently offline (no clean disconnect, so `partnerDa` above never flips false either) — the
    /// sleeper's own phone would eventually re-decide and resend, but it's the one that's offline.
    /// Falls back to `.offline` once the SAME state has sat unchanged past a sensible limit and it's
    /// no longer plausible night. Only the partner, never `ich` (whose own device is right here).
    private func partnerZustandVerfallenLassen() {
        guard let partner = Raum.shared.ich?.partner, let z = zustand[partner],
              z.haupt == .schlaeft || z.haupt == .sitztImBett,
              SchlafLogik.partnerZustandAbgelaufen(seit: zustandSeit[partner], jetzt: Date())
        else { return }
        zustand[partner] = Zustand(haupt: .offline, abzeichen: z.abzeichen, detail: z.detail)
    }

    /// audit-szene #4: pulls the server's `seit` (ISO8601 with fractional seconds, `Date().toISOString()`
    /// on the server) out of the SAME raw `d` payload `Zustand` above decodes — an unknown key
    /// `Zustand`'s own `Codable` conformance silently ignores.
    private struct ZustandZeitHuelle: Decodable { let seit: String? }
    // MainActor-isolated through this @MainActor class, same as every other stored property here —
    // no nonisolated(unsafe) (common.md).
    private static let isoFraktional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static func zustandSeitAusPayload(_ data: Data) -> Date? {
        guard let seit = try? JSONDecoder().decode(ZustandZeitHuelle.self, from: data).seit else { return nil }
        return isoFraktional.date(from: seit)
    }

    /// Z-7.2: "zuletzt online vor …" for the offline figure, `nil` before the partner was ever seen.
    func zuletztOnlineText(_ p: Person) -> String? {
        guard let zeit = partnerZuletztGesehen[p] else { return nil }
        return "zuletzt online \(ZeitText.relativ(zeit))"
    }

    /// Falls back to the Bitmoji look (Z-38.4) for whoever never sent an own `figur.aussehen`.
    /// Stamps `person` so the drawing knows whose figure it is (gym look).
    func aussehen(_ p: Person) -> FigurAussehen {
        var a = aussehen[p] ?? .standard(for: p)
        a.person = p
        return a
    }

    /// What to draw for a person right now: fresh gesture > "Gute Nacht" override > live state > offline.
    func anzeige(_ p: Person) -> Zustand {
        if let g = geste[p], g.bis > Date() { return Zustand(haupt: g.art) }
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
        guard let ich = Raum.shared.ich else { return }
        // Runde-3 expressions: the own figure makes the face too, for the same 4 s.
        if let z = FigurZustand(rawValue: art), FigurZustand.mimik.contains(z) {
            geste[ich] = (z, Date().addingTimeInterval(4))
            return
        }
        guard art == "kuss" else { return }
        geste[ich] = (.kuss, Date().addingTimeInterval(4))
        letzterKuss[ich] = Date()
        kussEreignis += 1
    }

    /// Z-27.1: "Gute Nacht"/"Guten Morgen" (`gruss {art}`, schnittstellen.md) — own figure state,
    /// sweet push for the partner (server: `regeln.js` `grussRegel`).
    func grussSenden(_ art: String) {
        Raum.shared.senden("gruss", GrussPayload(art: art))
        // The op folds locally right away; re-decide sleep now, not on the next 30 s tick.
        Anwesenheit.shared.anstossen()
    }

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
