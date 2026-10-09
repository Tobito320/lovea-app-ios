import Foundation

/// Die Stimmungspflanze: ein Topf je Person. Wer seine Stimmung wählt, gießt sie. Jeder Tag in Folge lässt
/// sie weiter blühen; fällt ein Tag aus, hängt sie die Blätter, stirbt aber nie. Reine Logik auf Tagestexten
/// ("yyyy-MM-dd", Berlin) ohne Uhr und ohne Speicher, damit die Tests fest bleiben.
enum StimmungsPflanzeLogik {
    /// Was der Topf zeigt: Stufe 0 (Setzling) bis `hoechststufe` (volle Blüte).
    struct Stand: Equatable {
        var stufe: Int
        var serie: Int
        var haengt: Bool
        var heuteGegossen: Bool
    }

    static let hoechststufe = 4
    /// Mehr Tage merkt sich der Speicher nicht; die Stufe 4 ist lange vorher erreicht.
    static let behalteTage = 30

    /// Ab dieser Serie (Tage in Folge) gilt die Stufe 1 bis 4.
    static let schwellen = [1, 3, 7, 14]

    static func vortag(_ tag: String) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: -1, to: Datum.datum(tag))!)
    }

    /// Tage in Folge, die auf `heute` oder gestern enden. Heute noch ungegossen bricht die Serie nicht:
    /// der Morgen soll die Pflanze nicht schon hängen lassen, bevor man sie gießen konnte.
    static func serie(tage: Set<String>, heute: String) -> Int {
        var tag = tage.contains(heute) ? heute : vortag(heute)
        var anzahl = 0
        while tage.contains(tag) {
            anzahl += 1
            tag = vortag(tag)
        }
        return anzahl
    }

    static func stufe(serie: Int) -> Int {
        schwellen.filter { serie >= $0 }.count
    }

    /// Hängt, wenn sie schon einmal gegossen wurde, aber weder heute noch gestern.
    static func stand(tage: Set<String>, heute: String) -> Stand {
        let serie = serie(tage: tage, heute: heute)
        let gegossen = tage.contains(heute)
        let haengt = !tage.isEmpty && !gegossen && !tage.contains(vortag(heute))
        return Stand(stufe: stufe(serie: serie), serie: serie, haengt: haengt, heuteGegossen: gegossen)
    }

    /// Die Tage nach dem Gießen: `heute` dazu, nur die letzten `behalteTage`, sortiert.
    static func gegossen(_ tage: [String], heute: String) -> [String] {
        Array(Set(tage + [heute]).sorted().suffix(behalteTage))
    }

    /// Die gemeinsame Aufgabe "beide gießen heute".
    static func beideHeute(ich: Set<String>, partner: Set<String>, heute: String) -> Bool {
        ich.contains(heute) && partner.contains(heute)
    }
}
