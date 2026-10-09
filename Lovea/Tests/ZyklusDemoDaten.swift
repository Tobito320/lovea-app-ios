import Foundation
@testable import Lovea

/// Feste Beispieldaten nur für Tests: etwa 8 Monate, 8 Zyklen, deterministisch (kein Zufall).
/// Der laufende Zyklus ist bei `heute` am 10. Tag. Gehört nicht zur App.
enum ZyklusDemoDaten {
    static let einstellung = ZyklusEinstellung(zyklusLaenge: 28, periodenLaenge: 5, modus: .zyklus)

    /// Zykluslängen, älteste zuerst; danach folgt der laufende Zyklus.
    static let zyklusLaengen = [28, 29, 27, 30, 28, 26, 29, 28]

    private static let blutungsMuster: [Blutung] = [.leicht, .mittel, .stark, .mittel, .leicht]

    static func tage(heute: String) -> [String: ZyklusTag] {
        let kal = Datum.kalender
        let heuteDatum = Datum.datum(heute)
        func tag(_ offset: Int) -> String {
            Datum.text(kal.date(byAdding: .day, value: offset, to: heuteDatum)!)
        }
        let letzterStart = -9
        var starts = [letzterStart]
        for l in zyklusLaengen.reversed() { starts.insert(starts[0] - l, at: 0) }

        var ergebnis: [String: ZyklusTag] = [:]
        for (z, start) in starts.enumerated() {
            let laenge = z < zyklusLaengen.count ? zyklusLaengen[z] : 28
            let periode = z % 3 == 1 ? 4 : 5
            let eisprung = laenge - ZyklusLogik.lutealTage
            for n in 0..<laenge {
                let offset = start + n
                if offset > 0 { break }
                let id = tag(offset)
                var t = ZyklusTag(id: id)
                if n < periode {
                    t.blutung = blutungsMuster[n]
                    if n < 2 { t.symptome.insert(.kraempfe) }
                    if n == 0 { t.symptome.insert(.rueckenschmerzen) }
                    t.stimmung = n < 2 ? [.empfindlich] : [.ruhig]
                } else if n >= eisprung - 5 && n <= eisprung + 1 {
                    t.stimmung = [.energiegeladen]
                    t.ausfluss = n >= eisprung - 1 ? .eiweissartig : .cremig
                    if n == eisprung - 1 { t.eisprungTest = .positiv }
                    else if n == eisprung - 2 { t.eisprungTest = .negativ }
                } else if n > eisprung + 1 && n >= laenge - 5 {
                    t.symptome = [.brustspannen, .heisshunger]
                    if n >= laenge - 3 { t.symptome.insert(.blaehbauch); t.stimmung = [.gereizt] }
                    t.ausfluss = .klebrig
                }
                if n >= periode {
                    let schwanke = Double((n * 7 + z * 3) % 5) * 0.02
                    t.temperatur = (n > eisprung ? 36.7 : 36.4) + schwanke
                }
                if n % 4 == 0 { t.wasserMl = 1800 + (n * 50) % 700 }
                if n % 3 == 0 { t.schlafMin = 400 + (n * 11 + z) % 80 }
                ergebnis[id] = t
            }
        }
        if var t = ergebnis[tag(-4)] { t.notiz = "Heute früh Sport, danach gut drauf."; ergebnis[t.id] = t }
        return ergebnis
    }
}
