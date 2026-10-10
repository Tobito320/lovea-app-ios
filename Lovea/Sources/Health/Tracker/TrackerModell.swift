import Foundation
import Observation

/// Verbindung zum iSo-Tech-Tracker (H59MAX), nur für Ahmed. Hält die Tage, die der Tracker geliefert hat
/// (`BandTage`, auf dem Gerät gespeichert), und meldet Änderungen an `HealthModell`: dessen Tageswert
/// ist der größere von Tracker und iPhone. Der Tracker schreibt absichtlich nichts in Apple Health, sonst
/// zählt Health dieselben Schritte doppelt.
///
/// Wann abgefragt wird: bei jeder Verbindung (auch wenn iOS die App dafür im Hintergrund weckt), beim
/// Start, beim Öffnen der App und danach alle zehn Minuten, solange die Verbindung steht. Der Tracker
/// selbst sendet nach dem Trennen erst wieder, wenn man ihn antippt; öfter als er will geht es nicht.
@MainActor
@Observable
final class TrackerModell {
    static let shared = TrackerModell()

    enum Zustand: Equatable {
        case getrennt, sucht, nichtGefunden, wartet, verbunden
        case bluetoothAus, nichtErlaubt, nichtVerfuegbar
        case fehler(String)
    }

    /// Wie viele Tage zurück eine volle Abfrage geht (heute = 1), und wie viele die kurze.
    static let tageVoll = 7
    static let tageKurz = 2
    /// Eine volle Abfrage, wenn die letzte so lange her ist.
    private static let vollNach: TimeInterval = 12 * 3600
    /// So lange ohne Antwort, dann gilt die Frage als beantwortet und die nächste geht raus.
    private static let ruhe: Duration = .seconds(3)
    private static let intervall: Duration = .seconds(600)
    private static let nameSchluessel = "lovea.tracker.name"
    private static let pauseSchluessel = "lovea.tracker.pause"

    private(set) var zustand: Zustand = .getrennt
    private(set) var gekoppelt = TrackerFunk.gemerkteKennung != nil
    private(set) var name: String? = UserDefaults.standard.string(forKey: TrackerModell.nameSchluessel)
    private(set) var akku: TrackerProtokoll.Akku?
    private(set) var pulsEinstellung: TrackerProtokoll.PulsEinstellung?
    private(set) var bandTage = BandTage.laden()
    private(set) var abfrageLaeuft = false

    private var funk: TrackerFunk?
    /// Ahmed hat "Trennen" getippt: dann nicht von selbst wieder verbinden, auch nicht nach einem Neustart.
    private var pausiert = UserDefaults.standard.bool(forKey: TrackerModell.pauseSchluessel)
    private var offeneAnfragen: [Data] = []
    private var anfrageNr = 0
    private var planNr = 0
    private var schrittAntwort = false
    /// Zeilen vom Tracker, die `HealthModell` vielleicht noch nicht kennt. Beim Start gilt Gespeichertes
    /// als ungemeldet: der letzte Lauf kann im Hintergrund geendet sein, bevor die Person bekannt war.
    private var ungemeldet = true

    private init() {}

    // MARK: Aktionen

    /// App-Start (auch im Hintergrund), Vordergrund und Öffnen der Seite: wieder verbinden, wenn gekoppelt
    /// und nicht absichtlich getrennt. Die Bluetooth-Abfrage kommt so erst, wenn Ahmed "Tracker suchen" getippt hat.
    func fortsetzen() {
        guard gekoppelt, !pausiert else { return }
        bandMelden()
        if funk == nil {
            verbinden()
        } else if zustand == .verbunden {
            if Date().timeIntervalSince(bandTage.stand ?? .distantPast) > 120 { abfragen() }
        } else {
            funk?.starten()
        }
    }

    func verbinden() {
        pausiert = false
        UserDefaults.standard.set(false, forKey: Self.pauseSchluessel)
        if funk == nil {
            funk = TrackerFunk { [weak self] ereignis in
                Task { @MainActor in self?.verarbeiten(ereignis) }
            }
        }
        funk?.starten()
    }

    func trennen() {
        pausiert = true
        UserDefaults.standard.set(true, forKey: Self.pauseSchluessel)
        abbrechen()
        funk?.trennen(vergessen: false)
    }

    func vergessen() {
        pausiert = true
        UserDefaults.standard.set(true, forKey: Self.pauseSchluessel)
        abbrechen()
        funk?.trennen(vergessen: true)
        gekoppelt = false
        name = nil
        akku = nil
        pulsEinstellung = nil
        bandTage = BandTage()
        BandTage.loeschen()
        UserDefaults.standard.removeObject(forKey: Self.nameSchluessel)
    }

    /// Fragt Akku, Puls-Einstellung und die Schritte der letzten Tage der Reihe nach ab (jede Antwort
    /// löst die nächste Frage aus, bei Schweigen nach `ruhe` die nächste von selbst).
    func abfragen() {
        guard zustand == .verbunden, !abfrageLaeuft else { return }
        abfrageLaeuft = true
        schrittAntwort = false
        let voll = Date().timeIntervalSince(bandTage.stand ?? .distantPast) > Self.vollNach
        let tage = voll ? Self.tageVoll : Self.tageKurz
        offeneAnfragen = [TrackerProtokoll.pulsEinstellungAnfrage] + (0..<tage).map { TrackerProtokoll.schritteAnfrage(tagVersatz: $0) }
        senden(TrackerProtokoll.akkuAnfrage)
    }

    // MARK: Anzeige

    var statusText: String {
        switch zustand {
        case .getrennt: return gekoppelt ? "Getrennt" : "Nicht verbunden"
        case .sucht: return "Sucht den Tracker"
        case .nichtGefunden: return "Nicht gefunden"
        case .wartet: return "Wartet auf den Tracker"
        case .verbunden: return abfrageLaeuft ? "Verbunden, liest" : "Verbunden"
        case .bluetoothAus: return "Bluetooth ist aus"
        case .nichtErlaubt: return "Bluetooth nicht erlaubt"
        case .nichtVerfuegbar: return "Bluetooth nicht verfügbar"
        case .fehler(let text): return text
        }
    }

    /// Der Tag heute laut Tracker; `nil`, solange er für heute nichts geliefert hat.
    var heute: BandTag? { bandTage.tage[Datum.text(Date())] }

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
            if let geraetename {
                name = geraetename
                UserDefaults.standard.set(geraetename, forKey: Self.nameSchluessel)
            }
            abfragen()
        case .getrennt:
            abbrechen()
            zustand = pausiert ? .getrennt : .wartet
        case .fehler(let text):
            abbrechen()
            zustand = .fehler(text)
        case .daten(let daten):
            antwortVerarbeiten(daten)
        }
    }

    private func antwortVerarbeiten(_ daten: Data) {
        switch TrackerProtokoll.lesen(daten) {
        case .akku(let wert):
            akku = wert
            naechsteAnfrage()
        case .pulsEinstellung(let wert):
            pulsEinstellung = wert
            naechsteAnfrage()
        case .schritteKopf:
            schrittAntwort = true
        case .schritte(let zeile):
            schrittAntwort = true
            bandTage.aufnehmen(zeile)
            ungemeldet = true
            if zeile.letzte { naechsteAnfrage() }
        case .schritteEnde:
            schrittAntwort = true
            naechsteAnfrage()
        case .unbekannt, nil:
            break
        }
    }

    // MARK: Abfrage-Ablauf

    private func senden(_ daten: Data) {
        anfrageNr += 1
        let nr = anfrageNr
        funk?.senden(daten)
        Task { [weak self] in
            try? await Task.sleep(for: Self.ruhe)
            guard let self, nr == self.anfrageNr else { return }
            self.naechsteAnfrage()
        }
    }

    private func naechsteAnfrage() {
        guard abfrageLaeuft else { return }
        bandTage.speichern()
        guard !offeneAnfragen.isEmpty else { abschliessen(); return }
        senden(offeneAnfragen.removeFirst())
    }

    private func abschliessen() {
        anfrageNr += 1
        abfrageLaeuft = false
        // Ohne eine einzige Schritt-Antwort ist nichts gelesen worden: dann bleibt der Stand alt.
        if schrittAntwort { bandTage.stand = .now }
        bandTage.kuerzen(heute: Datum.text(Date()))
        bandTage.speichern()
        bandMelden()
        naechsteAbfragePlanen()
    }

    /// Bricht eine laufende Abfrage ab (Verbindung weg, getrennt, vergessen). Was schon gelesen ist, bleibt.
    private func abbrechen() {
        anfrageNr += 1
        planNr += 1
        abfrageLaeuft = false
        offeneAnfragen = []
        bandTage.speichern()
        bandMelden()
    }

    private func naechsteAbfragePlanen() {
        planNr += 1
        let nr = planNr
        Task { [weak self] in
            try? await Task.sleep(for: Self.intervall)
            guard let self, nr == self.planNr, self.zustand == .verbunden else { return }
            self.abfragen()
        }
    }

    /// Neue Tracker-Zahlen an Health weitergeben. Erst wenn die Person bekannt ist (ein Start im
    /// Hintergrund hat sie vielleicht noch nicht); `fortsetzen()` holt es beim nächsten Öffnen nach.
    private func bandMelden() {
        guard ungemeldet, !bandTage.tage.isEmpty, Raum.shared.ich != nil else { return }
        ungemeldet = false
        HealthModell.shared.bandSchritteNeu()
    }
}
