import Foundation
import Observation

/// Eine Sprachpost: aufgenommen, hochgeladen, nie live. Spielt nie von allein ab.
struct Sprachpost: Hashable, Identifiable, Sendable {
    var id: String
    var medienId: String
    var dauer: Double
    var pegel: [Float]
    var von: Person
    var zeit: Date
}

struct SprachpostD: Codable, Hashable, Sendable {
    var id: String
    var medienId: String
    var dauer: Double
    var pegel: [Float]
}

struct SprachpostGehoertD: Codable, Hashable, Sendable { var id: String }

struct SprachpostStand: Sendable, Equatable {
    var posten: [String: Sprachpost] = [:]
    var gehoert: [String: Date] = [:]
}

enum SprachpostLogik {
    static let artNeu = "sprachpost.neu"
    static let artGehoert = "sprachpost.gehoert"
    static let arten: Set<String> = [artNeu, artGehoert]

    /// Kürzer ist ein versehentliches Antippen.
    static let mindestDauer: TimeInterval = 1

    static func anwenden(_ ops: [Op], auf start: SprachpostStand = SprachpostStand()) -> SprachpostStand {
        var z = start
        for op in ops {
            switch op.art {
            case artNeu:
                guard let d = op.daten(SprachpostD.self) else { continue }
                z.posten[d.id] = Sprachpost(id: d.id, medienId: d.medienId, dauer: d.dauer, pegel: d.pegel, von: op.von, zeit: op.zeit)
            case artGehoert:
                guard let d = op.daten(SprachpostGehoertD.self) else { continue }
                z.gehoert[d.id] = min(z.gehoert[d.id] ?? op.zeit, op.zeit)
            default:
                break
            }
        }
        return z
    }

    /// Neueste zuerst.
    static func liste(_ stand: SprachpostStand) -> [Sprachpost] {
        stand.posten.values.sorted { a, b in a.zeit != b.zeit ? a.zeit > b.zeit : a.id < b.id }
    }

    static func istUngehoert(_ p: Sprachpost, _ stand: SprachpostStand, ich: Person) -> Bool {
        p.von != ich && stand.gehoert[p.id] == nil
    }

    static func ungehoert(_ stand: SprachpostStand, ich: Person) -> Int {
        stand.posten.values.filter { istUngehoert($0, stand, ich: ich) }.count
    }
}

@MainActor @Observable
final class SprachpostSpeicher {
    static let shared = SprachpostSpeicher()

    private(set) var stand = SprachpostStand()

    @ObservationIgnored private let wer: () -> Person?
    @ObservationIgnored private let ausgang: (Op) -> Void

    init(ich: @escaping () -> Person?, senden: @escaping (Op) -> Void) {
        self.wer = ich
        self.ausgang = senden
    }

    private convenience init() {
        self.init(ich: { Raum.shared.ich }, senden: { Raum.shared.einreihen($0) })
        Raum.shared.beobachtenStapel(SprachpostLogik.arten) { [weak self] ops in self?.einarbeiten(ops) }
    }

    func einarbeiten(_ ops: [Op]) { stand = SprachpostLogik.anwenden(ops, auf: stand) }

    var ich: Person? { wer() }
    var liste: [Sprachpost] { SprachpostLogik.liste(stand) }
    var ungehoert: Int { wer().map { SprachpostLogik.ungehoert(stand, ich: $0) } ?? 0 }

    func ungehoert(_ p: Sprachpost) -> Bool { wer().map { SprachpostLogik.istUngehoert(p, stand, ich: $0) } ?? false }

    /// Zu kurze Aufnahmen: nil.
    @discardableResult
    func abschicken(medienId: String, dauer: Double, pegel: [Float]) -> Sprachpost? {
        guard dauer >= SprachpostLogik.mindestDauer, let ich = wer() else { return nil }
        let d = SprachpostD(id: "post-" + UUID().uuidString, medienId: medienId, dauer: dauer, pegel: pegel)
        let op = Op.neu(SprachpostLogik.artNeu, d, von: ich)
        stand = SprachpostLogik.anwenden([op], auf: stand)
        ausgang(op)
        return stand.posten[d.id]
    }

    /// Beim Abspielen: nur Empfängerin, nur einmal.
    func alsGehoert(_ p: Sprachpost) {
        guard let ich = wer(), p.von != ich, stand.gehoert[p.id] == nil else { return }
        let op = Op.neu(SprachpostLogik.artGehoert, SprachpostGehoertD(id: p.id), von: ich)
        stand = SprachpostLogik.anwenden([op], auf: stand)
        ausgang(op)
    }
}
