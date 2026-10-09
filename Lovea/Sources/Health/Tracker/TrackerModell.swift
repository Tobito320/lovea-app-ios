import Foundation
import Observation

/// Zustand der Verbindung zum iSo-Tech-Tracker (H59MAX), nur für Ahmed. Rein lokal: nichts davon
/// geht in den Raum, zu Annika oder in Health. Absichtlich kein Aufruf von `schritteEintragen` oder
/// `schlafEintragen`, solange die Schritt-Dekodierung nicht mit QWatch Pro verglichen ist.
@MainActor
@Observable
final class TrackerModell {
    static let shared = TrackerModell()

    enum Zustand: Equatable {
        case getrennt, sucht, nichtGefunden, wartet, verbunden
        case bluetoothAus, nichtErlaubt, nichtVerfuegbar
        case fehler(String)
    }

    private(set) var zustand: Zustand = .getrennt
    private(set) var gekoppelt = TrackerFunk.gemerkteKennung != nil
    private(set) var name: String?
    private(set) var akku: TrackerProtokoll.Akku?
    private(set) var pulsEinstellung: TrackerProtokoll.PulsEinstellung?
    /// Summe der Antwortzeilen von heute. Nicht belegt, nur zum Vergleich mit QWatch Pro.
    private(set) var testSchritte: Int?
    private(set) var aktualisiert: Date?

    private var funk: TrackerFunk?
    private var manuellGetrennt = false
    private var offeneAnfragen: [Data] = []
    private var schrittSlots: [Int: Int] = [:]

    private init() {}

    // MARK: Aktionen

    /// Beim Öffnen der Seite: nur selbst verbinden, wenn der Tracker schon gekoppelt ist. Die
    /// Bluetooth-Abfrage kommt so erst, wenn Ahmed "Tracker suchen" tippt.
    func beimOeffnen() {
        guard gekoppelt, funk == nil, !manuellGetrennt else { return }
        verbinden()
    }

    func verbinden() {
        manuellGetrennt = false
        if funk == nil {
            funk = TrackerFunk { [weak self] ereignis in
                Task { @MainActor in self?.verarbeiten(ereignis) }
            }
        }
        funk?.starten()
    }

    func trennen() {
        manuellGetrennt = true
        funk?.trennen(vergessen: false)
    }

    func vergessen() {
        manuellGetrennt = true
        funk?.trennen(vergessen: true)
        gekoppelt = false
        name = nil
        akku = nil
        pulsEinstellung = nil
        testSchritte = nil
        aktualisiert = nil
    }

    /// Fragt Akku, Puls-Einstellung und Schritte der Reihe nach ab (jede Antwort löst die nächste Frage aus).
    func abfragen() {
        guard zustand == .verbunden else { return }
        offeneAnfragen = [TrackerProtokoll.pulsEinstellungAnfrage, TrackerProtokoll.schritteHeuteAnfrage]
        schrittSlots = [:]
        funk?.senden(TrackerProtokoll.akkuAnfrage)
    }

    // MARK: Anzeige

    var statusText: String {
        switch zustand {
        case .getrennt: return gekoppelt ? "Getrennt" : "Nicht verbunden"
        case .sucht: return "Sucht den Tracker"
        case .nichtGefunden: return "Nicht gefunden"
        case .wartet: return "Wartet auf den Tracker"
        case .verbunden: return "Verbunden"
        case .bluetoothAus: return "Bluetooth ist aus"
        case .nichtErlaubt: return "Bluetooth nicht erlaubt"
        case .nichtVerfuegbar: return "Bluetooth nicht verfügbar"
        case .fehler(let text): return text
        }
    }

    // MARK: Ereignisse

    private func verarbeiten(_ ereignis: TrackerEreignis) {
        switch ereignis {
        case .bluetooth(let status):
            switch status {
            case .an: break
            case .aus: zustand = .bluetoothAus
            case .nichtErlaubt: zustand = .nichtErlaubt
            case .nichtVerfuegbar: zustand = .nichtVerfuegbar
            }
        case .sucht: zustand = .sucht
        case .nichtGefunden: zustand = .nichtGefunden
        case .verbindet: zustand = .wartet
        case .verbunden(let geraetename):
            zustand = .verbunden
            gekoppelt = true
            name = geraetename ?? name
            abfragen()
        case .getrennt:
            zustand = manuellGetrennt ? .getrennt : .wartet
        case .fehler(let text):
            zustand = .fehler(text)
        case .daten(let daten):
            antwortVerarbeiten(daten)
        }
    }

    private func antwortVerarbeiten(_ daten: Data) {
        switch TrackerProtokoll.lesen(daten) {
        case .akku(let wert):
            akku = wert
            aktualisiert = .now
            naechsteAnfrage()
        case .pulsEinstellung(let wert):
            pulsEinstellung = wert
            naechsteAnfrage()
        case .schritte(let slot):
            schrittSlots[slot.slot] = slot.schritte
            testSchritte = schrittSlots.values.reduce(0, +)
        case .unbekannt, nil:
            break
        }
    }

    private func naechsteAnfrage() {
        guard !offeneAnfragen.isEmpty else { return }
        funk?.senden(offeneAnfragen.removeFirst())
    }
}
