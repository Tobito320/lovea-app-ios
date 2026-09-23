import Foundation
import HealthKit
import Observation
import UIKit

/// Folds `schritte.setzen`, `schlaf.setzen`, the four habit ops (`HabitFaltung`, Z-35.1) and the
/// `ziel.*` keys of `einstellung.setzen` (Z-20.1, Z-20.2), and owns the HealthKit side (steps, km,
/// floors, sleep — read-only). Authorization is requested from `sicherstellen()` (the Health tab's
/// `onAppear`) once per permission set (`angefragtSchluessel`); the HealthKit observers are
/// (re)started on every launch via `beobachtenStartenFallsErlaubt()` (from `AppStart.falten`, already
/// in `didFinishLaunching` — I-7) without prompting, so background delivery survives relaunches.
@MainActor
@Observable
final class HealthModell {
    static let shared = HealthModell()

    private(set) var schritte: [Person: [String: TagesEintrag<Int>]] = [:]
    private(set) var schlaf: [Person: [String: (minuten: Int, von: Date, bis: Date)]] = [:]

    private(set) var zielSchritteAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielGymAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielWasserAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielGemeinsamWocheAenderungen: [ZielAenderung] = []

    /// km and floors of the same `schritte.setzen` op as `schritte` (same `seq`/`id`, so the same
    /// winner per day).
    private var schritteExtras: [Person: [String: TagesEintrag<SchritteExtra>]] = [:]
    private var habitFaltung = HabitFaltung()

    private let store = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let distanzType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    private let etagenType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

    private var angewendeteOps: Set<String> = []
    private var beobachterGestartet = false
    private var nachtragLaeuft = false
    private var zuletztGesendetSchritte: (datum: String, anzahl: Int)?
    private var zuletztGesendetUm = Date.distantPast

    /// Z-36.1: new key, so the prompt appears once more for distance and floors (the Runde-2 flag
    /// `altSchluessel` would block it). Background observers still start on the old flag.
    private static let angefragtSchluessel = "lovea.health.berechtigungAngefragt.v3"
    private static let altSchluessel = "lovea.health.berechtigungAngefragt"
    private static let nachgetragenSchluessel = "lovea.health.schritteNachgetragen.v1"

    /// Für den "Health nicht erlaubt"-Hinweis (Z-21.1/Z-21.3, Review-Fokus 4): unterscheidet "noch
    /// nie gefragt" (Knopf soll `sicherstellen()` erneut auslösen) von "schon gefragt, aber keine
    /// Daten" (Knopf soll in die Einstellungen führen). Gespeichert statt berechnet, damit `@Observable`
    /// den Hinweis-Knopf sofort umschaltet, sobald `sicherstellen()` läuft — ein reiner UserDefaults-
    /// Lesezugriff würde SwiftUI keine Änderung melden.
    private(set) var berechtigungAngefragt = UserDefaults.standard.bool(forKey: HealthModell.angefragtSchluessel)

    private init() {
        Raum.shared.beobachten(["schritte.setzen"]) { [weak self] op in self?.schritteOpAnwenden(op) }
        Raum.shared.beobachten(["schlaf.setzen"]) { [weak self] op in self?.schlafOpAnwenden(op) }
        Raum.shared.beobachten(["habit.setzen", "habit.anlegen", "habit.aendern", "habit.ausblenden"]) { [weak self] op in
            self?.habitFaltung.anwenden(op)
        }
        Raum.shared.beobachten(["einstellung.setzen"]) { [weak self] op in self?.zielOpAnwenden(op) }
    }

    private var heute: String { Datum.text(Date()) }

    // MARK: - Lesen (UI-API)

    func heuteSchritte(_ person: Person) -> Int? { schritte[person]?[heute]?.wert }
    func schritteAm(_ person: Person, _ tag: String) -> Int? { schritte[person]?[tag]?.wert }
    func kmAm(_ person: Person, _ tag: String) -> Double? { schritteExtras[person]?[tag]?.wert.km }
    func etagenAm(_ person: Person, _ tag: String) -> Int? { schritteExtras[person]?[tag]?.wert.etagen }
    func schlafNacht(_ person: Person, _ tag: String) -> (minuten: Int, von: Date, bis: Date)? { schlaf[person]?[tag] }

    /// Every habit incl. Gym and Wasser; `ausgeblendet` = hidden by this device's person.
    var habits: [String: Habit] { habitFaltung.habits(ich: Raum.shared.ich ?? .ahmed) }
    /// Without hidden ones, "ich" habits only for their creator; Gym, Wasser, then creation order.
    func sichtbareHabits(fuer ich: Person) -> [Habit] { habitFaltung.sichtbar(fuer: ich) }
    func habitWert(_ id: String, _ person: Person, _ tag: String) -> Int { habitFaltung.werte[id]?[person]?[tag]?.wert ?? 0 }
    func habitWerte(_ id: String, _ person: Person) -> [String: Int] { (habitFaltung.werte[id]?[person] ?? [:]).mapValues(\.wert) }

    /// The `ziel` for `HabitLogik`: Gym's weekly and Wasser's daily goal per person, `nil` for own habits.
    func habitZiel(_ id: String, _ person: Person) -> Int? {
        switch id {
        case Habit.gym.id: return zielGym(person)
        case Habit.wasser.id: return zielWasser(person)
        default: return nil
        }
    }

    /// Widgets and `PunkteModell` read these two as before — now views on the generic habit storage.
    var gym: [Person: [String: TagesEintrag<Int>]] { habitFaltung.werte[Habit.gym.id] ?? [:] }
    var wasser: [Person: [String: TagesEintrag<Int>]] { habitFaltung.werte[Habit.wasser.id] ?? [:] }
    func gymAbgehakt(_ person: Person, _ tag: String) -> Bool { habitWert(Habit.gym.id, person, tag) > 0 }
    func wasserAnzahl(_ person: Person, _ tag: String) -> Int { habitWert(Habit.wasser.id, person, tag) }

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
    /// Gleichstand (zwei unbestätigte) → die später angekommene (I-2).
    var zielGemeinsamWoche: Int {
        zielGemeinsamWocheAenderungen.enumerated()
            .max { ($0.element.seq ?? .max, $0.offset) < ($1.element.seq ?? .max, $1.offset) }?
            .element.wert ?? 140_000
    }

    // MARK: - Schreiben

    func setzeHabit(_ id: String, datum: String, wert: Int) {
        Raum.shared.senden("habit.setzen", HabitSetzenD(art: id, datum: datum, wert: max(0, wert)))
    }

    func anlegen(_ habit: Habit) { Raum.shared.senden("habit.anlegen", habit) }
    func aendern(_ habit: Habit) { Raum.shared.senden("habit.aendern", habit) }
    func ausblenden(_ id: String, _ aus: Bool) { Raum.shared.senden("habit.ausblenden", HabitAusblendenD(id: id, aus: aus)) }

    func setzeGym(datum: String, an: Bool) { setzeHabit(Habit.gym.id, datum: datum, wert: an ? 1 : 0) }
    func setzeWasser(datum: String, anzahl: Int) { setzeHabit(Habit.wasser.id, datum: datum, wert: anzahl) }

    /// `schluessel` ist eines von `ziel.schritte`, `ziel.gym`, `ziel.wasser`, `ziel.gemeinsamWoche`.
    func setzeZiel(_ schluessel: String, _ wert: Int) {
        EinstellungenModell.shared.setzen(schluessel, .number(Double(wert)))
    }

    // MARK: - Ops falten

    // I-2: no one-shot `angewendeteOps` guard for schritte/habit/ziel — the confirmed echo of an own
    // op must reach the fold to replace its `seq == nil` copy (all folds are idempotent by op id).
    private func schritteOpAnwenden(_ op: Op) {
        guard let d = op.daten(SchritteD.self) else { return }
        let gesendet = Datum.text(op.zeit)
        HealthFaltung.aufnehmen(&schritte, TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: gesendet, wert: d.anzahl, id: op.id, nachgetragen: d.nachgetragen ?? false))
        HealthFaltung.aufnehmen(&schritteExtras, TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: gesendet, wert: SchritteExtra(km: d.km, etagen: d.etagen), id: op.id))
    }

    private func schlafOpAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(SchlafD.self) else { return }
        guard let von = Self.isoDatum(d.von), let bis = Self.isoDatum(d.bis) else { return }
        schlaf[op.von, default: [:]][d.datum] = (minuten: d.minuten, von: von, bis: bis)
    }

    private func zielOpAnwenden(_ op: Op) {
        guard let d = op.daten(EinstellungD.self) else { return }
        guard case .number(let zahl) = d.wert else { return }
        let aenderung = ZielAenderung(seq: op.seq, datum: Datum.text(op.zeit), wert: Int(zahl), id: op.id)
        switch d.schluessel {
        case "ziel.schritte": HealthLogik.zielAufnehmen(&zielSchritteAenderungen[op.von, default: []], aenderung)
        case "ziel.gym": HealthLogik.zielAufnehmen(&zielGymAenderungen[op.von, default: []], aenderung)
        case "ziel.wasser": HealthLogik.zielAufnehmen(&zielWasserAenderungen[op.von, default: []], aenderung)
        case "ziel.gemeinsamWoche": HealthLogik.zielAufnehmen(&zielGemeinsamWocheAenderungen, aenderung)
        default: break
        }
    }

    // MARK: - HealthKit

    /// Vom `onAppear` des Health-Tabs: fragt die Leseberechtigung höchstens einmal pro Berechtigungs-
    /// Satz an (Flag in `UserDefaults`, überlebt Neustarts). Danach bei jedem Erscheinen nur noch der
    /// Nachtrag-Versuch (läuft erst, sobald das Nachholen fertig ist, und dann genau einmal).
    func sicherstellen() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !berechtigungAngefragt else {
            beobachtenStartenFallsErlaubt()
            Task { await nachtragenFallsNoetig() }
            return
        }
        UserDefaults.standard.set(true, forKey: Self.angefragtSchluessel)
        berechtigungAngefragt = true
        Task {
            _ = await berechtigungAnfragen()
            beobachtenStartenFallsErlaubt()
            await nachtragenFallsNoetig()
        }
    }

    /// Startet `HKObserverQuery` + Background Delivery erneut, ohne zu fragen — muss bei JEDEM
    /// App-Start laufen (auch einem Hintergrund-Start), sonst bleibt Background Delivery nach
    /// einem Neustart aus. No-op, solange nie gefragt wurde (weder Runde 2 noch jetzt).
    func beobachtenStartenFallsErlaubt() {
        let jemalsGefragt = berechtigungAngefragt || UserDefaults.standard.bool(forKey: Self.altSchluessel)
        guard HKHealthStore.isHealthDataAvailable(), jemalsGefragt, !beobachterGestartet else { return }
        beobachterGestartet = true
        beobachteAenderungen()
    }

    /// `requestAuthorization` meldet nur, ob die Anfrage abgeschlossen wurde, nie ob sie gewährt
    /// wurde (Apples Privacy-Design für Lesezugriffe) — deshalb wird trotzdem versucht zu lesen.
    private func berechtigungAnfragen() async -> Bool {
        await withCheckedContinuation { fortsetzung in
            store.requestAuthorization(toShare: [], read: [stepType, distanzType, etagenType, sleepType]) { erfolg, _ in
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

    /// Heute + letzte 7 Tage, nur bei Änderung (Z-20.1); km und Etagen reisen mit (Z-36.1).
    // ponytail: only the step observer triggers — distance and floors are written with the steps.
    private func schritteAktualisierenUndSenden() async {
        guard let ich = Raum.shared.ich else { return }
        for tag in letzteAchtTage() {
            guard let neu = await tageswerte(tag) else { continue }
            let extra = schritteExtras[ich]?[tag]?.wert
            guard schritte[ich]?[tag]?.wert != neu.anzahl || extra?.km != neu.km || extra?.etagen != neu.etagen else { continue }
            if tag == heute {
                let vergangen = Date().timeIntervalSince(zuletztGesendetUm)
                guard HealthLogik.sollSchritteSenden(anzahl: neu.anzahl, zuletzt: zuletztGesendetSchritte, heutigerTag: heute, vergangen: vergangen) else { continue }
                zuletztGesendetSchritte = (heute, neu.anzahl)
                zuletztGesendetUm = Date()
            }
            Raum.shared.senden("schritte.setzen", SchritteD(datum: tag, anzahl: neu.anzahl, km: neu.km, etagen: neu.etagen))
        }
        // Not awaited: the observer's completion handler must not wait for 82 days of queries
        // (HealthKit throttles late background deliveries). A suspended run retries, the flag comes last.
        guard UIApplication.shared.applicationState == .active else { return }
        Task { await nachtragenFallsNoetig() }
    }

    /// Z-36.1, Review-Fokus 2: once, the last 90 days of steps as `nachgetragen: true` (display only,
    /// never points or challenges), only days without an own value. Waits for `Raum.nachgeholt`: on
    /// a fresh install the log is empty until the catch-up, and a flagged op would out-`seq` a day
    /// that already earned points. The flag is set only after the loop, so a kill mid-way retries —
    /// already sent days are then in `schritte` and skipped.
    private func nachtragenFallsNoetig() async {
        guard let ich = Raum.shared.ich, Raum.shared.nachgeholt, berechtigungAngefragt, !nachtragLaeuft,
              !UserDefaults.standard.bool(forKey: Self.nachgetragenSchluessel) else { return }
        nachtragLaeuft = true
        defer { nachtragLaeuft = false }
        for tag in HealthLogik.nachtragTage(heute: heute, vorhanden: Set((schritte[ich] ?? [:]).keys)) {
            guard let werte = await tageswerte(tag), schritte[ich]?[tag] == nil else { continue }
            Raum.shared.senden("schritte.setzen", SchritteD(datum: tag, anzahl: werte.anzahl, km: werte.km, etagen: werte.etagen, nachgetragen: true))
        }
        UserDefaults.standard.set(true, forKey: Self.nachgetragenSchluessel)
    }

    /// Steps, km (2 decimals) and floors of one Berlin day; `nil` without any step data.
    private func tageswerte(_ tag: String) async -> (anzahl: Int, km: Double?, etagen: Int?)? {
        guard let anzahl = await summe(stepType, tag, inMetern: false) else { return nil }
        let meter = await summe(distanzType, tag, inMetern: true)
        let etagen = await summe(etagenType, tag, inMetern: false)
        return (Int(anzahl), meter.map { ($0 / 10).rounded() / 100 }, etagen.map { Int($0) })
    }

    /// Sum over the Berlin day, the same boundaries for live sends and the backfill. The unit is
    /// built inside the (possibly `@Sendable`) handler from a `Bool`, so nothing non-Sendable is captured.
    private func summe(_ typ: HKQuantityType, _ tag: String, inMetern: Bool) async -> Double? {
        let start = Calendar.berlin.startOfDay(for: Datum.datum(tag))
        let ende = Calendar.berlin.date(byAdding: .day, value: 1, to: start) ?? start
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: ende, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKStatisticsQuery(quantityType: typ, quantitySamplePredicate: praedikat, options: .cumulativeSum) { _, ergebnis, _ in
                fortsetzung.resume(returning: ergebnis?.sumQuantity()?.doubleValue(for: inMetern ? .meter() : .count()))
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

    /// Nacht wird dem Aufwach-Tag zugeordnet (Spec 3.1). Das Fenster (30 h vor `tag` bis Ende `tag`)
    /// ist absichtlich großzügig; welche Intervalle wirklich die Nacht von `tag` sind, entscheidet
    /// `HealthLogik.schlafNacht` (I-4: die Vornacht endet am Vortag und fällt dort raus).
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
        return HealthLogik.schlafNacht(intervalle, tag: tag)
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

struct SchritteExtra: Sendable, Equatable { var km: Double?; var etagen: Int? }

/// `schritte.setzen {datum, anzahl, km?, etagen?, nachgetragen?}` — optional fields are left out
/// when `nil`, older builds ignore them.
private struct SchritteD: Codable {
    var datum: String
    var anzahl: Int
    var km: Double? = nil
    var etagen: Int? = nil
    var nachgetragen: Bool? = nil
}
private struct SchlafD: Codable { var datum: String; var minuten: Int; var von: String; var bis: String }
private struct EinstellungD: Codable { var schluessel: String; var wert: JSONValue }

/// HealthKit's observer completion handler is not `Sendable`; calling it from any thread is fine.
private struct ErledigtBox: @unchecked Sendable {
    let aufrufen: () -> Void
    init(_ f: @escaping () -> Void) { aufrufen = f }
}
