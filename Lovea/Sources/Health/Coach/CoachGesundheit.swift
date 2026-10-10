import Foundation
import HealthKit

/// Was der Coach an Health- und Tracker-Zahlen mitbekommt (`gesundheit` im Body von `coach/frage`).
/// Nur Ahmed, nur mit Schalter `schalter` (Standard an). Der Server nimmt davon nur feste Schlüssel und
/// nur Zahlen (`gesundheitBereinigen`), Text kommt nie durch. Die Schritte selbst stehen schon im
/// Kontext des Servers (aus den Ops, dort ist der Tracker eingerechnet); hier steht `schritteHealth`,
/// die reine iPhone-Zahl, daneben.
struct CoachGesundheitBericht: Encodable {
    struct Workout: Encodable {
        let art: String
        let datum: String
        var minuten: Double?
        var kcal: Double?
        var km: Double?
    }

    struct Band: Encodable {
        var akku: Double?
        var laedt: Bool?
        var pulsDauermessung: Bool?
        var pulsIntervallMin: Double?
        var letzteAbfrageVorMin: Double?
        var tage: [String: [String: Double]]
    }

    var tage: [String: [String: Double]]
    var workouts: [Workout]
    var band: Band?
}

/// Einheiten als Sendable-Wert: Die `HKUnit` entsteht erst im Handler der Abfrage.
private enum GesundheitEinheit: Sendable {
    case anzahl, kcal, minuten, proMinute, millisekunden, prozent, vo2, kilogramm

    var einheit: HKUnit {
        switch self {
        case .anzahl: return HKUnit.count()
        case .kcal: return HKUnit.kilocalorie()
        case .minuten: return HKUnit.minute()
        case .proMinute: return HKUnit.count().unitDivided(by: HKUnit.minute())
        case .millisekunden: return HKUnit.secondUnit(with: .milli)
        case .prozent: return HKUnit.percent()
        case .vo2: return HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))
        case .kilogramm: return HKUnit.gramUnit(with: .kilo)
        }
    }

    /// `HKUnit.percent()` liefert 0 bis 1.
    var faktor: Double { self == .prozent ? 100 : 1 }
}

private struct GesundheitStatistik: Sendable {
    var summe: Double?
    var mittel: Double?
    var min: Double?
    var max: Double?
}

@MainActor
enum CoachGesundheit {
    nonisolated static let schalter = "lovea.coach.gesundheit"
    static var erlaubt: Bool { UserDefaults.standard.object(forKey: schalter) as? Bool ?? true }

    /// Heute und die sieben Tage davor, so viele nimmt der Server.
    private static let fenster = 8

    /// Je Zeile eine Messgröße. Die Art passt zur Größe: Zählwerte summieren, Messwerte mitteln
    /// (die falsche Art lässt `HKStatisticsQuery` abstürzen).
    private struct Messwert {
        enum Art { case summe, mittel, bereich }
        let schluessel: String
        let kennung: HKQuantityTypeIdentifier
        let einheit: GesundheitEinheit
        let art: Art
        var minSchluessel: String?
        var maxSchluessel: String?

        var optionen: HKStatisticsOptions {
            switch art {
            case .summe: return [.cumulativeSum]
            case .mittel: return [.discreteAverage]
            case .bereich: return [.discreteAverage, .discreteMin, .discreteMax]
            }
        }
    }

    private static let messwerte: [Messwert] = [
        Messwert(schluessel: "schritteHealth", kennung: .stepCount, einheit: .anzahl, art: .summe),
        Messwert(schluessel: "etagen", kennung: .flightsClimbed, einheit: .anzahl, art: .summe),
        Messwert(schluessel: "aktivKcal", kennung: .activeEnergyBurned, einheit: .kcal, art: .summe),
        Messwert(schluessel: "ruheKcal", kennung: .basalEnergyBurned, einheit: .kcal, art: .summe),
        Messwert(schluessel: "trainingMin", kennung: .appleExerciseTime, einheit: .minuten, art: .summe),
        Messwert(schluessel: "stehMin", kennung: .appleStandTime, einheit: .minuten, art: .summe),
        Messwert(schluessel: "pulsSchnitt", kennung: .heartRate, einheit: .proMinute, art: .bereich, minSchluessel: "pulsMin", maxSchluessel: "pulsMax"),
        Messwert(schluessel: "ruhepuls", kennung: .restingHeartRate, einheit: .proMinute, art: .mittel),
        Messwert(schluessel: "gehpuls", kennung: .walkingHeartRateAverage, einheit: .proMinute, art: .mittel),
        Messwert(schluessel: "hrv", kennung: .heartRateVariabilitySDNN, einheit: .millisekunden, art: .mittel),
        Messwert(schluessel: "spo2", kennung: .oxygenSaturation, einheit: .prozent, art: .mittel),
        Messwert(schluessel: "atemfrequenz", kennung: .respiratoryRate, einheit: .proMinute, art: .mittel),
        Messwert(schluessel: "vo2max", kennung: .vo2Max, einheit: .vo2, art: .mittel),
        Messwert(schluessel: "gewichtKg", kennung: .bodyMass, einheit: .kilogramm, art: .mittel),
        Messwert(schluessel: "koerperfett", kennung: .bodyFatPercentage, einheit: .prozent, art: .mittel),
    ]

    /// Alles, was der Coach liest, zusätzlich zu dem, was `HealthModell` schon liest. Nur für Ahmed anfragen.
    static var typen: Set<HKObjectType> {
        var alle: Set<HKObjectType> = [HKObjectType.workoutType()]
        for m in messwerte {
            if let typ = HKQuantityType.quantityType(forIdentifier: m.kennung) { alle.insert(typ) }
        }
        return alle
    }

    private static let store = HKHealthStore()
    /// Die Health-Zahlen ändern sich langsam: bei Schlag auf Schlag-Fragen nicht jedes Mal 120 Abfragen.
    private static var zwischen: (zeit: Date, tage: [String: [String: Double]], workouts: [CoachGesundheitBericht.Workout])?

    /// `nil` für Annika, bei ausgeschaltetem Schalter und ohne Health. Fehlende Berechtigung ergibt keine Werte, keinen Fehler.
    static func bericht() async -> CoachGesundheitBericht? {
        guard erlaubt, Raum.shared.ich == .ahmed, HKHealthStore.isHealthDataAvailable() else { return nil }
        let tageUndWorkouts: (tage: [String: [String: Double]], workouts: [CoachGesundheitBericht.Workout])
        if let z = zwischen, Date().timeIntervalSince(z.zeit) < 300 {
            tageUndWorkouts = (z.tage, z.workouts)
        } else {
            let tage = await tageLesen()
            let workouts = await workoutsLesen()
            zwischen = (Date(), tage, workouts)
            tageUndWorkouts = (tage, workouts)
        }
        let bericht = CoachGesundheitBericht(tage: tageUndWorkouts.tage, workouts: tageUndWorkouts.workouts, band: bandBericht())
        return bericht.tage.isEmpty && bericht.workouts.isEmpty && bericht.band == nil ? nil : bericht
    }

    // MARK: Tracker

    private static func bandBericht() -> CoachGesundheitBericht.Band? {
        let band = TrackerModell.shared
        guard band.gekoppelt else { return nil }
        var tage: [String: [String: Double]] = [:]
        for (tag, eintrag) in band.bandTage.tage {
            var w: [String: Double] = ["schritte": Double(eintrag.schritte), "meter": Double(eintrag.meter), "slots": Double(eintrag.zeilen.count)]
            if let minute = eintrag.letzteMinute { w["letzteMinute"] = Double(minute) }
            tage[tag] = w
        }
        return CoachGesundheitBericht.Band(
            akku: band.akku.map { Double($0.prozent) },
            laedt: band.akku?.laedt,
            pulsDauermessung: band.pulsEinstellung?.an,
            pulsIntervallMin: band.pulsEinstellung.map { Double($0.intervallMinuten) },
            letzteAbfrageVorMin: band.bandTage.stand.map { (Date().timeIntervalSince($0) / 60).rounded() },
            tage: tage
        )
    }

    // MARK: Health

    private static func tageLesen() async -> [String: [String: Double]] {
        let heute = Datum.text(Date())
        var ergebnis: [String: [String: Double]] = [:]
        for tag in (0..<fenster).map({ Datum.addTage(heute, -$0) }) {
            let start = Calendar.berlin.startOfDay(for: Datum.datum(tag))
            let ende = Calendar.berlin.date(byAdding: .day, value: 1, to: start) ?? start
            var werte: [String: Double] = [:]
            for m in messwerte {
                guard let typ = HKQuantityType.quantityType(forIdentifier: m.kennung),
                      let s = await statistik(typ, von: start, bis: ende, optionen: m.optionen, einheit: m.einheit) else { continue }
                let hauptwert = m.art == .summe ? s.summe : s.mittel
                if let w = hauptwert, w.isFinite { werte[m.schluessel] = w * m.einheit.faktor }
                if let schluessel = m.minSchluessel, let w = s.min, w.isFinite { werte[schluessel] = w * m.einheit.faktor }
                if let schluessel = m.maxSchluessel, let w = s.max, w.isFinite { werte[schluessel] = w * m.einheit.faktor }
            }
            // Strecke und Schlaf kommen aus `HealthModell`: dort ist der Tracker schon eingerechnet.
            if let km = HealthModell.shared.kmAm(.ahmed, tag) { werte["km"] = km }
            if let schlaf = HealthModell.shared.schlafMinuten(.ahmed, tag) { werte["schlafMin"] = Double(schlaf) }
            if !werte.isEmpty { ergebnis[tag] = werte }
        }
        return ergebnis
    }

    private static func statistik(_ typ: HKQuantityType, von start: Date, bis ende: Date, optionen: HKStatisticsOptions, einheit: GesundheitEinheit) async -> GesundheitStatistik? {
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: ende, options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKStatisticsQuery(quantityType: typ, quantitySamplePredicate: praedikat, options: optionen) { _, ergebnis, _ in
                guard let ergebnis else { fortsetzung.resume(returning: nil); return }
                let unit = einheit.einheit
                fortsetzung.resume(returning: GesundheitStatistik(
                    summe: ergebnis.sumQuantity()?.doubleValue(for: unit),
                    mittel: ergebnis.averageQuantity()?.doubleValue(for: unit),
                    min: ergebnis.minimumQuantity()?.doubleValue(for: unit),
                    max: ergebnis.maximumQuantity()?.doubleValue(for: unit)
                ))
            }
            store.execute(abfrage)
        }
    }

    /// Die letzten zehn Trainings der letzten 14 Tage. Der Name ist nur ein kurzes deutsches Wort (der Server lässt nichts anderes durch).
    private static func workoutsLesen() async -> [CoachGesundheitBericht.Workout] {
        let heute = Datum.text(Date())
        let start = Calendar.berlin.startOfDay(for: Datum.datum(Datum.addTage(heute, -13)))
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let sortierung = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: praedikat, limit: 10, sortDescriptors: [sortierung]) { _, ergebnis, _ in
                let liste = ((ergebnis as? [HKWorkout]) ?? []).map { w -> CoachGesundheitBericht.Workout in
                    let kcal = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned).flatMap { w.statistics(for: $0)?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) }
                    let meter = [HKQuantityTypeIdentifier.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
                        .compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
                        .compactMap { w.statistics(for: $0)?.sumQuantity()?.doubleValue(for: HKUnit.meter()) }
                        .first
                    return CoachGesundheitBericht.Workout(
                        art: name(w.workoutActivityType), datum: Datum.text(w.startDate),
                        minuten: (w.duration / 60).rounded(), kcal: kcal.map { $0.rounded() }, km: meter.map { ($0 / 10).rounded() / 100 }
                    )
                }
                fortsetzung.resume(returning: liste)
            }
            store.execute(abfrage)
        }
    }

    private nonisolated static func name(_ art: HKWorkoutActivityType) -> String {
        switch art {
        case .running: return "Laufen"
        case .walking: return "Gehen"
        case .hiking: return "Wandern"
        case .cycling: return "Radfahren"
        case .swimming: return "Schwimmen"
        case .traditionalStrengthTraining: return "Krafttraining"
        case .functionalStrengthTraining: return "Funktionstraining"
        case .highIntensityIntervalTraining: return "Intervalltraining"
        case .coreTraining: return "Rumpftraining"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .elliptical: return "Crosstrainer"
        case .rowing: return "Rudern"
        case .stairClimbing: return "Treppensteigen"
        default: return "Training"
        }
    }
}
