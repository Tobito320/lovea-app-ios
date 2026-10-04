import Foundation
import HealthKit

/// Zyklus-Verknüpfung mit Apple Health. Nur Annika, nur mit Schalter, nie für Demo-Daten.
/// Hier steht nur Rechte- und Abbildungs-Code, der ohne Gerät testbar ist.
enum ZyklusHealthKit {
    static func erlaubt(person: Person, schalter: Bool, quelle: ZyklusQuelle) -> Bool {
        ZyklusVerknuepfung.zeigen(person: person, schalter: schalter, quelle: quelle)
    }

    static let flussTyp = HKCategoryType(.menstrualFlow)

    static var leseTypen: Set<HKObjectType> {
        [flussTyp, HKQuantityType(.basalBodyTemperature), HKCategoryType(.sleepAnalysis),
         HKQuantityType(.stepCount), HKQuantityType(.bodyMass)]
    }

    static var schreibTypen: Set<HKSampleType> { [flussTyp] }

    /// Schmierblutung hat in Health keinen Flusswert und wird nicht geschrieben.
    static func fluss(von blutung: Blutung) -> HKCategoryValueMenstrualFlow? {
        switch blutung {
        case .schmierblutung: nil
        case .leicht: .light
        case .mittel: .medium
        case .stark: .heavy
        }
    }

    /// `.unspecified` heißt Blutung ohne Stärke, wir nehmen mittel. `.none` ist keine Blutung.
    static func blutung(von fluss: HKCategoryValueMenstrualFlow) -> Blutung? {
        switch fluss {
        case .light: .leicht
        case .medium: .mittel
        case .heavy: .stark
        case .unspecified: .mittel
        default: nil
        }
    }

    static func blutung(vonRohwert wert: Int) -> Blutung? {
        HKCategoryValueMenstrualFlow(rawValue: wert).flatMap(blutung(von:))
    }

    /// Flussprobe für einen Tag. Die Sync-ID macht das erneute Schreiben zu einem Ersetzen.
    static func probe(blutung: Blutung, tag: String, periodenStart: Bool) -> HKCategorySample? {
        guard let wert = fluss(von: blutung) else { return nil }
        let start = Datum.kalender.startOfDay(for: Datum.datum(tag))
        let ende = Datum.kalender.date(byAdding: .day, value: 1, to: start) ?? start
        var meta: [String: Any] = [
            HKMetadataKeySyncIdentifier: "lovea.zyklus.fluss.\(tag)",
            HKMetadataKeySyncVersion: 1,
        ]
        if periodenStart { meta[HKMetadataKeyMenstrualCycleStart] = true }
        return HKCategorySample(type: flussTyp, value: wert.rawValue, start: start, end: ende, metadata: meta)
    }

    /// Fragt die Rechte nur, wenn die Bedingungen stimmen. Gibt zurück, ob gefragt wurde.
    @MainActor
    @discardableResult
    static func anfragen(person: Person, schalter: Bool, quelle: ZyklusQuelle,
                         store: HKHealthStore = HKHealthStore()) async throws -> Bool {
        guard erlaubt(person: person, schalter: schalter, quelle: quelle),
              HKHealthStore.isHealthDataAvailable() else { return false }
        try await store.requestAuthorization(toShare: schreibTypen, read: leseTypen)
        return true
    }
}
