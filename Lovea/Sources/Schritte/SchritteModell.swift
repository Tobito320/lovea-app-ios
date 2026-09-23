import Foundation
import HealthKit
import Observation

/// Faltet `schritte.setzen {datum, anzahl}` (heutige Schrittzahl beider, Z-18.8) und liest/beobachtet
/// die eigenen Schritte über HealthKit. Die Leseberechtigung wird erst angefragt, wenn `sicherstellen()`
/// beim ersten Anzeigen aufgerufen wird — nicht beim App-Start.
@MainActor
@Observable
final class SchritteModell {
    static let shared = SchritteModell()

    /// Heutige Schrittzahl pro Person, `nil` solange unbekannt (keine Berechtigung, Simulator, Partner
    /// hat heute noch nichts gesendet).
    private(set) var heute: [Person: Int] = [:]

    private let store = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private var angewendeteOps: Set<String> = []
    private var angefragt = false
    private var zuletztGesendet: (datum: String, anzahl: Int)?
    private var zuletztGesendetUm = Date.distantPast

    private init() {
        Raum.shared.beobachten(["schritte.setzen"]) { [weak self] op in
            guard let self, self.angewendeteOps.insert(op.id).inserted, let d = op.daten(SchritteD.self) else { return }
            SchritteLogik.falten(&self.heute, von: op.von, datum: d.datum, anzahl: d.anzahl, heutigerTag: Datum.text(Date()))
        }
    }

    /// Vom `onAppear` der Schritte-Anzeige: fragt beim ersten Mal die Leseberechtigung an, danach
    /// liest sie die eigenen Schritte und beobachtet Änderungen. `HKHealthStore.isHealthDataAvailable()`
    /// ist auf dem Simulator und iPads `false` — dann bleibt `heute[ich]` einfach unbekannt.
    func sicherstellen() {
        guard !angefragt, HKHealthStore.isHealthDataAvailable() else { return }
        angefragt = true
        Task {
            guard await berechtigungAnfragen() else { return }
            await aktualisieren()
            beobachteAenderungen()
        }
    }

    /// `requestAuthorization` meldet nur, ob die Anfrage abgeschlossen wurde, nie ob sie gewährt
    /// wurde (Apples Privacy-Design für Lesezugriffe) — deshalb wird trotzdem versucht zu lesen.
    private func berechtigungAnfragen() async -> Bool {
        await withCheckedContinuation { fortsetzung in
            store.requestAuthorization(toShare: [], read: [stepType]) { erfolg, _ in
                fortsetzung.resume(returning: erfolg)
            }
        }
    }

    private func aktualisieren() async {
        guard let ich = Raum.shared.ich, let anzahl = await heutigeSchritte() else { return }
        heute[ich] = anzahl
        sendenFallsNoetig(anzahl)
    }

    private func heutigeSchritte() async -> Int? {
        let start = Calendar.berlin.startOfDay(for: Date())
        let praedikat = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { fortsetzung in
            let abfrage = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: praedikat, options: .cumulativeSum) { _, ergebnis, _ in
                let summe = ergebnis?.sumQuantity()?.doubleValue(for: .count())
                fortsetzung.resume(returning: summe.map { Int($0) })
            }
            store.execute(abfrage)
        }
    }

    /// `HKObserverQuery` + stündliche Hintergrund-Zustellung (Spec: "wenn simpel").
    private func beobachteAenderungen() {
        let abfrage = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, fertig, _ in
            Task { @MainActor in await self?.aktualisieren() }
            fertig()
        }
        store.execute(abfrage)
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }

    private func sendenFallsNoetig(_ anzahl: Int) {
        let heuteStr = Datum.text(Date())
        let vergangen = Date().timeIntervalSince(zuletztGesendetUm)
        guard SchritteLogik.sollSenden(anzahl: anzahl, zuletzt: zuletztGesendet, heutigerTag: heuteStr, vergangen: vergangen) else { return }
        zuletztGesendet = (heuteStr, anzahl)
        zuletztGesendetUm = Date()
        Raum.shared.senden("schritte.setzen", SchritteD(datum: heuteStr, anzahl: anzahl))
    }
}

private struct SchritteD: Codable { let datum: String; let anzahl: Int }

/// Reine Logik ohne HealthKit/Raum — separat testbar (common.md: "Tests only for pure logic").
enum SchritteLogik {
    /// Immer senden, wenn heute noch nichts geschickt wurde; danach nur bei Sprung ≥50 oder nach 15
    /// Minuten (throttle, damit der Partner auch offline zeitnah nachzieht, ohne die Warteschlange
    /// mit einer Op pro Schritt zu fluten).
    static func sollSenden(anzahl: Int, zuletzt: (datum: String, anzahl: Int)?, heutigerTag: String, vergangen: TimeInterval) -> Bool {
        guard let zuletzt, zuletzt.datum == heutigerTag else { return true }
        return abs(anzahl - zuletzt.anzahl) >= 50 || vergangen >= 15 * 60
    }

    /// Wendet eine `schritte.setzen`-Op auf die heutigen Zahlen an. Ops für einen anderen Tag werden
    /// verworfen; Überschreiben pro `von` ist sicher, da `Raum` Ops in `seq`-Reihenfolge zustellt und
    /// jede Veröffentlichung die volle Tagessumme trägt (kein Aufaddieren nötig).
    static func falten(_ heute: inout [Person: Int], von: Person, datum: String, anzahl: Int, heutigerTag: String) {
        guard datum == heutigerTag else { return }
        heute[von] = anzahl
    }
}
