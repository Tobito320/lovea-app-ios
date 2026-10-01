import Foundation
import os

/// Launch-/Absturz-Protokoll (Build 78, Ahmed: Absturzverdacht Build 76/77 — kein eindeutiger Befund
/// in keinem Diff, keine Absturz-/JetsamEvent-Logs auf dem Gerät, der Prozess also vermutlich vom
/// System getötet statt sauber abgestürzt). Jede `marke` hängt eine Zeile
/// "<ms> <stufe> [main|bg] mem=<MB>MB" an eine feste Liste und schreibt die GANZE Liste synchron
/// nach UserDefaults — der Prozess kann direkt danach sterben.
///
/// `liste`/`sperre`: in-memory statt bei jedem Aufruf aus UserDefaults neu zu lesen (die Liste bleibt
/// klein). `marke` läuft sowohl vom MainActor (SwiftUI-Code) als auch `nonisolated`
/// (`EssenLive`/`GymLive.anwenden` laufen auf dem Kooperativ-Pool, `Herzschlag` auf einer eigenen
/// Queue) — deshalb eine Klasse mit `NSLock` statt ungeschütztem `nonisolated(unsafe) static var`,
/// wie auch anderswo im Projekt (`LebensmittelIndex`).
final class StartProtokoll: @unchecked Sendable {
    static let shared = StartProtokoll()
    private let sperre = NSLock()
    private var liste: [String] = []
    /// `unsauberZaehlen()` darf nur einmal pro Prozess zählen (Vordergrund-`didFinishLaunching`
    /// UND späteres Szene-Connect können beide feuern) — dieses Flag lebt nur im Speicher, ist also
    /// automatisch pro Prozess frisch.
    private var zaehlerErhoehtDiesenProzess = false
    private let start = Date()
    private init() {}

    /// Herzschlag schreibt alle 500 ms für bis zu 30 s — großzügig genug, dass die Launch-Stufen
    /// davor nicht sofort rausfallen.
    private static let maxEintraege = 200
    private static let breadcrumbsSchluessel = "start.breadcrumbs"
    private static let vorherSchluessel = "start.vorher"
    private static let sauberSchluessel = "start.sauber"
    private static let szeneSchluessel = "start.szeneErreicht"
    private static let zaehlerSchluessel = "start.unsauber.zaehler"
    private static let alteStufeSchluessel = "start.stufe" // Build 77: altes Einzel-Feld.

    /// Dreht die Liste für einen neuen Prozessstart: alte Liste nach `start.vorher`, neue Liste leer.
    /// Entscheidet NUR, ob der Absturz-Bericht angezeigt wird (vorige Szene erreicht, nie `sauber()`)
    /// — der Sicherheitsmodus-Zähler hängt NICHT mehr daran, siehe `unsauberZaehlen()`: Ahmed
    /// berichtet, die App stirbt oft VOR jeder UI, ein "Szene erreicht"-Gate hätte den Zähler dann
    /// nie erhöht und der Sicherheitsmodus nie ausgelöst.
    @discardableResult
    static func neuerStart() -> Bool {
        let d = UserDefaults.standard
        let warSzene = d.bool(forKey: szeneSchluessel)
        let warSauber = d.bool(forKey: sauberSchluessel)
        let vorherCrash = warSzene && !warSauber
        if let bisher = d.stringArray(forKey: breadcrumbsSchluessel), !bisher.isEmpty {
            d.set(bisher, forKey: vorherSchluessel)
        }
        d.set([String](), forKey: breadcrumbsSchluessel)
        d.set(false, forKey: sauberSchluessel)
        d.set(false, forKey: szeneSchluessel)
        d.synchronize()
        shared.sperre.withLock { shared.liste = []; shared.zaehlerErhoehtDiesenProzess = false }
        return vorherCrash
    }

    /// R3 (Coordinator-Korrektur, Ahmed): zählt einen Start direkt, statt auf eine erreichte Szene
    /// zu warten — ruft `LoveaAppDelegate.didFinishLaunching` auf, wenn `UIApplication.shared.
    /// applicationState != .background` (Nutzer hat die App wirklich geöffnet), UND `LoveaApp`s
    /// Szene-`onAppear` (deckt einen Start ab, der im Hintergrund begann — Silent-Push/HealthKit —
    /// und erst danach in den Vordergrund geholt wird). Höchstens EINMAL pro Prozess (Flag oben) und
    /// sofort synchronisiert: der Prozess kann binnen Millisekunden sterben.
    static func unsauberZaehlen() {
        let schonGezaehlt = shared.sperre.withLock { () -> Bool in
            if shared.zaehlerErhoehtDiesenProzess { return true }
            shared.zaehlerErhoehtDiesenProzess = true
            return false
        }
        guard !schonGezaehlt else { return }
        let d = UserDefaults.standard
        d.set(d.integer(forKey: zaehlerSchluessel) + 1, forKey: zaehlerSchluessel)
        d.synchronize()
    }

    static func marke(_ stufe: String) {
        let ms = Int(Date().timeIntervalSince(shared.start) * 1000)
        let ort = Thread.isMainThread ? "main" : "bg"
        let memMB = os_proc_available_memory() / (1024 * 1024)
        let zeile = "\(ms) \(stufe) [\(ort)] mem=\(memMB)MB"
        let liste: [String] = shared.sperre.withLock {
            shared.liste.append(zeile)
            if shared.liste.count > maxEintraege { shared.liste.removeFirst(shared.liste.count - maxEintraege) }
            return shared.liste
        }
        let d = UserDefaults.standard
        d.set(liste, forKey: breadcrumbsSchluessel)
        d.synchronize()
    }

    /// Irgendeine UI sichtbar geworden — Voraussetzung dafür, dass ein fehlendes `sauber()`
    /// überhaupt als Absturz zählt (siehe `neuerStart`).
    static func szeneErreicht() {
        let d = UserDefaults.standard
        d.set(true, forKey: szeneSchluessel)
        d.synchronize()
    }

    /// Lauf sauber beendet (Szene in den Hintergrund): kein Absturz, Sicherheitsmodus-Zähler zurück.
    static func sauber() {
        let d = UserDefaults.standard
        d.set(true, forKey: sauberSchluessel)
        d.set(0, forKey: zaehlerSchluessel)
        d.synchronize()
    }

    /// 5 s sichtbar ohne Absturz: Zähler zurück, ohne auf `.background` zu warten.
    static func zaehlerZuruecksetzenNachSichtbar() {
        let d = UserDefaults.standard
        d.set(0, forKey: zaehlerSchluessel)
        d.synchronize()
    }

    static var abgesichert: Bool { UserDefaults.standard.integer(forKey: zaehlerSchluessel) >= 2 }

    static func vorherigeListe() -> [String] { UserDefaults.standard.stringArray(forKey: vorherSchluessel) ?? [] }

    /// Das alte Einzel-Feld aus Build 77 — einmalig lesen und löschen, damit Ahmeds letzter
    /// Build-77-Stand noch in den ersten Build-78-Bericht kommt.
    static func alteStufeEinmalLesen() -> String? {
        let d = UserDefaults.standard
        guard let stufe = d.string(forKey: alteStufeSchluessel), !stufe.isEmpty, stufe != "fertig" else { return nil }
        d.removeObject(forKey: alteStufeSchluessel)
        return stufe
    }
}
