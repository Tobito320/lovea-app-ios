import CoreLocation
import CoreMotion
import Foundation
import Observation
import UIKit

/// Payload for the ephemeral `standort` message (schnittstellen.md). `zeit` is ISO 8601 text,
/// matching what the server stores verbatim inside `d` — never `Raum`'s default `Date` coding.
struct StandortDaten: Codable, Sendable, Equatable {
    let lat: Double
    let lon: Double
    let genau: Double
    let tempo: Double?
    let richtung: Double?
    let akku: Double?
    let laedt: Bool
    let bewegung: String?
    let zeit: String
}

/// Always-on location sharing (Z-8.1). Broadcasts the own position as `fl standort` and keeps
/// the partner's (and, after the first fix, the own) last position for the map to read.
/// `start()` is safe to call repeatedly — call it from `KarteTab.task` and once more from
/// `LoveaApp` at launch so sharing runs even while another tab is open (see block-8-report.md).
@MainActor
@Observable
final class Standort: NSObject {
    static let shared = Standort()

    private(set) var positionen: [Person: StandortDaten] = [:]

    private let manager = CLLocationManager()
    private let bewegungsManager = CMMotionActivityManager()
    private var sparTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var live = false
    private var letzteMeldung = Date.distantPast

    private override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        UIDevice.current.isBatteryMonitoringEnabled = true

        Raum.shared.fluechtigBeobachten("standort") { [weak self] person, daten in
            guard let d = try? JSONDecoder().decode(StandortDaten.self, from: daten) else { return }
            self?.positionen[person] = d
        }
        // Live-Modus: an, sobald der Partner die Karte offen hat (auch per stiller Push -
        // die kommt als ganz normale `fl karte.offen` an, kein Sonderfall hier).
        Raum.shared.fluechtigBeobachten("karte.offen") { [weak self] person, daten in
            guard person != Raum.shared.ich else { return }
            guard let an = try? JSONDecoder().decode(KarteOffenD.self, from: daten).an else { return }
            self?.liveSetzen(an)
        }
    }

    /// Idempotent: safe to call from every screen's `.task` and from app launch.
    func start() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startMonitoringSignificantLocationChanges()
            manager.startMonitoringVisits()
            startSparTask()
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    /// Sparbetrieb: alle paar Minuten ein Fix, dazu deutliche Bewegung (signifikante Ortsänderung)
    /// und Besuche (siehe `didVisit`). Läuft nur, so lange der Prozess lebt.
    // ponytail: plain sleeping Task, not a background refresh task — in the background it only
    // keeps running as long as significant-change/visit wakeups keep the process alive. Upgrade
    // path: CLBackgroundActivitySession if that turns out to be too sparse in practice.
    private func startSparTask() {
        guard sparTask == nil else { return }
        sparTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.manager.requestLocation()
                try? await Task.sleep(for: .seconds(180))
            }
        }
    }

    private func liveSetzen(_ an: Bool) {
        guard an != live else { return }
        live = an
        liveTask?.cancel()
        guard an else { liveTask = nil; return }
        liveTask = Task { @MainActor [weak self] in
            // ponytail: unsure of the exact throwing/async shape of `CLLocationUpdate.liveUpdates()`
            // on iOS 26 (no local compiler to check) - see block-8-report.md. `.default` accuracy
            // is used instead of a named high-accuracy configuration for the same reason.
            let ende = Date().addingTimeInterval(600)
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let self, !Task.isCancelled, self.live, Date() < ende else { break }
                    if let ort = update.location { await self.melden(ort) }
                }
            } catch {}
            self?.live = false
        }
    }

    private func melden(_ ort: CLLocation) async {
        await melden(
            lat: ort.coordinate.latitude, lon: ort.coordinate.longitude, genau: ort.horizontalAccuracy,
            tempo: ort.speed, richtung: ort.course, zeit: ort.timestamp
        )
    }

    private func melden(lat: Double, lon: Double, genau: Double, tempo: CLLocationSpeed?, richtung: CLLocationDirection?, zeit: Date) async {
        // Throttle: live mode already paces itself via CLLocationUpdate; this only guards the
        // spar/visit paths from firing twice in the same second.
        guard Date().timeIntervalSince(letzteMeldung) > 2 else { return }
        letzteMeldung = Date()
        let bewegung = await bewegungsart()
        let d = StandortDaten(
            lat: lat, lon: lon, genau: genau,
            tempo: (tempo ?? -1) >= 0 ? tempo : nil,
            richtung: (richtung ?? -1) >= 0 ? richtung : nil,
            akku: UIDevice.current.batteryLevel >= 0 ? Double(UIDevice.current.batteryLevel) : nil,
            laedt: UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full,
            bewegung: bewegung,
            zeit: ISO8601DateFormatter().string(from: zeit)
        )
        if let ich = Raum.shared.ich { positionen[ich] = d }
        Raum.shared.fluechtig("standort", d)
        // Place states end with the fix that leaves the place, not on the next 30 s tick.
        Anwesenheit.shared.standortNeu()
    }

    private func bewegungsart() async -> String? {
        guard CMMotionActivityManager.isActivityAvailable() else { return nil }
        return await withCheckedContinuation { fortsetzen in
            bewegungsManager.queryActivityStarting(from: Date().addingTimeInterval(-30), to: Date(), to: .main) { taetigkeiten, _ in
                let a = taetigkeiten?.last
                if a?.automotive == true { fortsetzen.resume(returning: "faehrt") }
                else if a?.cycling == true { fortsetzen.resume(returning: "rad") }
                else if a?.running == true { fortsetzen.resume(returning: "rennt") }
                else if a?.walking == true { fortsetzen.resume(returning: "laeuft") }
                else { fortsetzen.resume(returning: nil) }
            }
        }
    }
}

private struct KarteOffenD: Codable { let an: Bool }

extension Standort: @preconcurrency CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.start() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Only primitives cross the actor hop below - never the `CLLocation` itself, whose
        // Sendability on iOS 26 isn't worth betting on without a local compiler.
        guard let ort = locations.last else { return }
        let lat = ort.coordinate.latitude
        let lon = ort.coordinate.longitude
        let genau = ort.horizontalAccuracy
        let tempo = ort.speed
        let richtung = ort.course
        let zeit = ort.timestamp
        Task { @MainActor in
            await self.melden(lat: lat, lon: lon, genau: genau, tempo: tempo, richtung: richtung, zeit: zeit)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let lat = visit.coordinate.latitude
        let lon = visit.coordinate.longitude
        let genau = visit.horizontalAccuracy
        // CLVisit sentinels: `.distantPast` means "arrived before monitoring started",
        // `.distantFuture` means "still there". Normalize before anything reads these as real dates.
        let jetzt = Date()
        let ankunft = visit.arrivalDate == .distantPast ? jetzt : visit.arrivalDate
        let verlassen = visit.departureDate == .distantFuture ? nil : visit.departureDate
        Task { @MainActor in
            OrteModell.shared.besuchAufzeichnen(lat: lat, lon: lon, ankunft: ankunft, verlassen: verlassen)
            await self.melden(lat: lat, lon: lon, genau: genau, tempo: nil, richtung: nil, zeit: jetzt)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension StandortDaten {
    var punkt: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }

    /// Age of the fix; `nil` if `zeit` doesn't parse. Texts come from `KarteLogik.alterText`.
    var sekundenAlt: TimeInterval? {
        ISO8601DateFormatter().date(from: zeit).map { Date().timeIntervalSince($0) }
    }

    func meter(bis andere: StandortDaten) -> CLLocationDistance {
        CLLocation(latitude: lat, longitude: lon).distance(from: CLLocation(latitude: andere.lat, longitude: andere.lon))
    }
}
