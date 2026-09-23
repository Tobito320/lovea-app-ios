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

    private var letzterZustand: FigurenModell.Zustand?
    private var letzterVersand = Date.distantPast
    private var anstehend: Task<Void, Never>?

    private let motion = CMMotionActivityManager()
    private var fokusAutorisiert = false

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
                    self?.bewegung = AnwesenheitEingabe.bewegung(automotive: automotive, cycling: cycling, running: running, walking: walking)
                    self?.aktualisieren()
                }
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

    private func ortZustand(_ ich: Person) -> FigurZustand? {
        ortAusGespeichertenPlaetzen(ich) ?? (supermarktName != nil ? .supermarkt : nil)
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
            bewegung: bewegung,
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
            monatsKrone: Puenktlich.monatsKrone(ops: KalenderModell.shared.alleOps, monat: monat) == ich
        )
    }

    private func aktualisieren() {
        guard let ich = Raum.shared.ich else { return }
        let (haupt, abzeichen) = FigurZustand.bestimmen(eingabe(ich))
        let neu = FigurenModell.Zustand(haupt: haupt, abzeichen: abzeichen)
        guard neu != letzterZustand else { return }
        let wartezeit = 1 - Date().timeIntervalSince(letzterVersand)
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
}
