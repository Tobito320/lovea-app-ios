import Foundation

/// Was die Zeitschätzung dem Tag rät, wenn er über das Studio-Fenster geht.
enum ZeitTipp: Equatable, Sendable {
    /// Zwei Übungen nebeneinander abwechselnd machen: eine Pause statt zwei.
    case supersatz(erste: String, zweite: String, spart: Int)
    /// Die letzten Übungen weglassen.
    case streichen(namen: [String], spart: Int)

    var text: String {
        switch self {
        case let .supersatz(a, b, spart): "Tipp: \(a) und \(b) als Supersatz, spart ca. \(spart) min."
        case let .streichen(namen, spart): "Tipp: \(namen.joined(separator: ", ")) weglassen, spart ca. \(spart) min."
        }
    }
}

/// Schätzung für einen Trainingstag gegen das Zeitfenster des Studios (`slot` nil = kein festes Fenster).
struct ZeitUrteil: Equatable, Sendable {
    var minuten: Int
    var slot: Int?
    var tipp: ZeitTipp?

    var ueber: Int { slot.map { max(0, minuten - $0) } ?? 0 }
    var warnt: Bool { ueber > 0 }

    /// "ca. 52 min, 7 min über deinem Slot (45 min)", "ca. 38 min, passt in deinen Slot (45 min)", "ca. 38 min".
    var titel: String {
        guard let slot else { return "ca. \(minuten) min" }
        return warnt ? "ca. \(minuten) min, \(ueber) min über deinem Slot (\(slot) min)" : "ca. \(minuten) min, passt in deinen Slot (\(slot) min)"
    }
}

/// Dauer eines Trainingstags aus Sätzen, Pausen und Wechseln.
// ponytail: Alle Zahlen unten sind Schätzungen, nicht gemessen. Satz ca. 40 s, Pause aus dem Plan (sonst 90 s),
// Wechsel zur nächsten Übung ca. 60 s. Gemessen wird erst, wenn Ahmed am Gerät Abweichungen meldet.
enum ZeitSchaetzung {
    static let satzSekunden = 40
    static let standardPauseSekunden = 90
    static let wechselSekunden = 60

    /// Pause nach einem Satz: die der Übung, sonst Standard (0 heißt im Plan "ohne Ziel", nicht "ohne Pause").
    static func pause(_ u: PlanUebung) -> Int {
        guard let p = u.pause, p > 0 else { return standardPauseSekunden }
        return p
    }

    /// Eine Übung allein oder ein Supersatz-Paar (`supersatz` an der ersten). Cardio zählt nie als Paar.
    private static func bloecke(_ uebungen: [PlanUebung]) -> [[PlanUebung]] {
        var aus: [[PlanUebung]] = []
        var i = 0
        while i < uebungen.count {
            let u = uebungen[i]
            if u.supersatz == true, !u.istCardio, i + 1 < uebungen.count, !uebungen[i + 1].istCardio {
                aus.append([u, uebungen[i + 1]])
                i += 2
            } else {
                aus.append([u])
                i += 1
            }
        }
        return aus
    }

    /// Sekunden für einen Block. Paar: alle Sätze beider Übungen, aber nur eine Pause pro Runde.
    private static func sekunden(_ block: [PlanUebung]) -> Int {
        if block.count == 1, let c = block.first, c.istCardio { return (c.minuten ?? 0) * 60 + wechselSekunden }
        let runden = block.map { $0.saetze.count }.max() ?? 0
        guard runden > 0 else { return 0 }
        let saetze = block.reduce(0) { $0 + $1.saetze.count }
        let rast = block.map { ZeitSchaetzung.pause($0) }.max() ?? standardPauseSekunden
        return saetze * satzSekunden + (runden - 1) * rast + wechselSekunden
    }

    private static func minuten(sekunden: Int) -> Int { (sekunden + 59) / 60 }

    static func sekunden(_ tag: TrainingsTag) -> Int { bloecke(tag.uebungen).reduce(0) { $0 + sekunden($1) } }

    /// Aufgerundet auf ganze Minuten. Leerer Tag: 0.
    static func minuten(_ tag: TrainingsTag) -> Int { minuten(sekunden: sekunden(tag)) }

    /// Das Zeitfenster aus dem Studio-Profil: nur mit fester Uhrzeit (`slotStart`), sonst gibt es nichts zu überschreiten.
    static func slot(_ profil: StudioProfil) -> Int? { profil.slotStart != nil && profil.dauer > 0 ? profil.dauer : nil }

    /// Schätzung und, nur über dem Fenster, ein Vorschlag: erst das Supersatz-Paar, das allein reicht,
    /// sonst die letzten Übungen weglassen.
    static func urteil(_ tag: TrainingsTag, slotMinuten: Int?) -> ZeitUrteil {
        let fenster = (slotMinuten ?? 0) > 0 ? slotMinuten : nil
        let gesamt = sekunden(tag)
        let dauer = minuten(sekunden: gesamt)
        guard let fenster, dauer > fenster else { return ZeitUrteil(minuten: dauer, slot: fenster, tipp: nil) }
        return ZeitUrteil(minuten: dauer, slot: fenster, tipp: tipp(tag, gesamt: gesamt, slot: fenster))
    }

    private static func tipp(_ tag: TrainingsTag, gesamt: Int, slot: Int) -> ZeitTipp? {
        let paare = bloecke(tag.uebungen)
        var bestes: (a: PlanUebung, b: PlanUebung, spart: Int)?
        for k in 0..<max(0, paare.count - 1) {
            guard paare[k].count == 1, paare[k + 1].count == 1, !paare[k][0].istCardio, !paare[k + 1][0].istCardio else { continue }
            let a = paare[k][0], b = paare[k + 1][0]
            let spart = sekunden([a]) + sekunden([b]) - sekunden([a, b])
            if spart > (bestes?.spart ?? 0) { bestes = (a, b, spart) }
        }
        if let bestes, minuten(sekunden: gesamt - bestes.spart) <= slot {
            return .supersatz(erste: bestes.a.anzeigeName, zweite: bestes.b.anzeigeName,
                              spart: minuten(sekunden: gesamt) - minuten(sekunden: gesamt - bestes.spart))
        }
        var rest = gesamt
        var namen: [String] = []
        for block in paare.reversed() where minuten(sekunden: rest) > slot {
            rest -= sekunden(block)
            namen.insert(contentsOf: block.map(\.anzeigeName), at: 0)
        }
        return namen.isEmpty ? nil : .streichen(namen: namen, spart: minuten(sekunden: gesamt) - minuten(sekunden: rest))
    }
}
