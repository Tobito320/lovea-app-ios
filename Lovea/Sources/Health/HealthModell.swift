import CoreMotion
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
    /// Teil 6: die automatisch erkannte Nacht (Watch, iPhone-Schlafenszeit oder Bewegungs-Schätzung —
    /// `quelle` sagt welche). Eigene Einträge (`schlafZeiten`) haben immer Vorrang, siehe `schlafMinuten`.
    private(set) var schlaf: [Person: [String: (minuten: Int, von: Date, bis: Date, quelle: String?)]] = [:]

    private(set) var zielSchritteAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielGymAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielWasserAenderungen: [Person: [ZielAenderung]] = [:]
    private(set) var zielGemeinsamWocheAenderungen: [ZielAenderung] = []

    /// km, floors, kcal and active minutes of the same `schritte.setzen` op as `schritte` (same
    /// `seq`/`id`, so the same winner per day).
    private var schritteExtras: [Person: [String: TagesEintrag<SchritteExtra>]] = [:]
    private var habitFaltung = HabitFaltung()
    /// `ziel.saetze.<gruppe>` und `ziel.prio.<gruppe>`: Person -> Schlüssel -> Änderungen.
    private var zielAndere: [Person: [String: [ZielAenderung]]] = [:]

    /// Teil 5: hand-entered bed and wake-up times per person and wake-up day (newest op wins).
    private(set) var schlafZeiten: [Person: [String: SchlafZeitenD]] = [:]
    private var schlafZeitenZeit: [Person: [String: Date]] = [:]
    /// Teil 5/R10: every `habit.setzen` by habit id, person, day and op id, for the times of the
    /// taps (Wasser-Gläser, Koffein-Tassen). Habit id first, so `zeiten(_:_:_:)` stays generic.
    private var habitOps: [String: [Person: [String: [String: (zeit: Date, wert: Int)]]]] = [:]
    /// When each person's steps last came in (live ops only, not the backfill) — "vor 3 Std.".
    private(set) var schritteZuletzt: [Person: Date] = [:]

    private let store = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let distanzType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    private let etagenType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    private let energieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let bewegungType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    /// Teil 6: Bewegungs-Schätzung (d), nur wenn weder Watch noch iPhone-Schlafenszeit etwas liefern.
    /// Gleiches Muster wie `Anwesenheit`/`Standort`: kein `requestAuthorization` nötig, iOS fragt beim
    /// ersten `queryActivityStarting` selbst (`NSMotionUsageDescription` ist schon gesetzt).
    private let bewegungsManager = CMMotionActivityManager()

    private var angewendeteOps: Set<String> = []
    private var beobachterGestartet = false
    private var nachtragLaeuft = false
    /// Teil 6: verhindert, dass der Kaltstart-Observer und `sicherstellen()`s eigener Anstoß gleichzeitig
    /// laufen (doppelte CoreMotion-Abfragen, evtl. doppelte `schlaf.setzen`).
    private var schlafLaeuft = false
    private var zuletztGesendetSchritte: (datum: String, anzahl: Int)?
    private var zuletztGesendetUm = Date.distantPast

    /// A new key per new set of types, so the prompt appears once more (v3: distance and floors,
    /// v4: active energy and exercise time). Background observers still start on any older flag.
    private static let angefragtSchluessel = "lovea.health.berechtigungAngefragt.v4"
    private static let alteSchluessel = ["lovea.health.berechtigungAngefragt", "lovea.health.berechtigungAngefragt.v3"]
    private static let nachgetragenSchluessel = "lovea.health.schritteNachgetragen.v1"

    /// Für den "Health nicht erlaubt"-Hinweis (Z-21.1/Z-21.3, Review-Fokus 4): unterscheidet "noch
    /// nie gefragt" (Knopf soll `sicherstellen()` erneut auslösen) von "schon gefragt, aber keine
    /// Daten" (Knopf soll in die Einstellungen führen). Gespeichert statt berechnet, damit `@Observable`
    /// den Hinweis-Knopf sofort umschaltet, sobald `sicherstellen()` läuft — ein reiner UserDefaults-
    /// Lesezugriff würde SwiftUI keine Änderung melden.
    private(set) var berechtigungAngefragt = UserDefaults.standard.bool(forKey: HealthModell.angefragtSchluessel)

    private init() {
        StartProtokoll.marke("healthModell.init.vor")
        Raum.shared.beobachten(["schritte.setzen"]) { [weak self] op in self?.schritteOpAnwenden(op) }
        Raum.shared.beobachten(["schlaf.setzen"]) { [weak self] op in self?.schlafOpAnwenden(op) }
        Raum.shared.beobachten(["habit.setzen", "habit.anlegen", "habit.aendern", "habit.ausblenden"]) { [weak self] op in
            self?.habitFaltung.anwenden(op)
            self?.habitOpMerken(op)
        }
        Raum.shared.beobachten(["einstellung.setzen"]) { [weak self] op in self?.zielOpAnwenden(op) }
        Raum.shared.beobachten(["schlaf.zeiten"]) { [weak self] op in self?.schlafZeitenAnwenden(op) }
        StartProtokoll.marke("healthModell.init.nach")
    }

    private var heute: String { Datum.text(Date()) }

    // MARK: - Lesen (UI-API)

    func heuteSchritte(_ person: Person) -> Int? { schritte[person]?[heute]?.wert }
    /// Kamen von `person` schon einmal Schritte an (egal welcher Tag)? Dann ist Health dort erlaubt.
    func schritteVerbunden(_ person: Person) -> Bool { !(schritte[person]?.isEmpty ?? true) }
    /// Für die Anzeige: heute noch nichts gezählt, aber verbunden = 0 statt "–".
    func heuteSchritteAnzeige(_ person: Person) -> Int? {
        heuteSchritte(person) ?? (schritteVerbunden(person) ? 0 : nil)
    }
    func schritteAm(_ person: Person, _ tag: String) -> Int? { schritte[person]?[tag]?.wert }
    func kmAm(_ person: Person, _ tag: String) -> Double? { schritteExtras[person]?[tag]?.wert.km }
    func etagenAm(_ person: Person, _ tag: String) -> Int? { schritteExtras[person]?[tag]?.wert.etagen }
    func extrasAm(_ person: Person, _ tag: String) -> SchritteExtra? { schritteExtras[person]?[tag]?.wert }
    /// All days with steps (backfilled ones too — display only).
    func schritteWerte(_ person: Person) -> [String: Int] { (schritte[person] ?? [:]).mapValues(\.wert) }
    func schlafNacht(_ person: Person, _ tag: String) -> (minuten: Int, von: Date, bis: Date, quelle: String?)? { schlaf[person]?[tag] }
    func schlafZeitenAm(_ person: Person, _ tag: String) -> SchlafZeitenD? { schlafZeiten[person]?[tag] }
    /// Teil 6: eigener Eintrag (auch gelöscht = 0 min, dann `nil`) vor Watch vor iPhone-Schlafenszeit
    /// vor Bewegungs-Schätzung — siehe `SchlafLogik.minuten`. `schlafQuelle` sagt, welche das war.
    func schlafMinuten(_ person: Person, _ tag: String) -> Int? {
        let eintrag = schlafZeitenAm(person, tag).map(EnergieLogik.imBett)
        return SchlafLogik.minuten(eintrag: eintrag, automatik: schlaf[person]?[tag]?.minuten)
    }
    /// "eingetragen" | "Apple Watch" | "iPhone Schlafenszeit" | "geschätzt (Bewegung)", `nil` ohne Daten.
    func schlafQuelle(_ person: Person, _ tag: String) -> String? {
        let eintrag = schlafZeitenAm(person, tag).map(EnergieLogik.imBett)
        return SchlafLogik.quelle(eintrag: eintrag, automatikQuelle: schlaf[person]?[tag]?.quelle)
    }
    /// Effektive Bett-/Aufsteh-Zeit nach demselben Vorrang wie `schlafMinuten` — eigener Eintrag,
    /// sonst die automatisch erkannte Nacht, `nil` bei gesperrtem (gelöschtem) oder fehlendem Wert.
    func schlafBettZeiten(_ person: Person, _ tag: String) -> (bett: Date, auf: Date)? {
        guard schlafMinuten(person, tag) != nil else { return nil }
        if let z = schlafZeitenAm(person, tag), EnergieLogik.imBett(z) > 0 { return (z.bett, z.auf) }
        return schlaf[person]?[tag].map { ($0.von, $0.bis) }
    }
    func wasserZeiten(_ person: Person, _ tag: String) -> [Date] { wasserEintraege(person, tag).map(\.zeit) }
    /// R10: Zeiten der Koffein-Tassen fürs Bearbeiten-Blatt, gleiche Regel wie Wasser.
    func koffeinZeiten(_ person: Person, _ tag: String) -> [Date] { koffeinEintraege(person, tag).map(\.zeit) }

    func wasserEintraege(_ person: Person, _ tag: String) -> [(id: String, zeit: Date)] { habitEintraege(Habit.wasser.id, person, tag) }
    func koffeinEintraege(_ person: Person, _ tag: String) -> [(id: String, zeit: Date)] { habitEintraege(Habit.koffein.id, person, tag) }

    /// Jeder bekannte Tipp mit seiner eigenen Op-Id und Zeit, älteste zuerst — Review-Fund 1: anders
    /// als der alte `EnergieLogik.wasserZeiten`-Nachbau (nur Zeit, per Positions-Auf/Abbau rekonstruiert)
    /// kennt das hier die echte Identität jedes Tipps, damit ein Bearbeiten-Blatt genau EINEN stornieren
    /// kann, nicht nur "den jüngsten". `EnergieLogik.wasserZeiten` bleibt unberührt (eigene Tests).
    func habitEintraege(_ habitId: String, _ person: Person, _ tag: String) -> [(id: String, zeit: Date)] {
        (habitOps[habitId]?[person]?[tag] ?? [:]).map { (id: $0.key, zeit: $0.value.zeit) }.sorted { $0.zeit < $1.zeit }
    }

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

    /// Teil 6: Basis-Schlafziel in Minuten, Standard 480 (8 h).
    func schlafZielMinuten(_ person: Person? = nil) -> Int {
        ziel("ziel.schlaf.minuten", person ?? Raum.shared.ich ?? .ahmed) ?? 480
    }
    /// ± Minuten an den `schlafZielExtraTage`-Tagen (z. B. Wochenende länger schlafen).
    func schlafZielExtraMinuten(_ person: Person? = nil) -> Int {
        ziel("ziel.schlaf.extraMinuten", person ?? Raum.shared.ich ?? .ahmed) ?? 0
    }
    /// Bitmaske Montag = Bit 0 … Sonntag = Bit 6, wie `ErnaehrungsZiele.extraTage`.
    func schlafZielExtraTage(_ person: Person? = nil) -> Int {
        ziel("ziel.schlaf.extraTage", person ?? Raum.shared.ich ?? .ahmed) ?? 0
    }
    /// Das für `tag` geltende Schlafziel in Minuten (Basis, an flexiblen Tagen plus/minus die Extra-Minuten).
    func schlafZiel(_ p: Person, tag: String) -> Int {
        SchlafLogik.ziel(basis: schlafZielMinuten(p), extraMinuten: schlafZielExtraMinuten(p),
                        extraTage: schlafZielExtraTage(p), wochentag: Datum.wochentag(tag))
    }

    /// Generisch für `ziel.saetze.<gruppe>` und `ziel.prio.<gruppe>`: der neueste Wert, nil wenn nie gesetzt.
    func ziel(_ schluessel: String, _ person: Person) -> Int? {
        zielAndere[person]?[schluessel]?.enumerated()
            .max { ($0.element.seq ?? .max, $0.offset) < ($1.element.seq ?? .max, $1.offset) }?
            .element.wert
    }

    /// Nur lesen, der Kalender gehört jemand anderem. "gut" | "mittel" | "schlecht".
    func stimmung(_ person: Person, _ tag: String) -> String? {
        KalenderModell.shared.zustand.stimmungen[tag]?[person]?.stimmung
    }

    /// "Letzter gewinnt" (schnittstellen.md), keine Personen-Historie wie bei den anderen Zielen.
    /// Gleichstand (zwei unbestätigte) → die später angekommene (I-2).
    var zielGemeinsamWoche: Int {
        zielGemeinsamWocheAenderungen.enumerated()
            .max { ($0.element.seq ?? .max, $0.offset) < ($1.element.seq ?? .max, $1.offset) }?
            .element.wert ?? 140_000
    }

    // MARK: - Schreiben

    /// `storniert`: Op-Id eines früheren Tipps desselben Tages, der damit zurückgenommen wird (R10,
    /// Review-Fix) — fürs genaue Löschen einer einzelnen Zeile statt nur des Tageswerts.
    func setzeHabit(_ id: String, datum: String, wert: Int, storniert: String? = nil) {
        Raum.shared.senden("habit.setzen", HabitSetzenD(art: id, datum: datum, wert: max(0, wert), storniert: storniert))
    }

    /// Eigene Op-Id statt der zufälligen aus `senden` (wie `WidgetPendingOpsMerge.op(aus:)`), damit
    /// ein späterer Tipp sie gezielt stornieren kann. Nur für Taps, die sich merken sollen, wer sie
    /// waren (Koffein, verknüpft mit einem Tagebuch-Eintrag gleicher Id).
    func setzeHabitMitId(_ opId: String, _ habitId: String, datum: String, wert: Int) {
        guard let ich = Raum.shared.ich, let d = try? JSONEncoder().encode(HabitSetzenD(art: habitId, datum: datum, wert: max(0, wert))) else { return }
        Raum.shared.einreihen(Op(id: opId, seq: nil, art: "habit.setzen", von: ich, zeit: Date(), d: d))
    }

    func anlegen(_ habit: Habit) { Raum.shared.senden("habit.anlegen", habit) }
    func aendern(_ habit: Habit) { Raum.shared.senden("habit.aendern", habit) }
    func ausblenden(_ id: String, _ aus: Bool) { Raum.shared.senden("habit.ausblenden", HabitAusblendenD(id: id, aus: aus)) }

    func setzeGym(datum: String, an: Bool) { setzeHabit(Habit.gym.id, datum: datum, wert: an ? 1 : 0) }
    func setzeWasser(datum: String, anzahl: Int) { setzeHabit(Habit.wasser.id, datum: datum, wert: anzahl) }
    func schlafEintragen(_ d: SchlafZeitenD) { Raum.shared.senden("schlaf.zeiten", d) }

    /// Schritte von Hand (YAZIO Pro "manuelle Schritte", ohne Tracker). Gleiche Op wie Apple Health,
    /// der neuere Wert gewinnt; schickt Apple Health später einen anderen Wert, gilt der.
    func schritteEintragen(_ anzahl: Int, datum: String) {
        Raum.shared.senden("schritte.setzen", SchritteD(datum: datum, anzahl: max(0, anzahl)))
    }

    /// `schluessel` ist eines von `ziel.schritte`, `ziel.gym`, `ziel.wasser`, `ziel.gemeinsamWoche`,
    /// oder `ziel.schlaf.minuten`/`.extraMinuten`/`.extraTage` (Teil 6, generisch über `zielOpAnwenden`).
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
        let extra = SchritteExtra(km: d.km, etagen: d.etagen, kcal: d.kcal, aktivMinuten: d.aktivMinuten)
        HealthFaltung.aufnehmen(&schritteExtras, TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: gesendet, wert: extra, id: op.id))
        if d.nachgetragen != true { schritteZuletzt[op.von] = max(schritteZuletzt[op.von] ?? .distantPast, op.zeit) }
    }

    private func schlafOpAnwenden(_ op: Op) {
        guard angewendeteOps.insert(op.id).inserted, let d = op.daten(SchlafD.self) else { return }
        guard let von = Self.isoDatum(d.von), let bis = Self.isoDatum(d.bis) else { return }
        // Ältere Ops ohne `quelle` kamen ausschließlich aus den asleep-Werten (vor Teil 6) — als Watch lesen.
        schlaf[op.von, default: [:]][d.datum] = (minuten: d.minuten, von: von, bis: bis, quelle: d.quelle ?? SchlafLogik.Quelle.appleWatch.rawValue)
    }

    private func schlafZeitenAnwenden(_ op: Op) {
        guard let d = op.daten(SchlafZeitenD.self), (schlafZeitenZeit[op.von]?[d.datum] ?? .distantPast) <= op.zeit else { return }
        schlafZeiten[op.von, default: [:]][d.datum] = d
        schlafZeitenZeit[op.von, default: [:]][d.datum] = op.zeit
    }

    private func habitOpMerken(_ op: Op) {
        guard op.art == "habit.setzen", let d = op.daten(HabitSetzenD.self) else { return }
        if let storniert = d.storniert {
            habitOps[d.art]?[op.von]?[d.datum]?.removeValue(forKey: storniert)
            return
        }
        habitOps[d.art, default: [:]][op.von, default: [:]][d.datum, default: [:]][op.id] = (zeit: op.zeit, wert: d.wert)
        habitOpsAufraeumen(d.art, op.von)
    }

    /// Minor (Review): ohne Grenze wächst `habitOps` jetzt für jeden Habit unbegrenzt (vorher nur bei
    /// Wasser gefiltert). Die Zeitenlisten sind fürs Bearbeiten-Blatt gedacht, nicht fürs Archiv — eine
    /// Woche deckt "ich hab's gestern vergessen einzutragen" ab, ohne für jeden Tag ewig mitzuwachsen.
    private func habitOpsAufraeumen(_ habitId: String, _ person: Person) {
        let aeltesteNoch = Datum.addTage(heute, -6)
        // Erst lesen, dann schreiben: Lesen und Schreiben von `habitOps` in EINER Zeile ist ein
        // überlappender Zugriff, Swift bricht dann zur Laufzeit ab (Absturz Build 76-80).
        guard let alt = habitOps[habitId]?[person] else { return }
        let neu = alt.filter { $0.key >= aeltesteNoch }
        habitOps[habitId]?[person] = neu
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
        default:
            guard d.schluessel.hasPrefix("ziel.saetze.") || d.schluessel.hasPrefix("ziel.prio.") || d.schluessel.hasPrefix("ziel.ernaehrung.")
                || d.schluessel.hasPrefix("ziel.schlaf.") else { break }
            HealthLogik.zielAufnehmen(&zielAndere[op.von, default: [:]][d.schluessel, default: []], aenderung)
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
            // Teil 6: ohne echte Watch-/iPhone-Schlafdaten feuert der HK-Observer nie von selbst (kein
            // neues Sample ändert sich) — die Bewegungs-Schätzung braucht also einen eigenen Anstoß.
            // Hier: jedes Öffnen des Health-Tabs, kein Hintergrund-Trigger (siehe Bericht). `leer()`
            // zuerst, sonst wirkt vor der eigenen Replay jeder Tag "geändert" (wie beim Observer-Pfad).
            Task {
                await Raum.shared.leer()
                await schlafAktualisierenUndSenden()
            }
            return
        }
        UserDefaults.standard.set(true, forKey: Self.angefragtSchluessel)
        berechtigungAngefragt = true
        Task {
            _ = await berechtigungAnfragen()
            // beobachtenStartenFallsErlaubt() startet den Schlaf-Observer zum ersten Mal, der wie jede
            // HKObserverQuery beim `execute()` sofort einmal feuert — ruft `schlafAktualisierenUndSenden`
            // hier schon mit auf, ein zweiter expliziter Aufruf wäre nur doppelt.
            beobachtenStartenFallsErlaubt()
            await nachtragenFallsNoetig()
        }
    }

    /// Startet `HKObserverQuery` + Background Delivery erneut, ohne zu fragen — muss bei JEDEM
    /// App-Start laufen (auch einem Hintergrund-Start), sonst bleibt Background Delivery nach
    /// einem Neustart aus. No-op, solange nie gefragt wurde (weder Runde 2 noch jetzt).
    func beobachtenStartenFallsErlaubt() {
        let jemalsGefragt = berechtigungAngefragt || Self.alteSchluessel.contains { UserDefaults.standard.bool(forKey: $0) }
        guard HKHealthStore.isHealthDataAvailable(), jemalsGefragt, !beobachterGestartet else { return }
        beobachterGestartet = true
        beobachteAenderungen()
    }

    /// `requestAuthorization` meldet nur, ob die Anfrage abgeschlossen wurde, nie ob sie gewährt
    /// wurde (Apples Privacy-Design für Lesezugriffe) — deshalb wird trotzdem versucht zu lesen.
    private func berechtigungAnfragen() async -> Bool {
        await withCheckedContinuation { fortsetzung in
            store.requestAuthorization(toShare: [], read: [stepType, distanzType, etagenType, energieType, bewegungType, sleepType]) { erfolg, _ in
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

    /// Heute + letzte 7 Tage, nur bei Änderung (Z-20.1); km, Etagen, kcal und Aktivzeit reisen mit.
    // ponytail: only the step observer triggers — the other values are written while walking too.
    private func schritteAktualisierenUndSenden() async {
        guard Geraet.wirdGetragen, let ich = Raum.shared.ich else { return }
        for tag in letzteAchtTage() {
            guard let neu = await tageswerte(tag) else { continue }
            guard schritte[ich]?[tag]?.wert != neu.anzahl || schritteExtras[ich]?[tag]?.wert != neu.extra else { continue }
            if tag == heute {
                let vergangen = Date().timeIntervalSince(zuletztGesendetUm)
                guard HealthLogik.sollSchritteSenden(anzahl: neu.anzahl, zuletzt: zuletztGesendetSchritte, heutigerTag: heute, vergangen: vergangen) else { continue }
                zuletztGesendetSchritte = (heute, neu.anzahl)
                zuletztGesendetUm = Date()
            }
            Raum.shared.senden("schritte.setzen", SchritteD(neu.anzahl, neu.extra, datum: tag))
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
        guard Geraet.wirdGetragen, let ich = Raum.shared.ich, Raum.shared.nachgeholt, berechtigungAngefragt, !nachtragLaeuft,
              !UserDefaults.standard.bool(forKey: Self.nachgetragenSchluessel) else { return }
        nachtragLaeuft = true
        defer { nachtragLaeuft = false }
        for tag in HealthLogik.nachtragTage(heute: heute, vorhanden: Set((schritte[ich] ?? [:]).keys)) {
            guard let werte = await tageswerte(tag), schritte[ich]?[tag] == nil else { continue }
            var d = SchritteD(werte.anzahl, werte.extra, datum: tag)
            d.nachgetragen = true
            Raum.shared.senden("schritte.setzen", d)
        }
        UserDefaults.standard.set(true, forKey: Self.nachgetragenSchluessel)
    }

    /// Steps plus km (2 decimals), floors, active kcal and exercise minutes of one Berlin day;
    /// `nil` without any step data.
    private func tageswerte(_ tag: String) async -> (anzahl: Int, extra: SchritteExtra)? {
        guard let anzahl = await summe(stepType, tag, .anzahl) else { return nil }
        let meter = await summe(distanzType, tag, .meter)
        let etagen = await summe(etagenType, tag, .anzahl)
        let kcal = await summe(energieType, tag, .kcal)
        let minuten = await summe(bewegungType, tag, .minuten)
        let extra = SchritteExtra(
            km: meter.map { ($0 / 10).rounded() / 100 }, etagen: etagen.map { Int($0) },
            kcal: kcal.map { Int($0.rounded()) }, aktivMinuten: minuten.map { Int($0.rounded()) }
        )
        return (Int(anzahl), extra)
    }

    private enum Einheit: Sendable { case anzahl, meter, kcal, minuten }

    /// Sum over the Berlin day, the same boundaries for live sends and the backfill. The unit is
    /// built inside the (possibly `@Sendable`) handler from a Sendable enum, so nothing else is captured.
    private func summe(_ typ: HKQuantityType, _ tag: String, _ einheit: Einheit) async -> Double? {
        let start = Calendar.berlin.startOfDay(for: Datum.datum(tag))
        let ende = Calendar.berlin.date(byAdding: .day, value: 1, to: start) ?? start
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: ende, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKStatisticsQuery(quantityType: typ, quantitySamplePredicate: praedikat, options: .cumulativeSum) { _, ergebnis, _ in
                let unit: HKUnit
                switch einheit {
                case .anzahl: unit = HKUnit.count()
                case .meter: unit = HKUnit.meter()
                case .kcal: unit = HKUnit.kilocalorie()
                case .minuten: unit = HKUnit.minute()
                }
                fortsetzung.resume(returning: ergebnis?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(abfrage)
        }
    }

    private func schlafAktualisierenUndSenden() async {
        guard Geraet.wirdGetragen, let ich = Raum.shared.ich, !schlafLaeuft else { return }
        schlafLaeuft = true
        defer { schlafLaeuft = false }
        for tag in letzteAchtTage() {
            guard let ergebnis = await schlafAn(tag),
                  schlaf[ich]?[tag]?.minuten != ergebnis.minuten || schlaf[ich]?[tag]?.quelle != ergebnis.quelle.rawValue
            else { continue }
            Raum.shared.senden("schlaf.setzen", SchlafD(datum: tag, minuten: ergebnis.minuten, von: Self.isoText(ergebnis.von), bis: Self.isoText(ergebnis.bis), quelle: ergebnis.quelle.rawValue))
        }
    }

    /// Nacht wird dem Aufwach-Tag zugeordnet (Spec 3.1). Das Fenster (30 h vor `tag` bis Ende `tag`)
    /// ist absichtlich großzügig; welche Intervalle wirklich die Nacht von `tag` sind, entscheidet
    /// `HealthLogik.schlafNacht` (I-4: die Vornacht endet am Vortag und fällt dort raus).
    ///
    /// Teil 6, Vorrang b) Watch vor c) iPhone-Schlafenszeit vor d) Bewegungs-Schätzung
    /// (`SchlafLogik.automatikVorrang`). Watch und andere Geräte, die echte Schlafphasen schreiben,
    /// benutzen die asleep-Werte; nur das iPhone selbst (mit eingeschalteter Schlafenszeit) schreibt
    /// `inBed`, ohne je asleep zu setzen — deshalb reicht "asleep vorhanden?" als Watch-Erkennung,
    /// ohne die Quelle jedes Samples einzeln zu prüfen.
    private func schlafAn(_ tag: String) async -> (minuten: Int, von: Date, bis: Date, quelle: SchlafLogik.Quelle)? {
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
        let watchIntervalle = samples
            .filter { Self.asleepWerte.contains($0.value) }
            .map { HealthLogik.SchlafIntervall(von: $0.startDate, bis: $0.endDate) }
        let iphoneIntervalle = samples
            .filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
            .map { HealthLogik.SchlafIntervall(von: $0.startDate, bis: $0.endDate) }
        let watch = HealthLogik.schlafNacht(watchIntervalle, tag: tag)
        let iphone = SchlafLogik.imBettSchaetzung(iphoneIntervalle, tag: tag)
        // Die Bewegungs-Schätzung braucht CoreMotion-Abfragen (teurer) — nur versuchen, wenn a/b/c nichts haben.
        let geschaetzt = (watch == nil && iphone == nil) ? await schlafGeschaetzt(tag) : nil
        return SchlafLogik.automatikVorrang(watch: watch, iphone: iphone, geschaetzt: geschaetzt)
    }

    /// d) Bewegungs-Schätzung: Fenster 18 Uhr Vortag bis 14 Uhr (nie in die Zukunft), Aktivität via
    /// `CMMotionActivityManager`.
    private func schlafGeschaetzt(_ tag: String) async -> (minuten: Int, von: Date, bis: Date)? {
        guard Geraet.wirdGetragen, CMMotionActivityManager.isActivityAvailable() else { return nil }
        let tagStart = Calendar.berlin.startOfDay(for: Datum.datum(tag))
        guard let fensterStart = Calendar.berlin.date(byAdding: .hour, value: -6, to: tagStart),
              let fensterEndeRoh = Calendar.berlin.date(byAdding: .hour, value: 14, to: tagStart)
        else { return nil }
        let fensterEnde = min(fensterEndeRoh, Date())
        guard fensterEnde > fensterStart else { return nil }
        let aktivitaeten: [SchlafLogik.Aktivitaet] = await withCheckedContinuation { fortsetzung in
            bewegungsManager.queryActivityStarting(from: fensterStart, to: fensterEnde, to: .main) { taetigkeiten, _ in
                let liste = (taetigkeiten ?? []).map {
                    SchlafLogik.Aktivitaet(zeit: $0.startDate, stationaer: $0.stationary,
                                          konfidenz: SchlafLogik.Konfidenz(rawValue: $0.confidence.rawValue) ?? .niedrig)
                }
                fortsetzung.resume(returning: liste)
            }
        }
        return SchlafLogik.bewegungsSchaetzung(aktivitaeten, fensterEnde: fensterEnde, tag: tag)
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

struct SchritteExtra: Sendable, Equatable {
    var km: Double? = nil
    var etagen: Int? = nil
    var kcal: Int? = nil
    var aktivMinuten: Int? = nil
}

/// `schritte.setzen {datum, anzahl, km?, etagen?, kcal?, aktivMinuten?, nachgetragen?}` — optional
/// fields are left out when `nil`, older builds ignore them.
private struct SchritteD: Codable {
    var datum: String
    var anzahl: Int
    var km: Double? = nil
    var etagen: Int? = nil
    var kcal: Int? = nil
    var aktivMinuten: Int? = nil
    var nachgetragen: Bool? = nil
}

private extension SchritteD {
    init(_ anzahl: Int, _ extra: SchritteExtra, datum: String) {
        self.init(datum: datum, anzahl: anzahl, km: extra.km, etagen: extra.etagen, kcal: extra.kcal, aktivMinuten: extra.aktivMinuten)
    }
}
/// `quelle` optional, ältere Builds ignorieren es (siehe `schlafOpAnwenden`).
private struct SchlafD: Codable { var datum: String; var minuten: Int; var von: String; var bis: String; var quelle: String? = nil }
private struct EinstellungD: Codable { var schluessel: String; var wert: JSONValue }

/// HealthKit's observer completion handler is not `Sendable`; calling it from any thread is fine.
private struct ErledigtBox: @unchecked Sendable {
    let aufrufen: () -> Void
    init(_ f: @escaping () -> Void) { aufrufen = f }
}
