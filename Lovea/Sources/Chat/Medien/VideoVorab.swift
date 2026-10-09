import Foundation

/// Schalter „Videos vorab hochladen (Test)" (Einstellungen, Standard an). Ein gewähltes Video wird
/// schon im Anhang-Streifen kodiert und hochgeladen, wie ein Foto; beim Senden geht nur noch die Op
/// raus. Aus: wie vorher, alles erst beim Senden. Hier nur die Entscheidungen, ohne Export und Upload;
/// die Arbeit selbst steht in `ChatMedien` (MedienSenden.swift).
enum VideoVorab {
    static let schluessel = "lovea.videoVorab"

    /// Stand eines Anhangs, wenn gesendet wird.
    enum Stand: Equatable {
        case keiner       // kein Vorab gestartet (Schalter aus, oder schon eins am Laufen)
        case offen        // Vorab läuft oder ist fertig, das Ergebnis ist noch nicht abgeholt
        case fertig       // kodiert und hochgeladen
        case nurKodiert   // kodiert, Upload gescheitert
        case gescheitert  // Kodierung gescheitert oder abgebrochen
    }

    enum Weg: Equatable {
        case nurOp            // nur `nachricht.neu`, die Datei liegt schon auf dem Server
        case aufEndeWarten    // erst das Vorab-Ergebnis abwarten, dann neu entscheiden
        case opDannHochladen  // Kodierung steht, Op raus, Upload über die Warteschlange
        case heutigerWeg      // alles beim Senden, wie vorher
    }

    static func an(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: schluessel) as? Bool ?? true
    }

    /// Immer nur ein Vorab zugleich: zwei Exporte und Uploads gleichzeitig kosten mehr Akku und
    /// Funk als sie bringen. Weitere Videos laufen beim Senden wie vorher.
    static func starten(schalter: Bool, laufende: Int) -> Bool {
        schalter && laufende == 0
    }

    /// Abbrechen, was nicht mehr im Entwurf steht (entfernt). Was gesendet wird, ist vorher aus der
    /// Liste genommen und wird nie abgebrochen.
    static func abzubrechen(offen: Set<UUID>, imEntwurf: Set<UUID>) -> Set<UUID> {
        offen.subtracting(imEntwurf)
    }

    static func stand(kodiert: Bool, hochgeladen: Bool) -> Stand {
        guard kodiert else { return .gescheitert }
        return hochgeladen ? .fertig : .nurKodiert
    }

    static func weg(beimSenden stand: Stand) -> Weg {
        switch stand {
        case .keiner, .gescheitert: .heutigerWeg
        case .offen: .aufEndeWarten
        case .fertig: .nurOp
        case .nurKodiert: .opDannHochladen
        }
    }
}
