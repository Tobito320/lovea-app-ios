import Foundation
import Observation

/// Heutiger Tag einer Person ("Ahmeds Tag"): Schritte-Marken, Gym und Herzen aus den gesyncten Ops,
/// Schlaf aus `HealthModell`, Fotos und Snaps aus dem Chat. Eigene Ops kommen doppelt an (optimistisch,
/// dann bestätigt): jeder Moment hat deshalb eine feste ID, die erste gewinnt.
@MainActor @Observable
final class TagModell {
    static let shared = TagModell()

    private var roh: [Person: [String: TagMoment]] = [:]
    private static let schrittMarken = [2_000, 5_000, 8_000, 10_000, 12_000, 15_000, 20_000, 25_000, 30_000]

    private init() {
        Raum.shared.beobachten(["schritte.setzen", "gym.checkin", "gym.checkout", "gym.loeschen", "geste"]) { [weak self] op in
            self?.aufnehmen(op)
        }
    }

    func ansicht(person: Person, tag: Date) -> [TagMoment] {
        var momente = Array((roh[person] ?? [:]).values)
        if let nacht = HealthModell.shared.schlafNacht(person, Datum.text(tag)), nacht.minuten > 0 {
            momente.append(TagMoment(id: "schlaf", zeit: nacht.bis, sorte: .schlaf,
                                     text: "Aufgewacht · \(nacht.minuten / 60) Std. \(nacht.minuten % 60) Min. geschlafen"))
        }
        let start = Calendar.berlin.startOfDay(for: tag)
        // Neueste zuerst; eine Stunde Luft, weil die Liste nicht streng nach Zeit sortiert sein muss.
        for n in ChatModell.shared.nachrichten.reversed().prefix(while: { $0.zeit > start.addingTimeInterval(-3600) })
        where n.von == person && !n.geloescht && n.system == nil {
            if n.snap != nil {
                momente.append(TagMoment(id: "snap-\(n.id)", zeit: n.zeit, sorte: .snap, text: "Snap geschickt"))
            } else if n.medien.contains(where: { $0.typ == "foto" }) {
                momente.append(TagMoment(id: "foto-\(n.id)", zeit: n.zeit, sorte: .foto, text: "Foto geschickt"))
            }
        }
        return TagLogik.zeitleiste(momente, tag: tag)
    }

    /// Letzter Moment von heute mit Uhrzeit, `nil` ohne Momente (Karte, Widget).
    func letzterMoment(person: Person) -> String? {
        ansicht(person: person, tag: Date()).last.map { "\(Datum.uhrzeit($0.zeit)) \($0.anzeige)" }
    }

    private struct SchritteRoh: Decodable { let datum: String; let anzahl: Int; let nachgetragen: Bool? }

    private func aufnehmen(_ op: Op) {
        switch op.art {
        case "schritte.setzen":
            // Nur der Stand von heute, den das Handy selbst meldet; springt er über mehrere Marken, zählt die höchste.
            guard let d = op.daten(SchritteRoh.self), d.nachgetragen != true, d.datum == Datum.text(op.zeit),
                  let marke = Self.schrittMarken.last(where: { d.anzahl >= $0 }) else { return }
            ablegen(TagMoment(id: "schritte-\(d.datum)-\(marke)", zeit: op.zeit, sorte: .schritte,
                              text: "\(marke / 1000).000 Schritte geschafft"), von: op.von)
        case "gym.checkin":
            guard let d = op.daten(GymD.self), let start = d.start else { return }
            ablegen(TagMoment(id: "gym-start-\(d.session)", zeit: start, sorte: .gym, text: "Los geht’s im Gym"), von: op.von)
        case "gym.checkout":
            // Nur das echte Beenden; reine Zeitkorrekturen tragen weder Dauer noch Sätze.
            guard let d = op.daten(GymD.self), d.status == "ende" else { return }
            let teile = ["Training beendet", d.minuten.map { "\($0) Min." }, d.zahl.map { "\($0) Sätze" }].compactMap { $0 }
            ablegen(TagMoment(id: "gym-ende-\(d.session)", zeit: d.ende ?? op.zeit, sorte: .gym,
                              text: teile.joined(separator: " · ")), von: op.von)
        case "gym.loeschen":
            guard let d = op.daten(GymD.self) else { return }
            roh[op.von]?["gym-start-\(d.session)"] = nil
            roh[op.von]?["gym-ende-\(d.session)"] = nil
        case "geste":
            guard op.daten([String: String].self)?["art"] == "herz" else { return }
            ablegen(TagMoment(id: "herz-\(op.id)", zeit: op.zeit, sorte: .herz, text: "Denk an dich geschickt"), von: op.von)
        default:
            break
        }
    }

    private func ablegen(_ moment: TagMoment, von person: Person) {
        guard Calendar.berlin.isDateInToday(moment.zeit), roh[person]?[moment.id] == nil else { return }
        roh[person, default: [:]][moment.id] = moment
    }
}
