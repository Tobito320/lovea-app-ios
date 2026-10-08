import Foundation
import Observation

/// Umarmung: beide haben das Profil gerade offen. Läuft über `Raum.fluechtig("zimmer.da")` (nur WebSocket,
/// nichts wird gespeichert). Lebenszeichen alle 10 s, gilt 25 s. Nur aktiv, solange die Szene sichtbar ist.
@MainActor @Observable
final class ZimmerUmarmung {
    static let shared = ZimmerUmarmung()

    private(set) var umarmt = false

    @ObservationIgnored private var ichDa = false
    @ObservationIgnored private var partnerBis = Date.distantPast
    @ObservationIgnored private var lauf: Task<Void, Never>?

    private struct DaD: Codable {
        var an: Bool
        var antwort: Bool
    }

    private init() {
        Raum.shared.fluechtigBeobachten("zimmer.da") { [weak self] person, daten in
            guard person != Raum.shared.ich, let d = try? JSONDecoder().decode(DaD.self, from: daten) else { return }
            self?.empfangen(d)
        }
    }

    private func empfangen(_ d: DaD) {
        if d.an {
            partnerBis = Date().addingTimeInterval(25)
            // Wer dazukommt, bekommt sofort ein Lebenszeichen zurück (aber keine Endlosschleife: Antwort antwortet nicht).
            if ichDa, !d.antwort { senden(an: true, antwort: true) }
        } else {
            partnerBis = .distantPast
        }
        neuBerechnen()
    }

    /// Die Szene ist sichtbar (Profil offen, App aktiv, Panorama im Bild) oder nicht.
    func sichtbar(_ da: Bool) {
        guard da != ichDa else { return }
        ichDa = da
        lauf?.cancel()
        lauf = nil
        if da {
            senden(an: true, antwort: false)
            lauf = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    guard !Task.isCancelled, let self else { return }
                    self.senden(an: true, antwort: true)
                    self.neuBerechnen()
                }
            }
        } else {
            senden(an: false, antwort: false)
        }
        neuBerechnen()
    }

    private func senden(an: Bool, antwort: Bool) {
        Raum.shared.fluechtig("zimmer.da", DaD(an: an, antwort: antwort))
    }

    private func neuBerechnen() {
        let neu = ZimmerRitualeLogik.umarmt(ichDa: ichDa, partnerBis: partnerBis, jetzt: Date())
        if neu != umarmt { umarmt = neu }
    }
}
