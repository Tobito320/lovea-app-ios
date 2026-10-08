import Foundation

/// Schalter für die Verknüpfung. Beide Standard AUS.
enum ZyklusSchalter {
    static let imTraining = "lovea.zyklusImTraining"
    static let healthKit = "lovea.zyklusHealthKit"
    /// p64: Wärmflasche und Tee im Zimmer an schweren Tagen. Nur Annika schaltet ein, Standard AUS.
    static let waerme = "lovea.waerme.freigabe"
}

enum TrainingsRat: String, Equatable {
    case kraft, normal, sanft
}

/// Was die Phase für Gym, Energie, Schlaf, Wasser, Essen und Schritte heißt. Nur Anregung, kein Befund.
struct ZyklusHinweis: Equatable {
    let phase: Phase
    let rat: TrainingsRat
    let training: String
    let energie: String
    let schlaf: String
    let wasserZielMl: Int
    let wasser: String
    let ernaehrung: String
    let schrittZiel: Int
    let schritte: String
}

enum ZyklusVerknuepfung {
    /// So nah vor der Periode zählt der späte Luteal-Teil.
    static let spaetLutealTage = 5

    static func hinweis(phase: Phase, tageBisPeriode: Int? = nil) -> ZyklusHinweis {
        switch phase {
        case .periode:
            return ZyklusHinweis(
                phase: phase, rat: .sanft,
                training: "Heute sanft. Yoga, Gehen oder leichtes Training. Hör auf deinen Körper.",
                energie: "Die Energie ist oft leise. Das ist normal.",
                schlaf: "Gönn dir etwas mehr Schlaf, wenn du magst.",
                wasserZielMl: 2300, wasser: "Trink heute etwas mehr, rund 2,3 Liter.",
                ernaehrung: "Eisen hilft jetzt: Linsen, Spinat, Haferflocken. Dazu etwas Wärmendes.",
                schrittZiel: 6000, schritte: "Ein Spaziergang tut gut. 6000 Schritte reichen.")
        case .follikel:
            return ZyklusHinweis(
                phase: phase, rat: .kraft,
                training: "Gute Zeit für Kraft. Du darfst schwerer gehen.",
                energie: "Die Energie steigt von Tag zu Tag.",
                schlaf: "Der Schlaf ist meist ruhig. Bleib bei deiner Zeit.",
                wasserZielMl: 2000, wasser: "Rund 2 Liter Wasser sind ein gutes Ziel.",
                ernaehrung: "Eiweiß und frisches Gemüse geben dir jetzt Kraft.",
                schrittZiel: 9000, schritte: "Heute geht mehr. Ziel 9000 Schritte.")
        case .fruchtbar:
            return ZyklusHinweis(
                phase: phase, rat: .kraft,
                training: "Du bist stark. Kraft und Tempo gehen gut.",
                energie: "Viel Schwung, oft auch gute Laune.",
                schlaf: "Der Schlaf kann etwas leichter sein.",
                wasserZielMl: 2200, wasser: "Trink rund 2,2 Liter, besonders beim Training.",
                ernaehrung: "Bunt essen: Beeren, Nüsse, Vollkorn.",
                schrittZiel: 10000, schritte: "Ziel 10000 Schritte, wenn du Lust hast.")
        case .eisprung:
            return ZyklusHinweis(
                phase: phase, rat: .kraft,
                training: "Heute ist dein Kraft-Tag. Achte beim Aufwärmen auf die Gelenke.",
                energie: "Meist dein Hoch. Nutz es.",
                schlaf: "Die Temperatur steigt bald. Der Schlaf kann unruhiger sein.",
                wasserZielMl: 2200, wasser: "Rund 2,2 Liter, vor allem rund ums Training.",
                ernaehrung: "Leicht und frisch. Viel Gemüse, gute Fette.",
                schrittZiel: 10000, schritte: "Ziel 10000 Schritte.")
        case .luteal:
            let spaet = (tageBisPeriode ?? Int.max) <= spaetLutealTage
            return ZyklusHinweis(
                phase: phase, rat: spaet ? .sanft : .normal,
                training: spaet
                    ? "Jetzt sanfter. Weniger Gewicht, mehr Pausen, dehnen tut gut."
                    : "Training wie immer. Du darfst bald etwas runterschalten.",
                energie: spaet ? "Die Energie sinkt. Plan Ruhe ein." : "Die Energie wird langsam ruhiger.",
                schlaf: "Der Schlaf ist oft flacher. Früh ins Bett hilft.",
                wasserZielMl: 2300, wasser: "Trink rund 2,3 Liter. Das hilft gegen Blähbauch.",
                ernaehrung: "Heißhunger ist normal. Magnesium hilft: Nüsse, Banane, dunkle Schokolade.",
                schrittZiel: 7000, schritte: "7000 Schritte sind genug.")
        }
    }

    /// Hinweis für einen Tag. Nil im Modus ohne Zyklus oder wenn die Phase unbekannt ist.
    static func hinweis(logik: ZyklusLogik, am tag: String) -> ZyklusHinweis? {
        guard logik.einstellung.modus == .zyklus, let phase = logik.phase(am: tag) else { return nil }
        return hinweis(phase: phase, tageBisPeriode: tageBisPeriode(logik: logik, am: tag))
    }

    static func tageBisPeriode(logik: ZyklusLogik, am tag: String) -> Int? {
        guard let n = logik.naechstePeriode else { return nil }
        return Datum.kalender.dateComponents([.day], from: Datum.datum(tag), to: Datum.datum(n)).day
    }

    /// Gate für die Karten: nur Annika, nur echte Daten, nur mit Schalter.
    static func zeigen(person: Person, schalter: Bool, quelle: ZyklusQuelle) -> Bool {
        person == .annika && schalter && quelle == .echt
    }
}
