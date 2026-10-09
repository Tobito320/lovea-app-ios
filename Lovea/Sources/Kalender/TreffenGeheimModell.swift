import Foundation
import Observation

/// Der Inhalt der eigenen versteckten Treffen-Punkte. Kommt als `entwurf.setzen` mit dem Schlüssel
/// `treffenGeheim` an: der Server gibt diese Art nur an den Absender zurück, der Partner sieht nur die
/// Platzhalter-Op. Der Chat-Entwurf ignoriert diese Ops (`EntwurfFaltung`).
@MainActor @Observable
final class TreffenGeheimModell {
    static let shared = TreffenGeheimModell()

    private(set) var punkte: [String: GeheimPunkt] = [:]

    private init() {
        Raum.shared.beobachtenStapel(["entwurf.setzen"]) { [weak self] ops in
            guard let self, let ich = Raum.shared.ich else { return }
            var neu = self.punkte
            Self.falten(ops, ich: ich, in: &neu)
            if neu != self.punkte { self.punkte = neu }
        }
    }

    /// Je Id gewinnt die neuere Op-Zeit (Id als Gleichstand); ein Grabstein bleibt. Doppelte
    /// Zustellung (eigenes Echo mit `seq`) ändert nichts.
    nonisolated static func falten(_ ops: [Op], ich: Person, in punkte: inout [String: GeheimPunkt]) {
        for op in ops where op.art == "entwurf.setzen" && op.von == ich {
            guard let huelle = op.daten(GeheimHuelle.self), let neu = GeheimPunkt(huelle.treffenGeheim, zeit: op.zeit) else { continue }
            if let alt = punkte[neu.id], alt.geloescht || (neu.zeit < alt.zeit && !neu.geloescht) { continue }
            punkte[neu.id] = neu
        }
    }
}
