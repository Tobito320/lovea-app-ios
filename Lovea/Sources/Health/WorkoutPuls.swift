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

    /// Fragt die Erlaubnis an (nur hier, also erst beim Einschalten, nie beim App-Start) und startet
    /// die Sitzung. Lief noch eine von vor einem App-Ende, wird sie fortgesetzt statt eine zweite
    /// daneben zu starten.
    static func starten(melden: @escaping @Sendable (Int?, Int?, Int?) -> Void) async throws -> PulsSitzung {
        let store = HKHealthStore()
        let lesen: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        let schreiben: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
        try await store.requestAuthorization(toShare: schreiben, read: lesen)
        let einstellung = HKWorkoutConfiguration()
        einstellung.activityType = .traditionalStrengthTraining
        einstellung.locationType = .indoor
        let alt = try? await store.recoverActiveWorkoutSession()
        let session = try alt ?? HKWorkoutSession(healthStore: store, configuration: einstellung)
        let sitzung = PulsSitzung(session: session, melden: melden)
        if alt == nil {
            sitzung.builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: einstellung)
            let jetzt = Date()
            session.prepare()
            session.startActivity(with: jetzt)
            try await sitzung.builder.beginCollection(at: jetzt)
        }
        return sitzung
    }

    /// Eine Sitzung, die ein App-Ende überlebt hat, obwohl kein Training mehr läuft: beenden und
    /// verwerfen, damit der Sensor nicht weiterläuft (Akku-Regel).
    static func verwaisteBeenden() async {
        guard let alt = try? await HKHealthStore().recoverActiveWorkoutSession() else { return }
        alt.associatedWorkoutBuilder().discardWorkout()
        alt.end()
    }

    private init(session: HKWorkoutSession, melden: @escaping @Sendable (Int?, Int?, Int?) -> Void) {
        self.session = session
        builder = session.associatedWorkoutBuilder()
        self.melden = melden
        super.init()
        builder.delegate = self
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
    /// Beenden kam, während die Sitzung noch startete.
    private var abbruch = false
    private var aufgeraeumt = false

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
    /// nach der Erlaubnis für Apple Health. Nur auf dem iPhone (`Geraet.wirdGetragen`), nie auf dem iPad.
    func starten() {
        guard an, Geraet.wirdGetragen, sitzung == nil, !startet, HKHealthStore.isHealthDataAvailable() else { return }
        startet = true
        abbruch = false
        Task {
            defer { startet = false }
            do {
                let neu = try await PulsSitzung.starten { puls, schnitt, kcal in
                    Task { @MainActor in WorkoutPuls.shared.uebernehmen(puls, schnitt, kcal) }
                }
                // Während des Startens ausgeschaltet oder das Training beendet: gleich wieder verwerfen.
                if an, !abbruch { sitzung = neu } else { await neu.beenden(speichern: false) }
            } catch {
                // Keine Erlaubnis oder kein Workout möglich: das Training läuft ohne Puls weiter.
            }
        }
    }

    /// Kein Training läuft mehr, aber die Messung ist eingeschaltet: eine Sitzung, die ein App-Ende
    /// überlebt hat, beenden. Einmal pro App-Start, und nur wenn der Schalter an ist.
    func verwaisteBeenden() {
        guard an, Geraet.wirdGetragen, sitzung == nil, !startet, !aufgeraeumt else { return }
        aufgeraeumt = true
        Task { await PulsSitzung.verwaisteBeenden() }
    }

    /// Beendet die Messung. Die Werte bleiben stehen, bis das nächste Training startet.
    func beenden(speichern: Bool) {
        abbruch = true
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
