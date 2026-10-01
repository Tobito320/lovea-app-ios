import Foundation
import HealthKit
import Observation

// Puls und Kalorien im Training (Teil 4), wie Hevy mit AirPods Pro 3. Seit iOS 26 läuft eine
// Workout-Sitzung auch auf dem iPhone; der Puls kommt nur, wenn ein Sensor verbunden ist (AirPods
// Pro 3, Pulsgurt). Ohne Sensor gibt es keinen Puls, das ist der Normalfall (Annika).
//
// Akku: Die Sitzung hält den Sensor wach, das kostet spürbar. Deshalb aus, bis man es pro Gerät
// einschaltet, und nur während ein Training läuft. Das Training landet danach in Apple Health.

/// Die HealthKit-Objekte sind nicht Sendable und rufen ihren Delegate auf einer eigenen Queue.
/// Diese Klasse hält sie zusammen und reicht nur Zahlen nach außen.
private final class PulsSitzung: NSObject, HKLiveWorkoutBuilderDelegate, @unchecked Sendable {
    private let session: HKWorkoutSession
    private let builder: HKLiveWorkoutBuilder
    private let melden: @Sendable (_ puls: Int?, _ schnitt: Int?, _ kcal: Int?) -> Void

    init(store: HKHealthStore, melden: @escaping @Sendable (Int?, Int?, Int?) -> Void) throws {
        let einstellung = HKWorkoutConfiguration()
        einstellung.activityType = .traditionalStrengthTraining
        einstellung.locationType = .indoor
        let neu = try HKWorkoutSession(healthStore: store, configuration: einstellung)
        let sammler = neu.associatedWorkoutBuilder()
        sammler.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: einstellung)
        session = neu
        builder = sammler
        self.melden = melden
        super.init()
        sammler.delegate = self
    }

    func starten() async throws {
        let jetzt = Date()
        session.prepare()
        session.startActivity(with: jetzt)
        try await builder.beginCollection(at: jetzt)
    }

    /// `speichern` schreibt das Training nach Apple Health, sonst wird es verworfen.
    func beenden(speichern: Bool) async {
        let jetzt = Date()
        session.stopActivity(with: jetzt)
        if speichern {
            try? await builder.endCollection(at: jetzt)
            _ = try? await builder.finishWorkout()
        } else {
            builder.discardWorkout()
        }
        session.end()
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let proMinute = HKUnit.count().unitDivided(by: .minute())
        let herz = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        let energie = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))
        melden(
            herz?.mostRecentQuantity().map { Int($0.doubleValue(for: proMinute).rounded()) },
            herz?.averageQuantity().map { Int($0.doubleValue(for: proMinute).rounded()) },
            energie?.sumQuantity().map { Int($0.doubleValue(for: .kilocalorie()).rounded()) }
        )
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

@MainActor @Observable
final class WorkoutPuls {
    static let shared = WorkoutPuls()
    private static let schluessel = "gym.puls"

    /// Letzter Puls, Schnitt über das Training und aktive Kalorien; nil, solange nichts kommt.
    private(set) var puls: Int?
    private(set) var schnitt: Int?
    private(set) var kcal: Int?

    private var sitzung: PulsSitzung?
    private var startet = false

    private init() {}

    /// Pro Gerät, ohne Op: aus, bis man es einschaltet.
    var an: Bool {
        get {
            access(keyPath: \.an)
            return UserDefaults.standard.bool(forKey: Self.schluessel)
        }
        set {
            withMutation(keyPath: \.an) { UserDefaults.standard.set(newValue, forKey: Self.schluessel) }
        }
    }

    /// Startet die Messung, wenn sie eingeschaltet ist und noch nicht läuft. Fragt beim ersten Mal
    /// nach der Erlaubnis für Apple Health.
    func starten() {
        guard an, sitzung == nil, !startet, HKHealthStore.isHealthDataAvailable() else { return }
        startet = true
        Task {
            defer { startet = false }
            let store = HKHealthStore()
            let lesen: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
            let schreiben: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
            do {
                try await store.requestAuthorization(toShare: schreiben, read: lesen)
                let neu = try PulsSitzung(store: store) { puls, schnitt, kcal in
                    Task { @MainActor in WorkoutPuls.shared.uebernehmen(puls, schnitt, kcal) }
                }
                try await neu.starten()
                // Inzwischen ausgeschaltet oder das Training beendet: gleich wieder verwerfen.
                if an { sitzung = neu } else { await neu.beenden(speichern: false) }
            } catch {
                // Keine Erlaubnis oder kein Workout möglich: das Training läuft ohne Puls weiter.
            }
        }
    }

    /// Beendet die Messung. Die Werte bleiben stehen, bis das nächste Training startet.
    func beenden(speichern: Bool) {
        guard let alt = sitzung else { return }
        sitzung = nil
        puls = nil
        Task { await alt.beenden(speichern: speichern) }
    }

    /// Vor einem neuen Training: alte Werte weg.
    func leeren() {
        guard sitzung == nil else { return }
        puls = nil
        schnitt = nil
        kcal = nil
    }

    private func uebernehmen(_ puls: Int?, _ schnitt: Int?, _ kcal: Int?) {
        guard sitzung != nil || startet else { return }
        if let puls { self.puls = puls }
        if let schnitt { self.schnitt = schnitt }
        if let kcal { self.kcal = kcal }
    }
}
