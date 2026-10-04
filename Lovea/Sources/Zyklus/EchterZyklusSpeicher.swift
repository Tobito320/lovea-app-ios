import Foundation
import Observation

/// Annikas echte Daten: lokal als JSON abgelegt, jede Änderung geht als `zyklus.*`-Op an den Raum.
/// Abhängigkeiten kommen als Parameter, damit Tests und die Verdrahtung nichts Fremdes brauchen.
@MainActor
@Observable
final class EchterZyklusSpeicher: ZyklusSpeicher {
    let quelle: ZyklusQuelle = .echt

    private(set) var stand: ZyklusStand
    private let datei: URL?
    private let ich: () -> Person?
    private let sende: (Op) -> Void

    var tage: [String: ZyklusTag] { stand.tage }

    var einstellung: ZyklusEinstellung {
        get { stand.einstellung }
        set {
            guard newValue != stand.einstellung, let person = ich(), person == .annika else { return }
            uebernehmen(ZyklusOps.einstellungOp(newValue, von: person))
        }
    }

    init(datei: URL?, ich: @escaping () -> Person?, sende: @escaping (Op) -> Void) {
        self.datei = datei
        self.ich = ich
        self.sende = sende
        if let datei, let daten = try? Data(contentsOf: datei),
           let s = try? JSONDecoder().decode(ZyklusStand.self, from: daten) {
            stand = s
        } else {
            stand = ZyklusStand()
        }
    }

    /// Ablage in Application Support, Senden und Empfangen über den gemeinsamen Raum.
    static func standard() -> EchterZyklusSpeicher {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return EchterZyklusSpeicher(
            datei: ordner.appendingPathComponent("zyklus.json"),
            ich: { Raum.shared.ich },
            sende: { Raum.shared.einreihen($0) })
    }

    /// Einmal beim Start: Verlauf nachspielen und neue Ops anwenden.
    func beobachten() {
        Raum.shared.beobachten(ZyklusOps.arten) { [weak self] op in
            Task { @MainActor in self?.empfangen(op) }
        }
    }

    func setze(_ tag: ZyklusTag) {
        guard let person = ich(), person == .annika else { return }
        uebernehmen(ZyklusOps.tagOp(tag, von: person))
    }

    /// Eingehende Op, auch die eigene Bestätigung vom Server. Ahmeds Gerät verwirft sie.
    func empfangen(_ op: Op) {
        if stand.anwenden(op, ich: ich()) { sichern() }
    }

    private func uebernehmen(_ op: Op) {
        guard stand.anwenden(op, ich: ich()) else { return }
        sichern()
        sende(op)
    }

    private func sichern() {
        guard let datei, let daten = try? JSONEncoder().encode(stand) else { return }
        try? daten.write(to: datei, options: .atomic)
    }
}
