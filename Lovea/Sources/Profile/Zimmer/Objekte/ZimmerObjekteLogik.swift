import Foundation

/// Zimmer-Objekte (Briefkasten, Anrufbeantworter, Herzglas, Sparschwein, Abreißkalender, Bilderrahmen):
/// die reine Rechnung dahinter. Keine Uhr, kein Modell; alles bekommt seine Werte hereingereicht.
enum ZimmerObjekteLogik {
    // MARK: Briefkasten

    /// Wie viele Umschläge man sieht und ob es mehr gibt, als in den Stapel passen.
    struct Stapel: Equatable {
        let sichtbar: Int
        let ueberlauf: Int
    }

    static let stapelHoechstens = 4

    /// Ungeöffnete Briefe als Stapel: bis `stapelHoechstens` Umschläge, der Rest läuft über.
    static func briefStapel(ungeoeffnet: Int) -> Stapel {
        let n = max(ungeoeffnet, 0)
        return Stapel(sichtbar: min(n, stapelHoechstens), ueberlauf: max(n - stapelHoechstens, 0))
    }

    /// Fahne oben, sobald Post wartet.
    static func fahneOben(ungeoeffnet: Int) -> Bool { ungeoeffnet > 0 }

    // MARK: Anrufbeantworter

    /// Die Anzeige: zwei Ziffern, ab 99 bleibt sie bei 99.
    static func ziffern(ungehoert: Int) -> String { String(format: "%02d", min(max(ungehoert, 0), 99)) }

    // MARK: Herzglas

    static let glasHoechstens = 7

    /// Wie viele Herzen im Glas liegen: die heute erhaltenen, bis das Glas voll ist.
    static func glasHerzen(erhalten: Int) -> Int { min(max(erhalten, 0), glasHoechstens) }

    /// Die Herzen, die `ich` heute vom Partner bekommen hat (`herzHeute` zählt je Absender).
    static func herzenErhalten(heute: [Person: Int], ich: Person?) -> Int {
        guard let ich else { return 0 }
        return heute[ich.partner] ?? 0
    }

    // MARK: Sparschwein

    static let schweinStufen = 5

    /// Füllstufe 0...5 nach den verfügbaren Punkten: 0, ab 1, 25, 100, 250, 500.
    static func schweinStufe(punkte: Int) -> Int {
        switch punkte {
        case ..<1: 0
        case 1..<25: 1
        case 25..<100: 2
        case 100..<250: 3
        case 250..<500: 4
        default: 5
        }
    }

    /// Füllstand 0...1 (für Tests und Beschriftung).
    static func schweinFuellung(punkte: Int) -> Double { Double(schweinStufe(punkte: punkte)) / Double(schweinStufen) }

    // MARK: Abreißkalender

    /// Tage bis zum nächsten Meilenstein. Am Meilenstein-Tag selbst springt der Zähler schon aufs nächste Ziel.
    static func tageBis(heute: String, start: String = Meilenstein.start) -> Int {
        Meilenstein.naechster(heute: heute, start: start).tage
    }

    /// Der Meilenstein, der heute erreicht ist (nil an allen anderen Tagen): der gestrige Zähler stand auf einem Tag.
    static func meilensteinHeute(heute: String, start: String = Meilenstein.start) -> String? {
        guard heute > start else { return nil }
        let gestern = Datum.text(Datum.kalender.date(byAdding: .day, value: -1, to: Datum.datum(heute))!)
        let stand = Meilenstein.naechster(heute: gestern, start: start)
        return stand.tage == 1 ? stand.titel : nil
    }

    static func istMeilensteinTag(heute: String, start: String = Meilenstein.start) -> Bool {
        meilensteinHeute(heute: heute, start: start) != nil
    }

    // MARK: Bilderrahmen

    static let rahmenHoechstens = 8

    /// Die Bilder im Rahmen: erst die Erinnerungen des Albums (neueste zuerst), dann die jüngsten Chat-Fotos.
    static func rahmenFotos(nachrichten: [ChatModell.Nachricht], ich: Person?) -> [AlbumFoto] {
        var gesehen = Set<String>()
        var liste: [AlbumFoto] = []
        func nimm(_ f: AlbumFoto) {
            guard liste.count < rahmenHoechstens, gesehen.insert(f.id).inserted else { return }
            liste.append(f)
        }
        for monat in ZimmerAlbumLogik.monate(aus: nachrichten, ich: ich).reversed() { monat.fotos.forEach(nimm) }
        for n in nachrichten.sorted(by: { $0.zeit > $1.zeit }) where !n.geloescht && n.system == nil && n.snap == nil {
            if let m = n.medien.first(where: { $0.typ == "foto" }) { nimm(AlbumFoto(medium: m, eigene: n.von == ich)) }
        }
        return liste
    }
}
