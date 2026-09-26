import Foundation

// Ernährung wie YAZIO (Ahmed, 26.09.): Tagebuch mit Mahlzeiten, Barcode über Open Food Facts,
// Menge in g, ml, Portion oder Packung, Ziele, eigene Lebensmittel, Rezepte, Favoriten, Fasten.
// Hier nur Typen, Faltung und reine Logik, ohne Views und ohne Singletons.

// MARK: - Typen

/// Nährwerte pro 100 g/ml (`Lebensmittel.pro100`) oder für eine Menge (Summen).
struct Naehrwerte: Codable, Equatable, Sendable {
    var kcal: Double = 0
    var protein: Double = 0
    var kohlenhydrate: Double = 0
    var fett: Double = 0
    var zucker: Double? = nil
    var ballaststoffe: Double? = nil
    var salz: Double? = nil
    var gesFett: Double? = nil

    static let null = Naehrwerte()

    func mal(_ f: Double) -> Naehrwerte {
        Naehrwerte(kcal: kcal * f, protein: protein * f, kohlenhydrate: kohlenhydrate * f, fett: fett * f,
                   zucker: zucker.map { $0 * f }, ballaststoffe: ballaststoffe.map { $0 * f },
                   salz: salz.map { $0 * f }, gesFett: gesFett.map { $0 * f })
    }

    static func + (a: Naehrwerte, b: Naehrwerte) -> Naehrwerte {
        Naehrwerte(kcal: a.kcal + b.kcal, protein: a.protein + b.protein,
                   kohlenhydrate: a.kohlenhydrate + b.kohlenhydrate, fett: a.fett + b.fett,
                   zucker: plus(a.zucker, b.zucker), ballaststoffe: plus(a.ballaststoffe, b.ballaststoffe),
                   salz: plus(a.salz, b.salz), gesFett: plus(a.gesFett, b.gesFett))
    }

    private static func plus(_ a: Double?, _ b: Double?) -> Double? {
        if a == nil && b == nil { return nil }
        return (a ?? 0) + (b ?? 0)
    }
}

/// `g` und `ml` zählen 1:1 (Dichte wird ignoriert), `portion` und `packung` über die Mengen des Lebensmittels.
enum Einheit: String, Codable, Sendable, CaseIterable {
    case g, ml, portion, packung
}

/// Ein Lebensmittel mit Werten pro 100 g (oder 100 ml bei `fluessig`). Jeder Eintrag speichert eine
/// Kopie, dadurch gehen "Zuletzt" und das Tagebuch auch offline.
struct Lebensmittel: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// "off-<barcode>", "eigen-<uuid>", "rezept-<uuid>" oder "schnell-<uuid>".
    var id: String
    var name: String
    var marke: String?
    var barcode: String?
    var fluessig: Bool
    var pro100: Naehrwerte
    /// g oder ml einer Portion, etwa 30 g Müsli.
    var portionMenge: Double?
    var portionName: String?
    var packungMenge: Double?
    /// "a" bis "e".
    var nutriscore: String?
    var bild: String?

    init(id: String, name: String, marke: String? = nil, barcode: String? = nil, fluessig: Bool = false,
         pro100: Naehrwerte, portionMenge: Double? = nil, portionName: String? = nil, packungMenge: Double? = nil,
         nutriscore: String? = nil, bild: String? = nil) {
        self.id = id
        self.name = name
        self.marke = marke
        self.barcode = barcode
        self.fluessig = fluessig
        self.pro100 = pro100
        self.portionMenge = portionMenge
        self.portionName = portionName
        self.packungMenge = packungMenge
        self.nutriscore = nutriscore
        self.bild = bild
    }

    static func == (a: Lebensmittel, b: Lebensmittel) -> Bool { a.id == b.id && a.name == b.name && a.pro100 == b.pro100 }
    func hash(into h: inout Hasher) { h.combine(id) }

    var basisEinheit: Einheit { fluessig ? .ml : .g }
    var istRezept: Bool { id.hasPrefix("rezept-") }
    var anzeigeName: String { marke.map { "\(name) · \($0)" } ?? name }
}

enum Mahlzeit: String, Codable, Sendable, CaseIterable, Identifiable {
    case fruehstueck, mittag, abend, snack

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fruehstueck: "Frühstück"
        case .mittag: "Mittagessen"
        case .abend: "Abendessen"
        case .snack: "Snacks"
        }
    }

    var symbol: String {
        switch self {
        case .fruehstueck: "sunrise.fill"
        case .mittag: "sun.max.fill"
        case .abend: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    /// Anteil am Tagesziel, wie YAZIO ihn als Richtwert je Mahlzeit zeigt.
    var anteil: Double {
        switch self {
        case .fruehstueck: 0.25
        case .mittag: 0.35
        case .abend: 0.30
        case .snack: 0.10
        }
    }

    /// Welche Mahlzeit jetzt dran ist, für den Standard beim Hinzufügen.
    static func zurZeit(stunde: Int) -> Mahlzeit {
        switch stunde {
        case 4..<11: .fruehstueck
        case 11..<15: .mittag
        case 17..<22: .abend
        default: .snack
        }
    }
}

/// Op `essen.setzen`: anlegen, ändern und löschen (`geloescht`) laufen über dieselbe Op, die neueste gewinnt.
struct EssenEintrag: Codable, Equatable, Sendable, Identifiable {
    var id: String
    /// Tag im Tagebuch, "yyyy-MM-dd".
    var datum: String
    var mahlzeit: Mahlzeit
    var menge: Double
    var einheit: Einheit
    var lebensmittel: Lebensmittel
    var geloescht: Bool?

    var naehrwerte: Naehrwerte { ErnaehrungLogik.naehrwerte(lebensmittel, menge: menge, einheit: einheit) }
}

/// Op `lebensmittel.setzen`: eigenes Lebensmittel, für beide sichtbar.
struct LebensmittelD: Codable, Sendable {
    var lebensmittel: Lebensmittel
    var geloescht: Bool?
}

/// Op `lebensmittel.favorit`: pro Person.
struct FavoritD: Codable, Sendable {
    var lebensmittel: Lebensmittel
    var an: Bool
}

struct Zutat: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var lebensmittel: Lebensmittel
    var menge: Double
    var einheit: Einheit
}

/// Op `rezept.setzen`: eigenes Rezept, für beide sichtbar. Wird als Lebensmittel mit Portionen eingetragen.
struct Rezept: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var portionen: Int
    var zutaten: [Zutat]
    var geloescht: Bool?
}

/// Op `fasten.setzen`: `start` gesetzt = Fasten läuft, nil = beendet (`ende` = wann).
struct FastenD: Codable, Equatable, Sendable {
    var start: Date?
    var ende: Date?
}

/// Ziele und Körperdaten, gespeichert als `einstellung.setzen` mit Schlüssel `ziel.ernaehrung.<feld>`.
struct ErnaehrungsZiele: Equatable, Sendable {
    var kcal: Int = 2000
    var protein: Int = 120
    var kohlenhydrate: Int = 220
    var fett: Int = 70
    /// 0 = Mann, 1 = Frau.
    var geschlecht: Int = 0
    var alter: Int = 25
    var groesseCm: Int = 175
    /// Index in `ErnaehrungLogik.aktivitaeten`.
    var aktivitaet: Int = 2
    /// 0 = abnehmen, 1 = halten, 2 = zunehmen.
    var richtung: Int = 1
    /// Gramm pro Woche beim Ab- oder Zunehmen.
    var tempo: Int = 500
    /// Index in `ErnaehrungLogik.makroProfile`.
    var makroProfil: Int = 0
    /// Fastenfenster in Stunden (16 = 16:8).
    var fastenStunden: Int = 16
    /// Wurden die Ziele schon einmal eingerichtet?
    var eingerichtet: Bool = false

    static let felder = ["kcal", "protein", "kohlenhydrate", "fett", "geschlecht", "alter", "groesseCm", "aktivitaet",
                         "richtung", "tempo", "makroProfil", "fastenStunden", "eingerichtet"]

    func wert(_ feld: String) -> Int {
        switch feld {
        case "kcal": kcal
        case "protein": protein
        case "kohlenhydrate": kohlenhydrate
        case "fett": fett
        case "geschlecht": geschlecht
        case "alter": alter
        case "groesseCm": groesseCm
        case "aktivitaet": aktivitaet
        case "richtung": richtung
        case "tempo": tempo
        case "makroProfil": makroProfil
        case "fastenStunden": fastenStunden
        default: eingerichtet ? 1 : 0
        }
    }

    mutating func setzen(_ feld: String, _ w: Int) {
        switch feld {
        case "kcal": kcal = w
        case "protein": protein = w
        case "kohlenhydrate": kohlenhydrate = w
        case "fett": fett = w
        case "geschlecht": geschlecht = w
        case "alter": alter = w
        case "groesseCm": groesseCm = w
        case "aktivitaet": aktivitaet = w
        case "richtung": richtung = w
        case "tempo": tempo = w
        case "makroProfil": makroProfil = w
        case "fastenStunden": fastenStunden = w
        default: eingerichtet = w > 0
        }
    }
}

// MARK: - Faltung

struct ErnaehrungFaltung: Sendable {
    static let arten: Set<String> = ["essen.setzen", "lebensmittel.setzen", "lebensmittel.favorit", "rezept.setzen", "fasten.setzen"]

    private struct Stand<T: Sendable>: Sendable {
        var zeit: Date
        var wert: T
    }

    private var essen: [Person: [String: Stand<EssenEintrag>]] = [:]
    private var eigene: [String: Stand<LebensmittelD>] = [:]
    private var favoriten: [Person: [String: Stand<FavoritD>]] = [:]
    private var rezepteStand: [String: Stand<Rezept>] = [:]
    private var fastenStand: [Person: Stand<FastenD>] = [:]

    mutating func anwenden(_ op: Op) {
        switch op.art {
        case "essen.setzen":
            guard let e = op.daten(EssenEintrag.self), (essen[op.von]?[e.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            essen[op.von, default: [:]][e.id] = Stand(zeit: op.zeit, wert: e)
        case "lebensmittel.setzen":
            guard let d = op.daten(LebensmittelD.self), (eigene[d.lebensmittel.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            eigene[d.lebensmittel.id] = Stand(zeit: op.zeit, wert: d)
        case "lebensmittel.favorit":
            guard let d = op.daten(FavoritD.self), (favoriten[op.von]?[d.lebensmittel.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            favoriten[op.von, default: [:]][d.lebensmittel.id] = Stand(zeit: op.zeit, wert: d)
        case "rezept.setzen":
            guard let r = op.daten(Rezept.self), (rezepteStand[r.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            rezepteStand[r.id] = Stand(zeit: op.zeit, wert: r)
        case "fasten.setzen":
            guard let d = op.daten(FastenD.self), (fastenStand[op.von]?.zeit ?? .distantPast) <= op.zeit else { return }
            fastenStand[op.von] = Stand(zeit: op.zeit, wert: d)
        default:
            break
        }
    }

    /// Einträge eines Tages in der Reihenfolge, in der sie zuletzt geändert wurden.
    func eintraege(_ p: Person, _ tag: String) -> [EssenEintrag] {
        (essen[p] ?? [:]).values
            .filter { $0.wert.datum == tag && $0.wert.geloescht != true }
            .sorted { $0.zeit < $1.zeit }
            .map(\.wert)
    }

    /// Alle Tage mit mindestens einem Eintrag.
    func tage(_ p: Person) -> Set<String> {
        Set((essen[p] ?? [:]).values.filter { $0.wert.geloescht != true }.map(\.wert.datum))
    }

    /// Zuletzt gegessene Lebensmittel, jedes einmal, neueste zuerst.
    func zuletzt(_ p: Person, anzahl: Int = 40) -> [Lebensmittel] {
        var gesehen: Set<String> = []
        var liste: [Lebensmittel] = []
        for s in (essen[p] ?? [:]).values.sorted(by: { $0.zeit > $1.zeit }) where s.wert.geloescht != true {
            let l = s.wert.lebensmittel
            guard !l.id.hasPrefix("schnell-"), gesehen.insert(l.id).inserted else { continue }
            liste.append(l)
            if liste.count == anzahl { break }
        }
        return liste
    }

    /// Letzte Menge und Einheit, mit der `p` dieses Lebensmittel eingetragen hat.
    func letzteMenge(_ p: Person, _ lebensmittelId: String) -> (menge: Double, einheit: Einheit)? {
        (essen[p] ?? [:]).values
            .filter { $0.wert.lebensmittel.id == lebensmittelId && $0.wert.geloescht != true }
            .max { $0.zeit < $1.zeit }
            .map { (menge: $0.wert.menge, einheit: $0.wert.einheit) }
    }

    var eigeneLebensmittel: [Lebensmittel] {
        eigene.values.filter { $0.wert.geloescht != true }.map(\.wert.lebensmittel)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func favoritenListe(_ p: Person) -> [Lebensmittel] {
        (favoriten[p] ?? [:]).values.filter(\.wert.an).map(\.wert.lebensmittel)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func istFavorit(_ p: Person, _ id: String) -> Bool { favoriten[p]?[id]?.wert.an == true }

    var rezepte: [Rezept] {
        rezepteStand.values.map(\.wert).filter { $0.geloescht != true }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func fasten(_ p: Person) -> FastenD? { fastenStand[p]?.wert }

    /// Offline-Treffer für einen Barcode: eigene Lebensmittel zuerst, dann alles schon Gegessene.
    func lebensmittel(barcode: String, _ p: Person) -> Lebensmittel? {
        if let eigenes = eigeneLebensmittel.first(where: { $0.barcode == barcode }) { return eigenes }
        for person in [p, p.partner] {
            if let s = (essen[person] ?? [:]).values.first(where: { $0.wert.lebensmittel.barcode == barcode }) {
                return s.wert.lebensmittel
            }
        }
        return nil
    }
}

// MARK: - Logik

enum ErnaehrungLogik {
    static let aktivitaeten: [(name: String, text: String, faktor: Double)] = [
        ("Kaum aktiv", "Bürojob, kaum Bewegung", 1.2),
        ("Leicht aktiv", "1 bis 3 mal Sport pro Woche", 1.375),
        ("Aktiv", "3 bis 5 mal Sport pro Woche", 1.55),
        ("Sehr aktiv", "6 bis 7 mal Sport pro Woche", 1.725),
        ("Extrem aktiv", "Körperlicher Job und täglich Sport", 1.9),
    ]

    /// Anteile Protein, Kohlenhydrate, Fett an den Kalorien. "Proteinreich" rechnet 2 g Protein pro kg.
    static let makroProfile: [(name: String, protein: Double, kohlenhydrate: Double, fett: Double)] = [
        ("Ausgewogen", 0.20, 0.50, 0.30),
        ("Proteinreich", 0.30, 0.40, 0.30),
        ("Low Carb", 0.30, 0.25, 0.45),
    ]

    /// Gramm oder Milliliter, die eine Menge in dieser Einheit bedeutet.
    static func gramm(_ l: Lebensmittel, menge: Double, einheit: Einheit) -> Double {
        switch einheit {
        case .g, .ml: menge
        case .portion: menge * (l.portionMenge ?? 100)
        case .packung: menge * (l.packungMenge ?? l.portionMenge ?? 100)
        }
    }

    static func naehrwerte(_ l: Lebensmittel, menge: Double, einheit: Einheit) -> Naehrwerte {
        l.pro100.mal(gramm(l, menge: menge, einheit: einheit) / 100)
    }

    static func summe(_ eintraege: [EssenEintrag]) -> Naehrwerte {
        eintraege.reduce(Naehrwerte.null) { $0 + $1.naehrwerte }
    }

    /// Einheiten, die für dieses Lebensmittel Sinn ergeben.
    static func einheiten(_ l: Lebensmittel) -> [Einheit] {
        var liste: [Einheit] = l.fluessig ? [.ml, .g] : [.g, .ml]
        if l.portionMenge != nil { liste.insert(.portion, at: 0) }
        if l.packungMenge != nil { liste.append(.packung) }
        return liste
    }

    /// Menge, mit der das Detailblatt startet: Portion, falls bekannt, sonst 100 g/ml.
    static func startMenge(_ l: Lebensmittel) -> (menge: Double, einheit: Einheit) {
        l.portionMenge != nil ? (1, .portion) : (100, l.basisEinheit)
    }

    static func einheitName(_ e: Einheit, _ l: Lebensmittel, menge: Double = 1) -> String {
        switch e {
        case .g: return "g"
        case .ml: return "ml"
        case .portion:
            if let name = l.portionName, !name.isEmpty { return name }
            return menge == 1 ? "Portion" : "Portionen"
        case .packung: return menge == 1 ? "Packung" : "Packungen"
        }
    }

    /// "1 Portion (30 g)", "250 ml", "0,5 Packungen (200 g)".
    static func mengeText(_ menge: Double, _ e: Einheit, _ l: Lebensmittel) -> String {
        let basis = "\(zahl(menge)) \(einheitName(e, l, menge: menge))"
        guard e == .portion || e == .packung else { return basis }
        return "\(basis) (\(zahl(gramm(l, menge: menge, einheit: e))) \(l.basisEinheit.rawValue))"
    }

    /// Deutsche Zahl mit höchstens einer Nachkommastelle, ohne ",0".
    static func zahl(_ x: Double) -> String {
        let gerundet = (x * 10).rounded() / 10
        if gerundet == gerundet.rounded() { return String(Int(gerundet)) }
        return String(format: "%.1f", gerundet).replacingOccurrences(of: ".", with: ",")
    }

    /// "12,5" oder "12.5" -> 12.5. Leer, Text, negativ -> nil.
    static func eingabe(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let x = Double(t), x.isFinite, x >= 0 else { return nil }
        return x
    }

    // MARK: Ziele

    /// Mifflin-St Jeor.
    static func grundumsatz(frau: Bool, kg: Double, cm: Double, alter: Int) -> Double {
        10 * kg + 6.25 * cm - 5 * Double(alter) + (frau ? -161 : 5)
    }

    /// Tagesziel auf 10 kcal gerundet. 7700 kcal pro kg Körperfett, also 1,1 kcal am Tag je Gramm pro Woche.
    /// Nie unter 1200 (Frau) oder 1500 (Mann).
    static func kalorienziel(_ z: ErnaehrungsZiele, kg: Double) -> Int {
        let faktor = aktivitaeten[min(max(z.aktivitaet, 0), aktivitaeten.count - 1)].faktor
        let bedarf = grundumsatz(frau: z.geschlecht == 1, kg: kg, cm: Double(z.groesseCm), alter: z.alter) * faktor
        let aenderung = Double(z.tempo) * 1.1 * Double(z.richtung - 1)
        let minimum: Double = z.geschlecht == 1 ? 1200 : 1500
        return Int((max(minimum, bedarf + aenderung) / 10).rounded()) * 10
    }

    /// Makros in Gramm aus Kalorien und Profil. Proteinreich: mindestens 2 g pro kg.
    static func makros(kcal: Int, kg: Double, profil: Int) -> (protein: Int, kohlenhydrate: Int, fett: Int) {
        let p = makroProfile[min(max(profil, 0), makroProfile.count - 1)]
        let k = Double(kcal)
        var protein = k * p.protein / 4
        if profil == 1 { protein = max(protein, 2 * kg) }
        let fett = k * p.fett / 9
        let kohlenhydrate = max(0, k - protein * 4 - fett * 9) / 4
        return (Int(protein.rounded()), Int(kohlenhydrate.rounded()), Int(fett.rounded()))
    }

    /// Ziele mit neu berechneten Kalorien und Makros.
    static func berechnet(_ z: ErnaehrungsZiele, kg: Double) -> ErnaehrungsZiele {
        var neu = z
        neu.kcal = kalorienziel(z, kg: kg)
        let m = makros(kcal: neu.kcal, kg: kg, profil: z.makroProfil)
        neu.protein = m.protein
        neu.kohlenhydrate = m.kohlenhydrate
        neu.fett = m.fett
        return neu
    }

    // MARK: Rezepte

    /// Das Rezept als Lebensmittel: Werte pro 100 g der ganzen Menge, eine Portion = Gesamtgewicht / Portionen.
    static func alsLebensmittel(_ r: Rezept) -> Lebensmittel {
        let gesamt = r.zutaten.reduce(0.0) { $0 + gramm($1.lebensmittel, menge: $1.menge, einheit: $1.einheit) }
        let summe = r.zutaten.reduce(Naehrwerte.null) { $0 + naehrwerte($1.lebensmittel, menge: $1.menge, einheit: $1.einheit) }
        let pro100 = gesamt > 0 ? summe.mal(100 / gesamt) : .null
        return Lebensmittel(id: "rezept-\(r.id)", name: r.name, pro100: pro100,
                            portionMenge: gesamt > 0 ? gesamt / Double(max(r.portionen, 1)) : 100, portionName: "Portion")
    }

    // MARK: Fasten

    /// Sekunden bis zum Ende des Fastenfensters, negativ = schon geschafft.
    static func fastenRest(start: Date, stunden: Int, jetzt: Date) -> TimeInterval {
        start.addingTimeInterval(Double(stunden) * 3600).timeIntervalSince(jetzt)
    }

    // MARK: Open Food Facts

    static let offFelder = "code,product_name,product_name_de,brands,quantity,serving_size,serving_quantity,product_quantity,product_quantity_unit,nutriments,nutriscore_grade,image_front_small_url"

    /// `/api/v2/product/<code>.json`. nil bei `status: 0` (unbekannt) oder ohne Kalorien.
    static func offProdukt(_ data: Data) -> Lebensmittel? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let status = zahlWert(json["status"]), status == 0 { return nil }
        guard let produkt = json["product"] as? [String: Any] else { return nil }
        return lebensmittel(offProdukt: produkt, code: json["code"] as? String)
    }

    /// search.openfoodfacts.org `hits`.
    static func offSuche(_ data: Data) -> [Lebensmittel] {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hits = json["hits"] as? [[String: Any]] else { return [] }
        return hits.compactMap { lebensmittel(offProdukt: $0, code: nil) }
    }

    static func lebensmittel(offProdukt p: [String: Any], code: String?) -> Lebensmittel? {
        let n = p["nutriments"] as? [String: Any] ?? [:]
        let kj = zahlWert(n["energy-kj_100g"]) ?? zahlWert(n["energy_100g"])
        let kcal = zahlWert(n["energy-kcal_100g"]) ?? kj.map { $0 / 4.184 }
        guard let kcal else { return nil }
        let barcode = (p["code"] as? String) ?? code
        let name = [p["product_name_de"], p["product_name"]].compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? "Unbekanntes Produkt"
        let marke: String?
        if let text = p["brands"] as? String {
            marke = text.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        } else if let liste = p["brands"] as? [String] {
            marke = liste.first?.trimmingCharacters(in: .whitespaces)
        } else {
            marke = nil
        }
        let einheit = (p["product_quantity_unit"] as? String)?.lowercased()
        let fluessig = einheit == "ml" || einheit == "l" || einheit == "cl"
        let werte = Naehrwerte(kcal: kcal, protein: zahlWert(n["proteins_100g"]) ?? 0,
                               kohlenhydrate: zahlWert(n["carbohydrates_100g"]) ?? 0, fett: zahlWert(n["fat_100g"]) ?? 0,
                               zucker: zahlWert(n["sugars_100g"]), ballaststoffe: zahlWert(n["fiber_100g"]),
                               salz: zahlWert(n["salt_100g"]), gesFett: zahlWert(n["saturated-fat_100g"]))
        let portion = zahlWert(p["serving_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        let packung = zahlWert(p["product_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        let grade = (p["nutriscore_grade"] as? String)?.lowercased()
        return Lebensmittel(id: "off-\(barcode ?? UUID().uuidString)", name: name, marke: marke?.isEmpty == true ? nil : marke,
                            barcode: barcode, fluessig: fluessig, pro100: werte, portionMenge: portion,
                            portionName: nil, packungMenge: packung,
                            nutriscore: ["a", "b", "c", "d", "e"].contains(grade ?? "") ? grade : nil,
                            bild: p["image_front_small_url"] as? String)
    }

    /// Zahl aus JSON, die als Zahl oder als Text ("496", "12,5") kommen kann.
    static func zahlWert(_ wert: Any?) -> Double? {
        if let n = wert as? NSNumber { return n.doubleValue }
        if let s = wert as? String { return Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
