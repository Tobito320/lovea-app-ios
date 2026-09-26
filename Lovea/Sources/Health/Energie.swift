import Foundation

/// `schlaf.zeiten {datum, bett, auf}`: when someone really went to bed and got up, typed in by hand.
/// `datum` is the wake-up day, the same key as `HealthModell.schlafNacht`. Newest op per person and day wins.
struct SchlafZeitenD: Codable, Sendable, Equatable { var datum: String; var bett: Date; var auf: Date }

struct EnergieEingabe: Sendable, Equatable {
    /// Sleep minutes per night, index 0 = last night, 1 = the night before, 2 = … nil = no data.
    var naechte: [Int?]
    var wasser: Int
    var wasserZiel: Int
    /// Hour of day in Berlin (0…23).
    var stunde: Int
    var schritteGestern: Int?
    /// The plan has a training day today / marks today as rest day / has no days at all.
    var trainingstag: Bool
    var ruhetag: Bool
    var planLeer: Bool
    /// Days in a row with gym before today (yesterday, the day before, …).
    var gymInFolge: Int
    var heuteSchonGym: Bool
}

struct EnergieRat: Sendable, Equatable {
    enum Stufe: String, Sendable { case hoch, mittel, niedrig }
    var stufe: Stufe
    var punkte: Int
    /// "Gym ja", "Gym ja, etwas leichter", "Heute besser kein Gym", "Ruhetag laut Plan", "Gym heute erledigt".
    var gym: String
    /// 0 = no cardio, else 15 or 30.
    var cardio: Int
    var gruende: [String]

    var titel: String {
        switch stufe {
        case .hoch: "Viel Energie heute"
        case .mittel: "Normale Energie"
        case .niedrig: "Heute eher wenig Energie"
        }
    }

    var cardioText: String { cardio == 0 ? "Kein Cardio" : "Cardio \(cardio) min" }
}

enum EnergieLogik {
    /// Points 0…100: last night up to 50 (5 h = 0, 8 h = 50), the 3-night average up to 30
    /// (5.5 h = 0, 7.5 h = 30), water on schedule 10, recovery 10. hoch ≥ 70, mittel ≥ 50.
    static func rat(_ e: EnergieEingabe) -> EnergieRat {
        let bekannt = e.naechte.prefix(3).compactMap { $0 }
        let letzte = e.naechte.first.flatMap { $0 } ?? 420
        let schnitt = bekannt.isEmpty ? 420 : bekannt.reduce(0, +) / bekannt.count
        let schlafPunkte = Double(max(0, min(letzte, 480) - 300)) * 50 / 180
        let schnittPunkte = Double(max(0, min(schnitt, 450) - 330)) * 30 / 120
        let soll = wasserSoll(ziel: e.wasserZiel, stunde: e.stunde)
        let wasserPunkte = soll == 0 ? 10 : Double(min(e.wasser, soll)) * 10 / Double(soll)
        let erholung: Double = e.gymInFolge >= 3 ? 0 : (e.gymInFolge == 0 ? 10 : 5)
        let punkte = Int((schlafPunkte + schnittPunkte + wasserPunkte + erholung).rounded())
        let stufe: EnergieRat.Stufe = punkte >= 70 ? .hoch : (punkte >= 50 ? .mittel : .niedrig)

        var gruende: [String] = []
        if bekannt.isEmpty {
            gruende.append("Keine Schlafdaten. Trag ein, wann du im Bett warst.")
        } else if letzte < 360 {
            gruende.append("Letzte Nacht nur \(dauer(letzte)) geschlafen.")
        } else if letzte >= 450 {
            gruende.append("Gut geschlafen (\(dauer(letzte))).")
        }
        if bekannt.count >= 2 && schnitt < 390 {
            gruende.append("Die letzten Nächte waren kürzer (Ø \(dauer(schnitt))).")
        }
        if soll - e.wasser >= 2 {
            gruende.append("Beim Wasser hinten: \(e.wasser) von \(soll) bis jetzt.")
        }
        if e.gymInFolge >= 3 {
            gruende.append("Schon \(e.gymInFolge) Tage am Stück trainiert.")
        }

        let gym: String
        if e.heuteSchonGym {
            gym = "Gym heute erledigt"
        } else if e.ruhetag {
            gym = "Ruhetag laut Plan"
        } else if !e.trainingstag && !e.planLeer {
            gym = "Kein Gym geplant"
        } else if stufe == .niedrig {
            gym = "Heute besser kein Gym"
        } else if stufe == .mittel || e.gymInFolge >= 3 {
            gym = "Gym ja, etwas leichter"
        } else {
            gym = "Gym ja"
        }
        let cardio: Int
        switch stufe {
        case .niedrig: cardio = 0
        case .mittel: cardio = 15
        case .hoch: cardio = (e.schritteGestern ?? 10_000) < 8_000 ? 30 : 15
        }
        return EnergieRat(stufe: stufe, punkte: punkte, gym: gym, cardio: cardio, gruende: gruende)
    }

    /// Glasses expected by this hour: none before 8, the full goal at 22, linear between.
    static func wasserSoll(ziel: Int, stunde: Int) -> Int {
        let anteil = min(max(Double(stunde - 8) / 14, 0), 1)
        return Int((Double(ziel) * anteil).rounded(.down))
    }

    /// Time of each glass from the day's `habit.setzen` values (value, send time). Every rise in the
    /// count adds that many glasses at that time; lowering it drops the latest ones.
    static func wasserZeiten(_ werte: [(zeit: Date, wert: Int)]) -> [Date] {
        var zeiten: [Date] = []
        for w in werte.sorted(by: { $0.zeit < $1.zeit }) {
            if w.wert > zeiten.count {
                zeiten += Array(repeating: w.zeit, count: w.wert - zeiten.count)
            } else {
                zeiten = Array(zeiten.prefix(max(0, w.wert)))
            }
        }
        return zeiten
    }

    /// Minutes in bed from hand-entered times. Only the time of day counts: the picker keeps whatever
    /// date the value started with, so 00:30 can carry yesterday's date. A later bed time was the evening before.
    static func imBett(_ z: SchlafZeitenD) -> Int {
        (minutenAmTag(z.auf) - minutenAmTag(z.bett) + 1440) % 1440
    }

    private static func minutenAmTag(_ d: Date) -> Int {
        let t = Datum.kalender.dateComponents([.hour, .minute], from: d)
        return (t.hour ?? 0) * 60 + (t.minute ?? 0)
    }

    /// Consecutive days before `heute` on which `trainiert` is true.
    static func inFolge(heute: String, trainiert: (String) -> Bool) -> Int {
        var n = 0
        while n < 14, trainiert(Datum.addTage(heute, -(n + 1))) { n += 1 }
        return n
    }

    static func dauer(_ minuten: Int) -> String { "\(minuten / 60) h \(String(format: "%02d", minuten % 60)) min" }
}
