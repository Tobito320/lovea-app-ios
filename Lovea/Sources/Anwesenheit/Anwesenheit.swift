import CoreLocation
import CoreMotion
import Foundation
import Intents
import UIKit

/// Z-7.1: collects every own live-state source (app activity, battery, focus, motion, place, time
/// of day, mood, special days) and folds them, via `FigurZustand.bestimmen`, into ONE `zustand`
/// broadcast to the partner — throttled to at most 1/s and only sent when it actually changed.
@MainActor
final class Anwesenheit {
    static let shared = Anwesenheit()

    private static let appGruppe: Set<FigurZustand> = [
        .imChat, .tippt, .kamera, .sprache, .liest, .schautBild, .schautVideo, .zeichnet, .karte, .spielt,
    ]

    private var appAktivitaet: FigurZustand?
    private var akku: Double?
    private var laedt = false
    private var fokus: String?
    private var bewegung: FigurZustand?
    private var morgenGeoeffnet = false
    private var supermarktName: String?
    /// Brief G fix 2: last real movement (steps or walking/running/cycling), for `SchlafLogik`.
    private var letzteBewegung: Date?
    /// Brief G bugfix: on a train rather than in a car (`AnwesenheitEingabe.zug`).
    private var imZug = false
    private var schnellSeit: Date?

    private var letzterZustand: FigurenModell.Zustand?
    private var letzterVersand = Date.distantPast
    private var anstehend: Task<Void, Never>?

    private let motion = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private var fokusAutorisiert = false

    /// Every pedometer update means the step count rose. `nonisolated`, so the handler CoreMotion
    /// calls on its own queue isn't a main-actor closure; `gelaufen` hops over itself.
    private nonisolated static func schritteBeobachten(_ pedometer: CMPedometer, gelaufen: @escaping @Sendable () -> Void) {
        pedometer.startUpdates(from: Date()) { daten, _ in
            if daten != nil { gelaufen() }
        }
    }

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        akkuAktualisieren()

        let center = NotificationCenter.default
        center.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.akkuAktualisieren() }
        }
        center.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.akkuAktualisieren() }
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.app(nil) }
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.morgenPruefen()
                self?.fokusAktualisieren()
            }
        }

        if CMMotionActivityManager.isActivityAvailable() {
            motion.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity else { return }
                // Extract primitives before the actor hop — `CMMotionActivity` itself isn't worth
                // betting on being `Sendable` without a local compiler to check (same reasoning as
                // `Standort.locationManager(_:didUpdateLocations:)`).
                let automotive = activity.automotive
                let cycling = activity.cycling
                let running = activity.running
                let walking = activity.walking
                Task { @MainActor in
                    // Walking, running or cycling (starting or just ending) wakes the sleep rule.
                    if walking || running || cycling || self?.bewegung != nil { self?.letzteBewegung = Date() }
                    let neu = AnwesenheitEingabe.bewegung(automotive: automotive, cycling: cycling, running: running, walking: walking)
                    // Starting or stopping a walk or a trip likely means arriving or leaving: ask for a
                    // fix now instead of waiting up to 3 min for the next one (one-shot, cheap).
                    if neu != self?.bewegung { Standort.shared.fixAnfordern(dringend: neu == .faehrt) }
                    self?.bewegung = neu
                    self?.aktualisieren()
                }
            }
        }
        if CMPedometer.isStepCountingAvailable() {
            Self.schritteBeobachten(pedometer) { [weak self] in
                Task { @MainActor in self?.letzteBewegung = Date() }
            }
        }

        morgenPruefen()
        Task { @MainActor [weak self] in await self?.fokusAutorisieren() }

        // ponytail: no push signal for place/mood/special-day-rollover — a light 30s nudge covers
        // slow-moving inputs (arriving somewhere, midnight badge rollover) without a dedicated
        // observer wired into every source. Upgrade: react to OrteModell/KalenderModell changes directly.
        Task { @MainActor [weak self] in
            while let self {
                await self.ortAktualisieren()
                self.aktualisieren()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: - App activity (from `FigurenModell.zustandSenden`)

    /// `nil` or `.ruhig` clears the app slot (a screen left); any other App-group value sets it.
    /// Anything outside the App group (e.g. a mood hint from `WieGehtsDirCard`) is ignored here —
    /// mood/need come straight from `KalenderModell` in `eingabe(_:)` instead.
    func app(_ z: FigurZustand?) {
        if z == nil || z == .ruhig {
            appAktivitaet = nil
        } else if let z, Self.appGruppe.contains(z) {
            appAktivitaet = z
        } else {
            return
        }
        aktualisieren()
    }

    // MARK: - Battery (Z-7.1)

    private func akkuAktualisieren() {
        akku = UIDevice.current.batteryLevel >= 0 ? Double(UIDevice.current.batteryLevel) : nil
        laedt = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        aktualisieren()
    }

    // MARK: - Focus (`INFocusStatusCenter`, Z-7.1)

    // ponytail: unsure whether iOS 26 also offers an async `requestAuthorization()` overload — the
    // completion-handler shape has existed since iOS 15, so that's what this uses (no local
    // compiler to check a newer one). Focus itself is polled (30s nudge + didBecomeActive) rather
    // than trusting a guessed live-change notification name, for the same reason.
    private func fokusAutorisieren() async {
        guard INFocusStatusCenter.default.authorizationStatus == .notDetermined else {
            fokusAutorisiert = INFocusStatusCenter.default.authorizationStatus == .authorized
            fokusAktualisieren()
            return
        }
        await withCheckedContinuation { fortsetzen in
            INFocusStatusCenter.default.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.fokusAutorisiert = status == .authorized
                    self?.fokusAktualisieren()
                    fortsetzen.resume()
                }
            }
        }
    }

    private func fokusAktualisieren() {
        guard fokusAutorisiert else { fokus = nil; return }
        let isFocused = INFocusStatusCenter.default.focusStatus.isFocused ?? false
        let stunde = Calendar.berlin.component(.hour, from: Date())
        fokus = AnwesenheitEingabe.fokus(isFocused: isFocused, stunde: stunde)
        aktualisieren()
    }

    // MARK: - Morning (first foreground 5–11 Uhr Berlin, once a day; Spec 4.3)

    private func morgenPruefen() {
        let heute = Datum.text(Date())
        let schluessel = "lovea.anwesenheit.morgen"
        guard UserDefaults.standard.string(forKey: schluessel) != heute else { return }
        guard AnwesenheitEingabe.istMorgenFenster(Calendar.berlin.component(.hour, from: Date())) else { return }
        UserDefaults.standard.set(heute, forKey: schluessel)
        morgenGeoeffnet = true
        aktualisieren()
    }

    // MARK: - Place (`OrteModell` + `Standort`, Apple-Maps-POI as a fallback; Z-7.1)

    private func ortAktualisieren() async {
        guard let ich = Raum.shared.ich, ortAusGespeichertenPlaetzen(ich) == nil,
              let position = Standort.shared.positionen[ich] else { supermarktName = nil; return }
        supermarktName = await OrtePOI.shared.supermarktName(lat: position.lat, lon: position.lon)
    }

    private func ortAusGespeichertenPlaetzen(_ ich: Person) -> FigurZustand? {
        guard let position = Standort.shared.positionen[ich] else { return nil }
        return OrteModell.shared.orte.first {
            $0.person == ich && CLLocation(latitude: $0.lat, longitude: $0.lon)
                .distance(from: CLLocation(latitude: position.lat, longitude: position.lon)) <= $0.radius
        }.flatMap { FigurZustand(rawValue: $0.kategorie) }
    }

    /// A place only while really there (no region exit events: `OrteModell.monitorAn` stays off).
    /// The last fix decides the place, so a fast or driving fix, or walking well after it, ends it.
    private func ortZustand(_ ich: Person) -> FigurZustand? {
        guard let ort = ortAusGespeichertenPlaetzen(ich) ?? (supermarktName != nil ? .supermarkt : nil) else { return nil }
        let fix = Standort.shared.positionen[ich]
        let gilt = AnwesenheitEingabe.ortGilt(
            ort, tempo: fix?.tempo, bewegung: bewegung, fixZeit: fix.flatMap { Standort.isoFormat.date(from: $0.zeit) },
            letzteBewegung: letzteBewegung
        )
        return gilt ? ort : nil
    }

    /// Called by `Standort` on every own fix, so a place ends with the fix that leaves it.
    /// Re-decide the own state right away (e.g. after a "Gute Nacht" / "Guten Morgen").
    func anstossen() { aktualisieren() }

    func standortNeu() {
        Task { @MainActor [weak self] in
            await self?.ortAktualisieren()
            self?.aktualisieren()
        }
    }

    // MARK: - Fold and send (Z-7.1/Z-7.2)

    private func eingabe(_ ich: Person) -> FigurEingabe {
        let heute = Datum.text(Date())
        let kalender = KalenderModell.shared.zustand
        let stimmung = kalender.stimmungen[heute]?[ich]
        let gestern = Datum.addTage(heute, -1)
        let monat = String(heute.prefix(7))
        return FigurEingabe(
            person: ich,
            app: appAktivitaet,
            ort: ortZustand(ich),
            bewegung: imZug ? .zug : AnwesenheitEingabe.reise(bewegung, tempo: Standort.shared.positionen[ich]?.tempo, fixAlter: Standort.shared.positionen[ich]?.sekundenAlt),
            akku: akku,
            laedt: laedt,
            // ponytail: own connectivity is irrelevant here — `Raum.fluechtig` drops `fl` silently
            // while offline, so this only ever reaches the partner while we ARE online.
            online: true,
            fokus: fokus,
            morgenGeoeffnet: morgenGeoeffnet,
            stimmung: stimmung?.stimmung,
            brauche: stimmung?.brauche,
            jahrestag: kalender.jahrestag.map(Datum.datum),
            dateHeute: kalender.daten.treffen.contains { $0.datum == heute },
            puenktlich: kalender.puenktlich[gestern]?[ich.partner],
            monatsKrone: Puenktlich.monatsKrone(ops: KalenderModell.shared.alleOps, monat: monat) == ich,
            guteNacht: FigurenModell.shared.gruss[ich]?.nacht,
            gutenMorgen: FigurenModell.shared.gruss[ich]?.morgen,
            letzteBewegung: letzteBewegung,
            zuhauseBekannt: OrteModell.shared.orte.contains { $0.person == ich && $0.kategorie == "zuhause" }
        )
    }

    private func aktualisieren() {
        guard let ich = Raum.shared.ich else { return }
        let fix = Standort.shared.positionen[ich]
        let frisch = (fix?.sekundenAlt ?? .infinity) < 180
        (imZug, schnellSeit) = AnwesenheitEingabe.zug(
            bisher: imZug, reist: AnwesenheitEingabe.reise(bewegung, tempo: fix?.tempo, fixAlter: fix?.sekundenAlt) == .faehrt,
            schnell: frisch && (fix?.tempo ?? 0) > AnwesenheitEingabe.zugTempo, schnellSeit: schnellSeit, jetzt: Date()
        )
        let (haupt, abzeichen) = FigurZustand.bestimmen(eingabe(ich))
        let neu = FigurenModell.Zustand(haupt: haupt, abzeichen: abzeichen)
        guard neu != letzterZustand else { return }
        // Sent as soon as it changes, at most every 3 s (a burst of changes goes out as one).
        let wartezeit = 3 - Date().timeIntervalSince(letzterVersand)
        guard wartezeit > 0 else { senden(neu); return }
        guard anstehend == nil else { return }
        anstehend = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(wartezeit))
            self?.anstehend = nil
            self?.aktualisieren()
        }
    }

    private func senden(_ z: FigurenModell.Zustand) {
        letzterZustand = z
        letzterVersand = Date()
        FigurenModell.shared.zustandVeroeffentlichen(z)
    }
}

/// Pure mapping helpers, kept free of `Raum`/CoreMotion/Intents types so they're testable without
/// device APIs — see `AnwesenheitTests.swift`.
enum AnwesenheitEingabe {
    /// Spec 4.3: Fokus an und 22–7 Uhr ergibt „schläft“, sonst „nicht stören“; Fokus aus ergibt nichts.
    static func fokus(isFocused: Bool, stunde: Int) -> String? {
        guard isFocused else { return nil }
        return istNachtstunde(stunde) ? "schlafen" : "nichtStoeren"
    }

    static func istNachtstunde(_ stunde: Int) -> Bool { stunde >= 22 || stunde < 7 }

    /// Core-Motion-Priorität wie `Standort.bewegungsart`: automotive > cycling > running > walking.
    static func bewegung(automotive: Bool, cycling: Bool, running: Bool, walking: Bool) -> FigurZustand? {
        if automotive { return .faehrt }
        if cycling { return .rad }
        if running { return .rennt }
        if walking { return .laeuft }
        return nil
    }

    static func istMorgenFenster(_ stunde: Int) -> Bool { (5..<11).contains(stunde) }

    /// Faster than this (m/s, ~22 km/h) is a vehicle, whatever CoreMotion says.
    static let reiseTempo: Double = 6

    /// A fresh fix (under 3 min) at vehicle speed counts as `faehrt` (train, bus, car).
    static func reise(_ bewegung: FigurZustand?, tempo: Double?, fixAlter: TimeInterval?) -> FigurZustand? {
        if let tempo, tempo > reiseTempo, (fixAlter ?? .infinity) < 180 { return .faehrt }
        return bewegung
    }

    /// Faster than this (m/s, ~80 km/h) for a minute is a train.
    static let zugTempo: Double = 22

    /// CoreMotion's "automotive" can't tell a car from a train. Fast (`schnell`: a fresh fix above
    /// `zugTempo`) for a minute or more makes it a train, and it stays one through stations until
    /// the trip ends (`reist` false).
    static func zug(bisher: Bool, reist: Bool, schnell: Bool, schnellSeit: Date?, jetzt: Date) -> (zug: Bool, schnellSeit: Date?) {
        guard reist else { return (false, nil) }
        let seit = schnell ? (schnellSeit ?? jetzt) : schnellSeit
        let lange = schnell && jetzt.timeIntervalSince(seit ?? jetzt) >= 60
        return (bisher || lange, seit)
    }

    /// Whether the place `ort` the last fix sits in still holds: not at vehicle speed, not driving
    /// or cycling now, and no walking more than 3 min after that fix (then they left and no newer
    /// fix has come in yet). Home is exempt from the walking rule: people walk around at home
    /// and fixes there are rare, and sleep needs it.
    static func ortGilt(_ ort: FigurZustand, tempo: Double?, bewegung: FigurZustand?, fixZeit: Date?, letzteBewegung: Date?) -> Bool {
        if let tempo, tempo > reiseTempo { return false }
        if bewegung == .faehrt || bewegung == .rad { return false }
        if ort != .zuhause, let fixZeit, let letzteBewegung, letzteBewegung.timeIntervalSince(fixZeit) > 180 { return false }
        return true
    }
}
