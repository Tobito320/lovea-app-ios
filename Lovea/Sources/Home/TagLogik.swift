import Foundation

/// Ein Eintrag in "Ahmeds Tag". Fotos, Snaps und Herzen kurz hintereinander werden zu einem mit `anzahl`.
struct TagMoment: Equatable, Identifiable, Sendable {
    enum Sorte: Sendable {
        case schlaf, schritte, gym, foto, snap, herz

        var symbol: String {
            switch self {
            case .schlaf: "sunrise.fill"
            case .schritte: "figure.walk"
            case .gym: "dumbbell.fill"
            case .foto: "camera.fill"
            case .snap: "flame.fill"
            case .herz: "heart.fill"
            }
        }
    }

    let id: String
    let zeit: Date
    let sorte: Sorte
    let text: String
    var anzahl = 1

    var anzeige: String { anzahl > 1 ? "\(anzahl)× \(text)" : text }
}

enum TagLogik {
    static let gruppenFenster: TimeInterval = 30 * 60

    /// Momente eines Berliner Kalendertags: nach Zeit sortiert, gleiche Fotos/Snaps/Herzen
    /// innerhalb von `gruppenFenster` nach der ersten zusammengefasst.
    static func zeitleiste(_ roh: [TagMoment], tag: Date, kalender: Calendar = .berlin) -> [TagMoment] {
        let start = kalender.startOfDay(for: tag)
        guard let ende = kalender.date(byAdding: .day, value: 1, to: start) else { return [] }
        var leiste: [TagMoment] = []
        for m in roh.filter({ $0.zeit >= start && $0.zeit < ende }).sorted(by: { ($0.zeit, $0.id) < ($1.zeit, $1.id) }) {
            if [.foto, .snap, .herz].contains(m.sorte),
               let i = leiste.lastIndex(where: { $0.sorte == m.sorte }),
               m.zeit.timeIntervalSince(leiste[i].zeit) <= gruppenFenster {
                leiste[i].anzahl += 1
            } else {
                leiste.append(m)
            }
        }
        return leiste
    }
}
