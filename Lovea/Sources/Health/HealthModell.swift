import Foundation
import HealthKit
import Observation
import UIKit

/// Folds `schritte.setzen`, `schlaf.setzen`, `habit.setzen` and the `ziel.*` keys of
/// `einstellung.setzen` (Z-20.1, Z-20.2) and owns the HealthKit side (steps + sleep, read-only).
/// Was `Schritte/SchritteModell` — moved and extended into Health per the Zielplan. Authorization is
/// requested only once ever, from `sicherstellen()` (called by the Health tab's `onAppear`); the
/// HealthKit observers themselves are (re)started on every launch via `beobachtenStartenFallsErlaubt()`
/// (from `LoveaApp.starten`, AFTER `Raum.shared.start()`) without prompting — required so background
/// delivery keeps working across relaunches, including ones iOS triggers in the background.
@MainActor
@Observable
final class HealthModell {
    static let shared = HealthModell()

    private(set) var schritte: [Person: [String: TagesEintrag<Int>]] = [:]
    private(set) var gym: [Person: [String: TagesEintrag<Int>]] = [:]
    private(set) var wasser: [Person: [String: TagesEintrag<Int>]] = [:]
    private(set) var schlaf: [Person: [String: (minuten: Int, von: Date, bis: Date)]] = [:]

    private(set) var zielSchritteAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielGymAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielWasserAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielGemeinsamWocheAenderungen: [ZielAenderung] = []

    private let store = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

    private var angewendeteOps: Set<String> = []
    private var beobachterGestartet = false
    private var zuletztGesendetSchritte: (datum: String, anzahl: Int)?
    private var zuletztGesendetUm = Date.distantPast

    private static let angefragtSchluessel = "lovea.health.berechtigungAngefragt"

    private init() {
        Raum.shared.beobachten(["schritte.setzen"]) { [weak self] op in self?.schritteOpAnwenden(op) }
        Raum.shared.beobachten(["schlaf.setzen"]) { [weak self] op in self?.schlafOpAnwenden(op) }
        Raum.shared.beobachten(["habit.setzen"]) { [weak self] op in self?.habitOpAnwenden(op) }
        Raum.shared.beobachten(["einstellung.setzen"]) { [weak self] op in self?.zielOpAnwenden(op) }
    }

    private var heute: String { Datum.text(Date()) }

    // MARK: - Lesen (UI-API)

    func heuteSchritte(_ person: Person) -> Int? { schritte[person]?[heute]?.wert }
    func schritteAm(_ person: Person, _ tag: String) -> Int? { schritte[person]?[tag]?.wert }
    func gymAbgehakt(_ person: Person, _ tag: String) -> Bool { (gym[person]?[tag]?.wert ?? 0) > 0 }
    func wasserAnzahl(_ person: Person, _ tag: String) -> Int { wasser[person]?[tag]?.wert ?? 0 }
    func schlafNacht(_ person: Person, _ tag: String) -> (minuten: Int, von: Date, bis: Date)? { schlaf[person]?[tag] }

    func zielSchritte(_ person: Person? = nil) -> Int {
        HealthLogik.zielAmTag(heute, zielSchritteAenderungen[person ?? Raum.shared.ich ?? .ahmed] ?? [], standard: 10_000)
    }

    func zielGym(_ person: Person? = nil) -> Int {
        HealthLogik.zielAmTag(heute, zielGymAenderungen[person ?? Raum.shared.ich ?? .ahmed] ?? [], standard: 3)
    }

    func zielWasser(_ person: Person? = nil) -> Int {
        HealthLogik.zielAmTag(heute, zielWasserAenderungen[person ?? Raum.shared.ich ?? .ahmed] ?? [], standard: 8)
    }

    /// "Letzter gewinnt" (schnittstellen.md), keine Personen-Historie wie bei den anderen Zielen.
    var zielGemeinsamWoche: Int {
        zielGemeinsamWocheAenderungen.max { ($0.seq ?? .max) < ($1.seq ?? .max) }?.wert ?? 140_000
    }

    // MARK: - Schreiben

    func setzeGym(datum: String, an: Bool) {
        Raum.shared.senden("habit.setzen", HabitD(art: "gym", datum: datum, wert: an ? 1 : 0))
    }

    func setzeWasser(datum: String, anzahl: Int) {
        Raum.shared.senden("habit.setzen", HabitD(art: "wasser", datum: datum, wert: max(0, anzahl)))
    }

    /// `schluessel` ist eines von `ziel.schritte`, `ziel.gym`, `ziel.wasser`, `ziel.gemeinsamWoche`.
    func setzeZiel(_ schluessel: String, _ wert: Int) {
        EinstellungenModell.shared.setzen(schluessel, .number(Double(wert)))
    }

    // MARK: - Ops falten

    private func schritteOpAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(SchritteD.self) else { return }
        HealthFaltung.aufnehmen(&schritte, TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: Datum.text(op.zeit), wert: d.anzahl))
    }

    private func habitOpAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(HabitD.self) else { return }
        let eintrag = TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: Datum.text(op.zeit), wert: d.wert)
        if d.art == "gym" { HealthFaltung.aufnehmen(&gym, eintrag) }
        else if d.art == "wasser" { HealthFaltung.aufnehmen(&wasser, eintrag) }
    }

    private func schlafOpAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(SchlafD.self) else { return }
        guard let von = Self.isoDatum(d.von), let bis = Self.isoDatum(d.bis) else { return }
        schlaf[op.von, default: [:]][d.datum] = (minuten: d.minuten, von: von, bis: bis)
    }

    private func zielOpAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(EinstellungD.self) else { return }
        guard case .number(let zahl) = d.wert else { return }
        let aenderung = ZielAenderung(seq: op.seq, datum: Datum.text(op.zeit), wert: Int(zahl))
        switch d.schluessel {
        case "ziel.schritte": zielSchritteAenderungen[op.von, default: []].append(aenderung)
        case "ziel.gym": zielGymAenderungen[op.von, default: []].append(aenderung)
        case "ziel.wasser": zielWasserAenderungen[op.von, default: []].append(aenderung)
        case "ziel.gemeinsamWoche": zielGemeinsamWocheAenderungen.append(aenderung)
        default: break
        }
    }

    // MARK: - HealthKit

    /// Für den "Health nicht erlaubt"-Hinweis (Z-21.1/Z-21.3, Review-Fokus 4): unterscheidet "noch
    /// nie gefragt" (Knopf soll `sicherstellen()` erneut auslösen) von "schon gefragt, aber keine
    /// Daten" (Knopf soll in die Einstellungen führen — ein zweiter Systemdialog kommt eh nicht mehr).
    var berechtigungAngefragt: Bool { UserDefaults.standard.bool(forKey: Self.angefragtSchluessel) }

    /// Vom `onAppear` des Health-Tabs: fragt die Leseberechtigung höchstens einmal jemals an
    /// (Flag in `UserDefaults`, überlebt Neustarts) — nicht nur einmal pro Prozess.
    func sicherstellen() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !UserDefaults.standard.bool(forKey: Self.angefragtSchluessel) else {
            beobachtenStartenFallsErlaubt()
            return
        }
        UserDefaults.standard.set(true, forKey: Self.angefragtSchluessel)
        Task {
            _ = await berechtigungAnfragen()
            beobachtenStartenFallsErlaubt()
        }
    }

    /// Startet `HKObserverQuery` + Background Delivery erneut, ohne zu fragen — muss bei JEDEM
    /// App-Start laufen (auch einem Hintergrund-Start), sonst bleibt Background Delivery nach
    /// einem Neustart aus. No-op, solange nie erfolgreich `sicherstellen()` aufgerufen wurde.
    func beobachtenStartenFallsErlaubt() {
        guard HKHealthStore.isHealthDataAvailable(), UserDefaults.standard.bool(forKey: Self.angefragtSchluessel), !beobachterGestartet else { return }
        beobachterGestartet = true
        beobachteAenderungen()
    }

    /// `requestAuthorization` meldet nur, ob die Anfrage abgeschlossen wurde, nie ob sie gewährt
    /// wurde (Apples Privacy-Design für Lesezugriffe) — deshalb wird trotzdem versucht zu lesen.
    private func berechtigungAnfragen() async -> Bool {
        await withCheckedContinuation { fortsetzung in
            store.requestAuthorization(toShare: [], read: [stepType, sleepType]) { erfolg, _ in
                fortsetzung.resume(returning: erfolg)
            }
        }
    }

    private func beobachteAenderungen() {
        let schritteAbfrage = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, fertig, _ in
            let fertig = ErledigtBox(fertig)
            Task { @MainActor in
                await Raum.shared.leer() // eigene Replay (aus `init`) muss zuerst durch sein, sonst wirkt jeder Wert "geändert"
                await self?.schritteAktualisierenUndSenden()
                await Self.vorMoeglichemHintergrundNachholen()
                fertig.aufrufen()
            }
        }
        store.execute(schritteAbfrage)
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }

        let schlafAbfrage = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, fertig, _ in
            let fertig = ErledigtBox(fertig)
            Task { @MainActor in
                await Raum.shared.leer()
                await self?.schlafAktualisierenUndSenden()
                await Self.vorMoeglichemHintergrundNachholen()
                fertig.aufrufen()
            }
        }
        store.execute(schlafAbfrage)
        store.enableBackgroundDelivery(for: sleepType, frequency: .hourly) { _, _ in }
    }

    /// Eine Hintergrund-Zustellung von HealthKit weckt die App unabhängig von jeder Push — ohne das
    /// hier würde die frisch eingereihte Op erst beim nächsten Vordergrund-Start rausgehen (gleiche
    /// Überlegung wie bei `LoveaAppDelegate`s Silent-Push-Behandlung).
    private static func vorMoeglichemHintergrundNachholen() async {
        guard UIApplication.shared.applicationState != .active else { return }
        await Raum.shared.nachholenBisFertig()
    }

    private func letzteAchtTage() -> [String] { (0..<8).map { Datum.addTage(heute, -$0) } }

    /// Heute + letzte 7 Tage, nur bei Änderung (Z-20.1).
    private func schritteAktualisierenUndSenden() async {
        guard let ich = Raum.shared.ich else { return }
        for tag in letzteAchtTage() {
            guard let anzahl = await schritteAn(tag), schritte[ich]?[tag]?.wert != anzahl else { continue }
            if tag == heute {
                let vergangen = Date().timeIntervalSince(zuletztGesendetUm)
                guard HealthLogik.sollSchritteSenden(anzahl: anzahl, zuletzt: zuletztGesendetSchritte, heutigerTag: heute, vergangen: vergangen) else { continue }
                zuletztGesendetSchritte = (heute, anzahl)
                zuletztGesendetUm = Date()
            }
            Raum.shared.senden("schritte.setzen", SchritteD(datum: tag, anzahl: anzahl))
        }
    }

    private func schritteAn(_ tag: String) async -> Int? {
        let start = Calendar.berlin.startOfDay(for: Datum.datum(tag))
        let ende = Calendar.berlin.date(byAdding: .day, value: 1, to: start) ?? start
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: ende, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: praedikat, options: .cumulativeSum) { _, ergebnis, _ in
                let summe = ergebnis?.sumQuantity()?.doubleValue(for: .count())
                fortsetzung.resume(returning: summe.map { Int($0) })
            }
            store.execute(abfrage)
        }
    }

    private func schlafAktualisierenUndSenden() async {
        guard let ich = Raum.shared.ich else { return }
        for tag in letzteAchtTage() {
            guard let ergebnis = await schlafAn(tag), schlaf[ich]?[tag]?.minuten != ergebnis.minuten else { continue }
            Raum.shared.senden("schlaf.setzen", SchlafD(datum: tag, minuten: ergebnis.minuten, von: Self.isoText(ergebnis.von), bis: Self.isoText(ergebnis.bis)))
        }
    }

    /// Nacht wird dem Aufwach-Tag zugeordnet (Spec 3.1) — Fenster reicht daher vom Vorabend bis
    /// zum Ende von `tag`, alle Asleep-Intervalle darin werden zusammengefasst (`HealthLogik`) und
    /// nur behalten, wenn das Ende wirklich auf `tag` fällt.
    private func schlafAn(_ tag: String) async -> (minuten: Int, von: Date, bis: Date)? {
        let tagStart = Calendar.berlin.startOfDay(for: Datum.datum(tag))
        guard let fensterStart = Calendar.berlin.date(byAdding: .hour, value: -30, to: tagStart),
              let fensterEnde = Calendar.berlin.date(byAdding: .day, value: 1, to: tagStart)
        else { return nil }
        let praedikat = HKQuery.predicateForSamples(withStart: fensterStart, end: fensterEnde, options: .strictStartDate)
        let samples: [HKCategorySample] = await withCheckedContinuation { fortsetzung in
            let abfrage = HKSampleQuery(sampleType: sleepType, predicate: praedikat, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, ergebnis, _ in
                fortsetzung.resume(returning: (ergebnis as? [HKCategorySample]) ?? [])
            }
            store.execute(abfrage)
        }
        let intervalle = samples
            .filter { Self.asleepWerte.contains($0.value) }
            .map { HealthLogik.SchlafIntervall(von: $0.startDate, bis: $0.endDate) }
        guard let zusammengefasst = HealthLogik.schlafZusammenfassen(intervalle), Datum.text(zusammengefasst.bis) == tag else { return nil }
        return zusammengefasst
    }

    /// UNSICHER (Bericht): `HKCategoryValueSleepAnalysis.allAsleepValues` (iOS 16+) deckt vermutlich
    /// genau diese vier Fälle ab und wäre kürzer — hier stattdessen einzeln aufgezählt, weil das
    /// sicher kompiliert, ohne die exakte Signatur der Sammel-Property zu kennen.
    private static let asleepWerte: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
    ]

    // Fresh formatter per call: ISO8601DateFormatter ist eine Klasse und nicht Sendable (gleiche
    // Begründung wie `Op.isoFormatierer`).
    private static func isoFormatierer(fraktional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fraktional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    private static func isoText(_ datum: Date) -> String { isoFormatierer(fraktional: true).string(from: datum) }

    private static func isoDatum(_ text: String) -> Date? {
        isoFormatierer(fraktional: true).date(from: text) ?? isoFormatierer(fraktional: false).date(from: text)
    }
}

private struct SchritteD: Codable { let datum: String; let anzahl: Int }
private struct SchlafD: Codable { var datum: String; var minuten: Int; var von: String; var bis: String }
private struct HabitD: Codable { var art: String; var datum: String; var wert: Int }
private struct EinstellungD: Codable { var schluessel: String; var wert: JSONValue }

/// HealthKit's observer completion handler is not `Sendable`; calling it from any thread is fine.
private struct ErledigtBox: @unchecked Sendable {
    let aufrufen: () -> Void
    init(_ f: @escaping () -> Void) { aufrufen = f }
}
