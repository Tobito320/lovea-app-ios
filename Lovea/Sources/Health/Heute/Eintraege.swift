import Foundation

/// "Schreib, was war": Vorschläge der KI (Server `POST eintraege/lesen`) als feste Einträge. Die Logik hier ist rein
/// (lesen, beschreiben, auf Glas/Stimmung abbilden). Gespeichert wird über die bestehenden Op-Arten in `EintraegeSpeicher`.
enum KIEintrag: Equatable, Sendable {
    case essen(datum: String, name: String, menge: Double, fluessig: Bool, mahlzeit: Mahlzeit, naehrwerte: Naehrwerte)
    case wasser(datum: String, ml: Int)
    case training(datum: String, name: String, minuten: Int)
    case schlaf(datum: String, bett: Date, auf: Date)
    case stimmung(datum: String, stufe: Int)
}

enum EintraegeLogik {
    private struct Antwort: Decodable { let eintraege: [Roh] }
    private struct Roh: Decodable {
        let typ: String
        let datum: String?
        let name: String?
        let mahlzeit: String?
        let menge: Double?
        let einheit: String?
        let kcal: Double?
        let protein: Double?
        let kohlenhydrate: Double?
        let fett: Double?
        let ml: Double?
        let minuten: Double?
        let bett: String?
        let auf: String?
        let stimmung: Int?
    }

    /// Antwort des Servers lesen. Alles Unvollständige fällt still weg. `tag` = Standard, wenn ein Datum fehlt.
    static func lesen(_ daten: Data, tag: String) -> [KIEintrag]? {
        guard let a = try? JSONDecoder().decode(Antwort.self, from: daten) else { return nil }
        return a.eintraege.compactMap { eintrag($0, tag: tag) }
    }

    private static func eintrag(_ r: Roh, tag: String) -> KIEintrag? {
        let datum = r.datum ?? tag
        switch r.typ {
        case "essen":
            guard let name = r.name, let menge = r.menge, menge > 0, let kcal = r.kcal else { return nil }
            let n = Naehrwerte(kcal: kcal, protein: r.protein ?? 0, kohlenhydrate: r.kohlenhydrate ?? 0, fett: r.fett ?? 0)
            return .essen(datum: datum, name: name, menge: menge, fluessig: r.einheit == "ml",
                          mahlzeit: r.mahlzeit.flatMap(Mahlzeit.init(rawValue:)) ?? .snack, naehrwerte: n)
        case "wasser":
            guard let ml = r.ml, ml > 0 else { return nil }
            return .wasser(datum: datum, ml: Int(ml.rounded()))
        case "training":
            guard let name = r.name, let min = r.minuten, min > 0 else { return nil }
            return .training(datum: datum, name: name, minuten: Int(min.rounded()))
        case "schlaf":
            guard let b = r.bett.flatMap({ FreitextLogik.uhrzeiten(" \($0) ").first }),
                  let a = r.auf.flatMap({ FreitextLogik.uhrzeiten(" \($0) ").first }),
                  case .schlaf(let bett, let auf)? = FreitextLogik.schlafDaten(bett: b, auf: a, tag: datum) else { return nil }
            return .schlaf(datum: datum, bett: bett, auf: auf)
        case "stimmung":
            guard let s = r.stimmung, (1...5).contains(s) else { return nil }
            return .stimmung(datum: datum, stufe: s)
        default:
            return nil
        }
    }

    /// Wasser zählt in Gläsern (250 ml), mindestens ein Glas.
    static func glaeser(ml: Int) -> Int { max(1, Int((Double(ml) / FreitextLogik.glasMl).rounded())) }

    /// 1 und 2 schlecht, 3 mittel, 4 und 5 gut: die drei Stufen der Stimmungs-Kachel.
    static func stimmungText(_ stufe: Int) -> String { stufe <= 2 ? "schlecht" : (stufe == 3 ? "mittel" : "gut") }

    /// Werte pro 100 g/ml aus den Summen für `menge`.
    static func lebensmittel(name: String, menge: Double, fluessig: Bool, summe n: Naehrwerte) -> Lebensmittel {
        let f = 100 / menge
        let pro100 = Naehrwerte(kcal: n.kcal * f, protein: n.protein * f, kohlenhydrate: n.kohlenhydrate * f, fett: n.fett * f)
        return Lebensmittel(id: "schnell-\(UUID().uuidString)", name: name, fluessig: fluessig, pro100: pro100)
    }

    static func beschreibung(_ e: KIEintrag) -> String {
        switch e {
        case .essen(_, let name, let menge, let fl, _, let n):
            return "\(name), \(Int(menge.rounded())) \(fl ? "ml" : "g"), \(Int(n.kcal.rounded())) kcal, \(Int(n.protein.rounded())) g Eiweiß"
        case .wasser(_, let ml): return "Wasser +\(ml) ml"
        case .training(_, let name, let min): return "Training \(name), \(min) min"
        case .schlaf(_, let bett, let auf):
            let f = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Datum.kalender.timeZone)
            let min = Int(auf.timeIntervalSince(bett) / 60)
            return "Schlaf \(bett.formatted(f)) bis \(auf.formatted(f)), \(min / 60) h \(min % 60) min"
        case .stimmung(_, let s): return "Stimmung \(stimmungText(s)) (\(s) von 5)"
        }
    }

    static func symbol(_ e: KIEintrag) -> String {
        switch e {
        case .essen: "fork.knife"
        case .wasser: "drop.fill"
        case .training: "dumbbell.fill"
        case .schlaf: "bed.double.fill"
        case .stimmung: "face.smiling"
        }
    }

    /// Bitte im Chat, die etwas eintragen soll ("trag das ein", "ich habe gerade eine Pizza gegessen").
    /// Grob und billig: erst dann geht der Text an den Server. Fragen ("wie viel Eiweiß hat Quark?") zählen nicht.
    static func klingtNachEintragen(_ text: String) -> Bool {
        let t = text.lowercased().replacingOccurrences(of: "ß", with: "ss")
        if t.hasSuffix("?") { return false }
        let befehle = ["trag das ein", "trag es ein", "trag mir", "trage das ein", "trage ein", "trag ein", "speicher das", "speichere das", "log das", "schreib das auf"]
        if befehle.contains(where: t.contains) { return true }
        let vergangenheit = ["ich habe ", "ich hab ", "hab ", "habe ", "war ", "bin ", "gegessen", "getrunken", "geschlafen", "trainiert"]
        let inhalt = ["gegessen", "getrunken", "geschlafen", "trainiert", "gegessen,", "gym", "joggen", "gelaufen", "liter", "glas ", "gläser", "kcal"]
        return vergangenheit.contains(where: t.contains) && inhalt.contains(where: t.contains)
    }
}

/// Server-Aufruf. `nil` = nichts Brauchbares (kein Schlüssel 503, Limit, Netz, kaputte Antwort): dann gelten die festen Muster.
enum EintraegeServer {
    @MainActor
    static func lesen(_ text: String, tag: String) async -> [KIEintrag]? {
        guard let konfig = Raum.shared.httpKonfiguration(), let body = try? JSONEncoder().encode(["text": text]) else { return nil }
        var anfrage = URLRequest(url: konfig.basis.appendingPathComponent("eintraege/lesen"))
        anfrage.httpMethod = "POST"
        anfrage.timeoutInterval = 25
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { anfrage.setValue(wert, forHTTPHeaderField: feld) }
        anfrage.httpBody = body
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              (antwort as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return EintraegeLogik.lesen(daten, tag: tag)
    }
}

private struct StimmungOpKI: Codable { var datum: String; var stimmung: String; var brauche: String?; var satz: String? }

/// Speichert über die bestehenden Wege und merkt sich, wie man jeden Eintrag zurücknimmt.
@MainActor
struct EintraegeSpeicher {
    private(set) var zurueck: [@MainActor () -> Void] = []

    mutating func speichern(_ liste: [KIEintrag]) {
        let health = HealthModell.shared
        let essen = ErnaehrungModell.shared
        let ich = Raum.shared.ich ?? .ahmed
        for e in liste {
            switch e {
            case .essen(let datum, let name, let menge, let fl, let mahlzeit, let n):
                let l = EintraegeLogik.lebensmittel(name: name, menge: menge, fluessig: fl, summe: n)
                let id = UUID().uuidString
                let einheit: Einheit = fl ? .ml : .g
                essen.eintragen(l, menge: menge, einheit: einheit, mahlzeit: mahlzeit, datum: datum, id: id)
                let eintrag = EssenEintrag(id: id, datum: datum, mahlzeit: mahlzeit, menge: menge, einheit: einheit, lebensmittel: l, geloescht: nil)
                zurueck.append { essen.loeschen(eintrag) }
            case .wasser(let datum, let ml):
                let vorher = health.wasserAnzahl(ich, datum)
                health.setzeWasser(datum: datum, anzahl: vorher + EintraegeLogik.glaeser(ml: ml))
                zurueck.append { health.setzeWasser(datum: datum, anzahl: vorher) }
            case .training(let datum, _, _):
                let vorher = health.habitWert(Habit.gym.id, ich, datum)
                health.setzeGym(datum: datum, an: true)
                zurueck.append { health.setzeGym(datum: datum, an: vorher > 0) }
            case .schlaf(let datum, let bett, let auf):
                let vorher = health.schlafZeitenAm(ich, datum)
                health.schlafEintragen(SchlafZeitenD(datum: datum, bett: bett, auf: auf))
                // Ohne früheren Eintrag: bett = auf heißt 0 min, also gelöscht (siehe HealthModell.schlafMinuten).
                zurueck.append { health.schlafEintragen(vorher ?? SchlafZeitenD(datum: datum, bett: auf, auf: auf)) }
            case .stimmung(let datum, let stufe):
                let vorher = health.stimmung(ich, datum)
                Raum.shared.senden("stimmung.setzen", StimmungOpKI(datum: datum, stimmung: EintraegeLogik.stimmungText(stufe), brauche: nil, satz: nil))
                if let vorher {
                    zurueck.append { Raum.shared.senden("stimmung.setzen", StimmungOpKI(datum: datum, stimmung: vorher, brauche: nil, satz: nil)) }
                }
            }
        }
    }

    func rueckgaengig() { for z in zurueck.reversed() { z() } }
}
