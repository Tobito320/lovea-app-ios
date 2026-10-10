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
    /// Vitamine, Mineralstoffe und weitere Werte, Schlüssel = `Mikro.rawValue`, Einheit = `Mikro.einheit`.
    var mikro: [String: Double]? = nil

    static let null = Naehrwerte()

    func wert(_ m: Mikro) -> Double? { mikro?[m.rawValue] }

    func mal(_ f: Double) -> Naehrwerte {
        Naehrwerte(kcal: kcal * f, protein: protein * f, kohlenhydrate: kohlenhydrate * f, fett: fett * f,
                   zucker: zucker.map { $0 * f }, ballaststoffe: ballaststoffe.map { $0 * f },
                   salz: salz.map { $0 * f }, gesFett: gesFett.map { $0 * f },
                   mikro: mikro.map { $0.mapValues { $0 * f } })
    }

    static func + (a: Naehrwerte, b: Naehrwerte) -> Naehrwerte {
        Naehrwerte(kcal: a.kcal + b.kcal, protein: a.protein + b.protein,
                   kohlenhydrate: a.kohlenhydrate + b.kohlenhydrate, fett: a.fett + b.fett,
                   zucker: plus(a.zucker, b.zucker), ballaststoffe: plus(a.ballaststoffe, b.ballaststoffe),
                   salz: plus(a.salz, b.salz), gesFett: plus(a.gesFett, b.gesFett),
                   mikro: mikroPlus(a.mikro, b.mikro))
    }

    private static func mikroPlus(_ a: [String: Double]?, _ b: [String: Double]?) -> [String: Double]? {
        guard let a else { return b }
        guard let b else { return a }
        return a.merging(b, uniquingKeysWith: +)
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
    /// "off-<barcode>", "eigen-<uuid>", "rezept-<uuid>", "schnell-<uuid>" oder "ki-<uuid>".
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
    /// Weitere Portionsgrößen wie in YAZIO ("ganze, mittelgroß" = 120 g). Optional, damit alte Einträge lesbar bleiben.
    var portionen: [LebensmittelPortion]?
    /// Vorberechneter Suchschlüssel aus dem Import (klein, ohne Umlaute), nur bei BLS-Einträgen.
    var suche: String?
    /// "bls" für Einträge aus dem Bundeslebensmittelschlüssel (Quellenangabe auf der Lebensmittel-Seite).
    var quelle: String?

    init(id: String, name: String, marke: String? = nil, barcode: String? = nil, fluessig: Bool = false,
         pro100: Naehrwerte, portionMenge: Double? = nil, portionName: String? = nil, packungMenge: Double? = nil,
         nutriscore: String? = nil, bild: String? = nil, portionen: [LebensmittelPortion]? = nil,
         suche: String? = nil, quelle: String? = nil) {
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
        self.portionen = portionen
        self.suche = suche
        self.quelle = quelle
    }

    static func == (a: Lebensmittel, b: Lebensmittel) -> Bool { a.id == b.id && a.name == b.name && a.pro100 == b.pro100 }
    func hash(into h: inout Hasher) { h.combine(id) }

    var basisEinheit: Einheit { fluessig ? .ml : .g }

    var istRezept: Bool { id.hasPrefix("rezept-") }
    /// Schnell-Einträge und Foto-Schätzungen gehören zu genau einer Mahlzeit, nicht in Zuletzt oder Häufig.
    var istEinmalig: Bool { id.hasPrefix("schnell-") || id.hasPrefix("ki-") }
    var anzeigeName: String { marke.map { "\(name) · \($0)" } ?? name }
}

/// Eine Portionsgröße, z. B. "ganze, mittelgroß" mit 120 g oder "Scheibe" mit 30 g.
struct LebensmittelPortion: Codable, Equatable, Hashable, Sendable, Identifiable {
    var name: String
    var gramm: Double
    var id: String { name }
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

enum RezeptArt: String, Codable, Sendable { case mahlzeit, rezept }

/// Op `rezept.setzen`: eigenes Rezept, für beide sichtbar. Wird als Lebensmittel mit Portionen eingetragen.
struct Rezept: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var portionen: Int
    var zutaten: [Zutat]
    var geloescht: Bool?
    /// nil = altes Rezept, zählt als `.rezept`.
    var art: RezeptArt?
    var anleitung: String?

    init(id: String, name: String, portionen: Int, zutaten: [Zutat], geloescht: Bool? = nil, art: RezeptArt? = nil, anleitung: String? = nil) {
        self.id = id; self.name = name; self.portionen = portionen; self.zutaten = zutaten
        self.geloescht = geloescht; self.art = art; self.anleitung = anleitung
    }

    var istMahlzeit: Bool { art == .mahlzeit }
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
    /// Flexible Tage (YAZIO Pro "Wochenend-Kalorien"): so viele kcal mehr an den Tagen in `extraTage`.
    var extraKcal: Int = 0
    /// Bitmaske der Wochentage, Bit 0 = Montag … Bit 6 = Sonntag.
    var extraTage: Int = 0

    static let felder = ["kcal", "protein", "kohlenhydrate", "fett", "geschlecht", "alter", "groesseCm", "aktivitaet",
                         "richtung", "tempo", "makroProfil", "fastenStunden", "eingerichtet", "extraKcal", "extraTage"]

    func istExtraTag(_ wochentag: Int) -> Bool { extraTage & (1 << (wochentag - 1)) != 0 }

    /// Die Ziele für einen bestimmten Tag: an flexiblen Tagen mehr kcal, Makros im selben Verhältnis.
    func fuer(tag: String) -> ErnaehrungsZiele {
        guard extraKcal != 0, istExtraTag(Datum.wochentag(tag)), kcal > 0 else { return self }
        var z = self
        let faktor = Double(kcal + extraKcal) / Double(kcal)
        z.kcal = kcal + extraKcal
        z.protein = Int((Double(protein) * faktor).rounded())
        z.kohlenhydrate = Int((Double(kohlenhydrate) * faktor).rounded())
        z.fett = Int((Double(fett) * faktor).rounded())
        return z
    }

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
        case "extraKcal": extraKcal
        case "extraTage": extraTage
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
        case "extraKcal": extraKcal = w
        case "extraTage": extraTage = w
        default: eingerichtet = w > 0
        }
    }
}

/// Körperwerte neben dem Gewicht (das Gewicht bleibt im Gewicht-Habit). Op `koerper.setzen`, einer pro Tag und Art.
enum KoerperArt: String, Codable, Sendable, CaseIterable, Identifiable {
    case koerperfett, taille, huefte, brust, oberarm, oberschenkel

    var id: String { rawValue }

    var name: String {
        switch self {
        case .koerperfett: "Körperfett"
        case .taille: "Taille"
        case .huefte: "Hüfte"
        case .brust: "Brust"
        case .oberarm: "Oberarm"
        case .oberschenkel: "Oberschenkel"
        }
    }

    var einheit: String { self == .koerperfett ? "%" : "cm" }
}

struct KoerperwertD: Codable, Equatable, Sendable {
    var datum: String
    var art: KoerperArt
    var wert: Double
    var geloescht: Bool?
}

/// Op `food.anpassung` (YAZIO Pro "Tagebuch anpassen"), pro Person, neueste gewinnt.
struct TagebuchAnpassung: Codable, Equatable, Sendable {
    static let alleAbschnitte = ["uebersicht", "ernaehrung", "wasser", "koerper"]
    static let standard = TagebuchAnpassung(reihenfolge: alleAbschnitte, ausgeblendet: [], mahlzeitNamen: [:])

    var reihenfolge: [String]
    var ausgeblendet: [String]
    /// `Mahlzeit.rawValue` -> eigener Name.
    var mahlzeitNamen: [String: String]

    /// Sichtbare Abschnitte in Reihenfolge; neue, noch unbekannte hinten angehängt.
    var sichtbar: [String] {
        let bekannt = reihenfolge.filter { Self.alleAbschnitte.contains($0) }
        let voll = bekannt + Self.alleAbschnitte.filter { !bekannt.contains($0) }
        return voll.filter { !ausgeblendet.contains($0) }
    }

    func name(_ m: Mahlzeit) -> String {
        let eigen = mahlzeitNamen[m.rawValue]?.trimmingCharacters(in: .whitespaces) ?? ""
        return eigen.isEmpty ? m.name : eigen
    }
}

// MARK: - Faltung

struct ErnaehrungFaltung: Sendable {
    static let arten: Set<String> = ["essen.setzen", "lebensmittel.setzen", "lebensmittel.favorit", "rezept.setzen", "fasten.setzen",
                                     "koerper.setzen", "food.anpassung"]

    private struct Stand<T: Sendable>: Sendable {
        var zeit: Date
        var wert: T
    }

    private var essen: [Person: [String: Stand<EssenEintrag>]] = [:]
    /// Eintrags-ids je Tag, damit Auswertungen über Monate nicht jedes Mal alle Einträge durchsuchen.
    private var tagIndex: [Person: [String: Set<String>]] = [:]
    private var eigene: [String: Stand<LebensmittelD>] = [:]
    private var favoriten: [Person: [String: Stand<FavoritD>]] = [:]
    private var rezepteStand: [String: Stand<Rezept>] = [:]
    private var fastenStand: [Person: Stand<FastenD>] = [:]
    private var koerper: [Person: [String: Stand<KoerperwertD>]] = [:]
    private var anpassungen: [Person: Stand<TagebuchAnpassung>] = [:]

    private var erstellerLebensmittel: [String: Person] = [:]
    private var erstellerRezept: [String: Person] = [:]
    private var erstellerZeit: [String: Date] = [:]

    /// Wer eine ID zuerst angelegt hat, unabhängig von der Reihenfolge, in der die Ops eintreffen.
    private mutating func ersteller(merken id: String, _ von: Person, _ zeit: Date, rezept: Bool) {
        guard zeit < (erstellerZeit[id] ?? .distantFuture) else { return }
        erstellerZeit[id] = zeit
        if rezept { erstellerRezept[id] = von } else { erstellerLebensmittel[id] = von }
    }
    func ersteller(lebensmittel id: String) -> Person? { erstellerLebensmittel[id] }
    func ersteller(rezept id: String) -> Person? { erstellerRezept[id] }

    mutating func anwenden(_ op: Op) {
        switch op.art {
        case "essen.setzen":
            guard let e = op.daten(EssenEintrag.self), (essen[op.von]?[e.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            if let alt = essen[op.von]?[e.id]?.wert.datum, alt != e.datum { tagIndex[op.von]?[alt]?.remove(e.id) }
            essen[op.von, default: [:]][e.id] = Stand(zeit: op.zeit, wert: e)
            tagIndex[op.von, default: [:]][e.datum, default: []].insert(e.id)
        case "lebensmittel.setzen":
            guard let d = op.daten(LebensmittelD.self) else { return }
            ersteller(merken: d.lebensmittel.id, op.von, op.zeit, rezept: false)
            guard (eigene[d.lebensmittel.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            eigene[d.lebensmittel.id] = Stand(zeit: op.zeit, wert: d)
        case "lebensmittel.favorit":
            guard let d = op.daten(FavoritD.self), (favoriten[op.von]?[d.lebensmittel.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            favoriten[op.von, default: [:]][d.lebensmittel.id] = Stand(zeit: op.zeit, wert: d)
        case "rezept.setzen":
            guard let r = op.daten(Rezept.self) else { return }
            ersteller(merken: r.id, op.von, op.zeit, rezept: true)
            guard (rezepteStand[r.id]?.zeit ?? .distantPast) <= op.zeit else { return }
            rezepteStand[r.id] = Stand(zeit: op.zeit, wert: r)
        case "fasten.setzen":
            guard let d = op.daten(FastenD.self), (fastenStand[op.von]?.zeit ?? .distantPast) <= op.zeit else { return }
            fastenStand[op.von] = Stand(zeit: op.zeit, wert: d)
        case "food.anpassung":
            guard let d = op.daten(TagebuchAnpassung.self), (anpassungen[op.von]?.zeit ?? .distantPast) <= op.zeit else { return }
            anpassungen[op.von] = Stand(zeit: op.zeit, wert: d)
        case "koerper.setzen":
            guard let d = op.daten(KoerperwertD.self) else { return }
            let schluessel = d.art.rawValue + "|" + d.datum
            guard (koerper[op.von]?[schluessel]?.zeit ?? .distantPast) <= op.zeit else { return }
            koerper[op.von, default: [:]][schluessel] = Stand(zeit: op.zeit, wert: d)
        default:
            break
        }
    }

    /// Einträge eines Tages in der Reihenfolge, in der sie zuletzt geändert wurden.
    func eintraege(_ p: Person, _ tag: String) -> [EssenEintrag] {
        let alle = essen[p] ?? [:]
        return (tagIndex[p]?[tag] ?? []).compactMap { alle[$0] }
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
            guard !l.istEinmalig, gesehen.insert(l.id).inserted else { continue }
            liste.append(l)
            if liste.count == anzahl { break }
        }
        return liste
    }

    /// Am häufigsten gegessen in den letzten 90 Tagen, bei Gleichstand das zuletzt gegessene zuerst.
    func haeufig(_ p: Person, anzahl: Int = 40) -> [Lebensmittel] {
        let grenze = Datum.addTage(Datum.text(Date()), -90)
        var zahl: [String: (n: Int, zeit: Date, l: Lebensmittel)] = [:]
        for s in (essen[p] ?? [:]).values where s.wert.geloescht != true && s.wert.datum >= grenze && !s.wert.lebensmittel.istEinmalig {
            let alt = zahl[s.wert.lebensmittel.id]
            zahl[s.wert.lebensmittel.id] = ((alt?.n ?? 0) + 1, max(alt?.zeit ?? .distantPast, s.zeit), s.wert.lebensmittel)
        }
        return zahl.values.sorted { $0.n != $1.n ? $0.n > $1.n : $0.zeit > $1.zeit }.prefix(anzahl).map(\.l)
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

    func anpassung(_ p: Person) -> TagebuchAnpassung { anpassungen[p]?.wert ?? .standard }

    /// Neuester Körperwert dieser Art bis einschließlich `tag`.
    func koerperwert(_ p: Person, _ art: KoerperArt, bis tag: String) -> KoerperwertD? {
        (koerper[p] ?? [:]).values.map(\.wert)
            .filter { $0.art == art && $0.geloescht != true && $0.datum <= tag }
            .max { $0.datum < $1.datum }
    }

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

    /// Alle Portionsgrößen zur Auswahl, ohne doppelte Namen: eigene Liste, Portion der Packung, ganze
    /// Packung, dann Haushaltsmaße aus dem Namen (Teelöffel, Esslöffel, …), auch für Importe ohne Portionen.
    static func portionsAuswahl(_ l: Lebensmittel) -> [LebensmittelPortion] {
        var liste = l.portionen ?? []
        if let menge = l.portionMenge, menge > 0 {
            liste.append(LebensmittelPortion(name: l.portionName ?? "Portion", gramm: menge))
        }
        if let menge = l.packungMenge, menge > 0 { liste.append(LebensmittelPortion(name: "Packung", gramm: menge)) }
        liste += HaushaltsMasse.portionen(fuer: l)
        var gesehen: Set<String> = []
        return liste.filter { $0.gramm > 0 && gesehen.insert($0.name).inserted }
    }

    /// Das Lebensmittel mit dieser Portion als `.portion`: der Eintrag speichert Name und Gewicht mit.
    static func mitPortion(_ l: Lebensmittel, _ p: LebensmittelPortion) -> Lebensmittel {
        var neu = l
        neu.portionMenge = p.gramm
        neu.portionName = p.name
        return neu
    }

    /// Getränke zählen mit ihren ml als Wasser (Näherung für YAZIOs "Wasser aus Lebensmitteln").
    static func wasserAusLebensmitteln(_ eintraege: [EssenEintrag]) -> Double {
        eintraege.filter { $0.lebensmittel.fluessig }
            .reduce(0.0) { $0 + gramm($1.lebensmittel, menge: $1.menge, einheit: $1.einheit) }
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

    /// Summe aller Zutaten einer Mahlzeit (ohne Portionen, die Mahlzeit ist die Menge).
    static func summe(_ r: Rezept) -> Naehrwerte {
        r.zutaten.reduce(Naehrwerte.null) { $0 + naehrwerte($1.lebensmittel, menge: $1.menge, einheit: $1.einheit) }
    }

    /// Eine gespeicherte Mahlzeit als einzelne Tagebuch-Einträge, einer je Zutat mit eigener neuer ID.
    /// So lässt sich jede Zutat am Tag ändern oder löschen, ohne die Vorlage anzufassen.
    static func eintraege(_ r: Rezept, mahlzeit: Mahlzeit, datum: String, neueId: () -> String = { UUID().uuidString }) -> [EssenEintrag] {
        r.zutaten.map {
            EssenEintrag(id: neueId(), datum: datum, mahlzeit: mahlzeit, menge: $0.menge, einheit: $0.einheit,
                         lebensmittel: $0.lebensmittel, geloescht: nil)
        }
    }

    // MARK: Fasten

    /// Sekunden bis zum Ende des Fastenfensters, negativ = schon geschafft.
    static func fastenRest(start: Date, stunden: Int, jetzt: Date) -> TimeInterval {
        start.addingTimeInterval(Double(stunden) * 3600).timeIntervalSince(jetzt)
    }

    // MARK: Open Food Facts

    static let offFelder = "code,product_name,product_name_de,brands,quantity,serving_size,serving_quantity,product_quantity,product_quantity_unit,nutriments,nutriscore_grade"

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
                               salz: zahlWert(n["salt_100g"]), gesFett: zahlWert(n["saturated-fat_100g"]),
                               mikro: Mikro.ausOpenFoodFacts(n))
        let portion = zahlWert(p["serving_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        let packung = zahlWert(p["product_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        let grade = (p["nutriscore_grade"] as? String)?.lowercased()
        let portionName: String? = portion == nil ? nil : (p["serving_size"] as? String).flatMap { portionsName($0) }
        return Lebensmittel(id: "off-\(barcode ?? UUID().uuidString)", name: name, marke: marke?.isEmpty == true ? nil : marke,
                            barcode: barcode, fluessig: fluessig, pro100: werte, portionMenge: portion,
                            portionName: portionName, packungMenge: packung,
                            nutriscore: ["a", "b", "c", "d", "e"].contains(grade ?? "") ? grade : nil)
    }

    /// "1 Riegel (45 g)" -> "Riegel", "30g" -> nil. Nur ein Wort ohne Zahl und Klammer taugt als Name.
    static func portionsName(_ text: String) -> String? {
        var t = text
        if let klammer = t.firstIndex(of: "(") { t = String(t[..<klammer]) }
        t = t.trimmingCharacters(in: .whitespaces)
        while let erstes = t.first, erstes.isNumber || erstes == "," || erstes == "." || erstes == " " { t.removeFirst() }
        t = t.trimmingCharacters(in: .whitespaces)
        let einheiten = ["g", "gr", "ml", "l", "kg", "cl"]
        guard !t.isEmpty, !einheiten.contains(t.lowercased()) else { return nil }
        return t
    }

    /// Zahl aus JSON, die als Zahl oder als Text ("496", "12,5") kommen kann.
    static func zahlWert(_ wert: Any?) -> Double? {
        if let n = wert as? NSNumber { return n.doubleValue }
        if let s = wert as? String { return Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
