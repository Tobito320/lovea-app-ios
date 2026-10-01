import Foundation
import Observation

/// Tagebuch, eigene Lebensmittel, Rezepte, Favoriten und Fasten beider Personen (`ErnaehrungFaltung`).
/// Ziele liegen als `ziel.ernaehrung.*` in `HealthModell`, das Gewicht im Gewicht-Habit.
@MainActor @Observable
final class ErnaehrungModell {
    static let shared = ErnaehrungModell()
    private var faltung = ErnaehrungFaltung()

    private init() {
        StartProtokoll.marke("ernaehrungModell.init.vor")
        Raum.shared.beobachten(ErnaehrungFaltung.arten) { [weak self] op in self?.faltung.anwenden(op) }
        StartProtokoll.marke("ernaehrungModell.init.nach")
    }

    var ich: Person { Raum.shared.ich ?? .ahmed }

    // MARK: - Lesen

    func eintraege(_ p: Person, _ tag: String) -> [EssenEintrag] { faltung.eintraege(p, tag) }
    func eintraege(_ p: Person, _ tag: String, _ m: Mahlzeit) -> [EssenEintrag] { faltung.eintraege(p, tag).filter { $0.mahlzeit == m } }
    func summe(_ p: Person, _ tag: String) -> Naehrwerte { ErnaehrungLogik.summe(eintraege(p, tag)) }
    func tage(_ p: Person) -> Set<String> { faltung.tage(p) }
    func zuletzt(_ p: Person) -> [Lebensmittel] { faltung.zuletzt(p) }
    func haeufig(_ p: Person) -> [Lebensmittel] { faltung.haeufig(p) }
    func letzteMenge(_ p: Person, _ l: Lebensmittel) -> (menge: Double, einheit: Einheit)? { faltung.letzteMenge(p, l.id) }
    var eigene: [Lebensmittel] { faltung.eigeneLebensmittel }
    /// Rezept-Favoriten zeigen immer die aktuelle Fassung, gelöschte Rezepte fallen weg.
    func favoriten(_ p: Person) -> [Lebensmittel] {
        faltung.favoritenListe(p).compactMap { l in l.istRezept ? rezeptAktuell(l.id) : l }
    }
    func istFavorit(_ l: Lebensmittel) -> Bool { faltung.istFavorit(ich, l.id) }
    var rezepte: [Rezept] { faltung.rezepte }
    func ersteller(_ l: Lebensmittel) -> Person? { faltung.ersteller(lebensmittel: l.id) }
    func ersteller(_ r: Rezept) -> Person? { faltung.ersteller(rezept: r.id) }
    func eigene(von p: Person) -> [Lebensmittel] { eigene.filter { (ersteller($0) ?? p) == p } }
    func rezepte(von p: Person, art: RezeptArt?) -> [Rezept] {
        rezepte.filter { (ersteller($0) ?? p) == p && (art == nil || ($0.art ?? .rezept) == art) }
    }
    /// Für `rezept-…`-IDs die neueste Fassung als Lebensmittel, sonst nil.
    func rezeptAktuell(_ lebensmittelId: String) -> Lebensmittel? {
        guard lebensmittelId.hasPrefix("rezept-") else { return nil }
        let id = String(lebensmittelId.dropFirst("rezept-".count))
        return rezepte.first { $0.id == id }.map(ErnaehrungLogik.alsLebensmittel)
    }
    func kopieren(_ r: Rezept) {
        var neu = r
        neu.id = UUID().uuidString
        rezeptSichern(neu)
    }
    func kopieren(_ l: Lebensmittel) {
        var neu = l
        neu.id = "eigen-\(UUID().uuidString)"
        eigenesSichern(neu)
    }
    func fasten(_ p: Person) -> FastenD? { faltung.fasten(p) }
    func anpassung(_ p: Person) -> TagebuchAnpassung { faltung.anpassung(p) }
    /// Name der Mahlzeit, wie `p` sie genannt hat.
    func mahlzeitName(_ m: Mahlzeit, _ p: Person? = nil) -> String { anpassung(p ?? ich).name(m) }
    func anpassungSichern(_ a: TagebuchAnpassung) { Raum.shared.senden("food.anpassung", a) }
    func koerperwert(_ p: Person, _ art: KoerperArt, bis tag: String) -> KoerperwertD? { faltung.koerperwert(p, art, bis: tag) }

    /// Gewicht (Zehntel-kg) an diesem Tag, sonst das letzte davor, mit Datum.
    func gewicht(_ p: Person, bis tag: String) -> (zehntel: Int, datum: String)? {
        HealthModell.shared.habitWerte(Habit.gewicht.id, p).filter { $0.value > 0 && $0.key <= tag }
            .max { $0.key < $1.key }
            .map { (zehntel: $0.value, datum: $0.key) }
    }
    func offline(barcode: String) -> Lebensmittel? { faltung.lebensmittel(barcode: barcode, ich) }

    // MARK: - Offene Barcodes (offline gescannt, laufen beim nächsten Öffnen der Ernährung nach, nie im Hintergrund)

    private static let offeneSchluessel = "essen.offeneBarcodes"
    var offeneBarcodes: [String] { UserDefaults.standard.stringArray(forKey: Self.offeneSchluessel) ?? [] }
    func merken(_ code: String) {
        UserDefaults.standard.set(Array(Set(offeneBarcodes + [code])), forKey: Self.offeneSchluessel)
    }
    /// Gefundene Produkte zurück; die Barcodes verschwinden aus der Liste, sobald die Kette etwas anderes als `.offline` liefert.
    func nachholen() async -> [Lebensmittel] {
        var gefunden: [Lebensmittel] = []
        var bleiben: [String] = []
        for code in offeneBarcodes {
            switch await BarcodeKette.suchen(code, .echt) {
            case .gefunden(let l): gefunden.append(l)
            case .offline: bleiben.append(code)
            default: break
            }
        }
        UserDefaults.standard.set(bleiben, forKey: Self.offeneSchluessel)
        return gefunden
    }

    /// Nie eingerichtet: aus dem Gewicht geschätzt (Standardwerte für den Rest), ohne Fragebogen.
    func ziele(_ p: Person) -> ErnaehrungsZiele {
        var z = ErnaehrungsZiele()
        for feld in ErnaehrungsZiele.felder {
            if let w = HealthModell.shared.ziel("ziel.ernaehrung.\(feld)", p) { z.setzen(feld, w) }
        }
        guard !z.eingerichtet else { return z }
        if p == .annika && HealthModell.shared.ziel("ziel.ernaehrung.geschlecht", p) == nil { z.geschlecht = 1 }
        return ErnaehrungLogik.berechnet(z, kg: gewichtKg(p) ?? (z.geschlecht == 1 ? 62 : 78))
    }

    /// Ziele an einem bestimmten Tag (flexible Tage eingerechnet).
    func ziele(_ p: Person, tag: String) -> ErnaehrungsZiele { ziele(p).fuer(tag: tag) }

    /// Berechnetes Gewicht (`GewichtLogik`, wie die Health-Kachel), nil wenn nie eingetragen.
    func gewichtKg(_ p: Person) -> Double? {
        GewichtLogik.berechnet(HealthModell.shared.habitWerte(Habit.gewicht.id, p)).map { Double($0) / 10 }
    }

    /// Aktive Kalorien aus Apple Health (nur Anzeige, zählt nicht zum Ziel).
    func verbrannt(_ p: Person, _ tag: String) -> Int? { HealthModell.shared.extrasAm(p, tag)?.kcal }

    // MARK: - Schreiben (eigene Person)

    /// `id` fest vorgeben, wenn ein anderer Teil der App diesen Eintrag später wiederfinden muss
    /// (R10: die Koffein-Kachel verknüpft so ihren Tipp mit genau diesem Tagebuch-Eintrag).
    func eintragen(_ l: Lebensmittel, menge: Double, einheit: Einheit, mahlzeit: Mahlzeit, datum: String, id: String = UUID().uuidString) {
        let e = EssenEintrag(id: id, datum: datum, mahlzeit: mahlzeit, menge: menge, einheit: einheit,
                             lebensmittel: l, geloescht: nil)
        let vorher = summe(ich, datum).protein
        Raum.shared.senden("essen.setzen", e)
        proteinPruefen(datum, protein: vorher + e.naehrwerte.protein)
        EssenLive.abgleichen()
    }

    func aendern(_ e: EssenEintrag) {
        let ohne = eintraege(ich, e.datum).filter { $0.id != e.id }
        Raum.shared.senden("essen.setzen", e)
        proteinPruefen(e.datum, protein: ErnaehrungLogik.summe(ohne).protein + e.naehrwerte.protein)
        EssenLive.abgleichen()
    }

    func loeschen(_ e: EssenEintrag) {
        var weg = e
        weg.geloescht = true
        Raum.shared.senden("essen.setzen", weg)
        EssenLive.abgleichen()
    }

    /// Alle Einträge einer Mahlzeit von einem anderen Tag noch einmal eintragen.
    func kopieren(von: String, nach: String, mahlzeit: Mahlzeit) {
        for e in eintraege(ich, von, mahlzeit) {
            eintragen(e.lebensmittel, menge: e.menge, einheit: e.einheit, mahlzeit: mahlzeit, datum: nach)
        }
    }

    func eigenesSichern(_ l: Lebensmittel) { Raum.shared.senden("lebensmittel.setzen", LebensmittelD(lebensmittel: l, geloescht: nil)) }
    func eigenesLoeschen(_ l: Lebensmittel) { Raum.shared.senden("lebensmittel.setzen", LebensmittelD(lebensmittel: l, geloescht: true)) }
    func favoritSetzen(_ l: Lebensmittel, an: Bool) { Raum.shared.senden("lebensmittel.favorit", FavoritD(lebensmittel: l, an: an)) }

    func rezeptSichern(_ r: Rezept) { Raum.shared.senden("rezept.setzen", r) }

    func rezeptLoeschen(_ r: Rezept) {
        var weg = r
        weg.geloescht = true
        Raum.shared.senden("rezept.setzen", weg)
    }

    func koerperwertSetzen(_ art: KoerperArt, _ wert: Double, datum: String) {
        Raum.shared.senden("koerper.setzen", KoerperwertD(datum: datum, art: art, wert: wert, geloescht: nil))
    }

    func gewichtSetzen(zehntel: Int, datum: String) {
        HealthModell.shared.setzeHabit(Habit.gewicht.id, datum: datum, wert: max(0, zehntel))
    }

    func fastenStarten(_ start: Date = Date()) { Raum.shared.senden("fasten.setzen", FastenD(start: start, ende: nil)) }
    func fastenBeenden() { Raum.shared.senden("fasten.setzen", FastenD(start: nil, ende: Date())) }

    /// Schickt nur geänderte Felder, beim ersten Einrichten alle.
    func zieleSichern(_ z: ErnaehrungsZiele) {
        let alt = ziele(ich)
        var neu = z
        neu.eingerichtet = true
        for feld in ErnaehrungsZiele.felder where !alt.eingerichtet || neu.wert(feld) != alt.wert(feld) {
            HealthModell.shared.setzeZiel("ziel.ernaehrung.\(feld)", neu.wert(feld))
        }
    }

    /// Hakt das Protein-Habit ab, sobald das Protein-Ziel des Tages erreicht ist. Nie wieder ab.
    private func proteinPruefen(_ datum: String, protein: Double) {
        guard protein >= Double(ziele(ich, tag: datum).protein), HealthModell.shared.habitWert(Habit.protein.id, ich, datum) == 0 else { return }
        HealthModell.shared.setzeHabit(Habit.protein.id, datum: datum, wert: 1)
    }
}

/// Open Food Facts: Produkt per Barcode (15 Anfragen/min) und Textsuche über search.openfoodfacts.org
/// (10/min, deshalb nur auf Absenden, nie beim Tippen). Fallback hinter dem eigenen Server.
enum OFFClient {
    enum Fehler: Error { case netz }

    private static let agent = "Lovea-iOS/1.0"

    /// nil = Produkt unbekannt oder ohne Nährwerte.
    static func produkt(_ barcode: String) async throws -> Lebensmittel? {
        let ziffern = BarcodeLogik.normal(barcode)
        guard !ziffern.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(ziffern).json?fields=\(ErnaehrungLogik.offFelder)")
        else { return nil }
        for versuch in 0..<2 {
            let (data, status) = try await laden(url, timeout: 8)
            if status == 404 { return nil }
            if (200..<300).contains(status) { return ErnaehrungLogik.offProdukt(data) }
            if versuch == 0, status == 429 || status >= 500 { try await Task.sleep(for: .seconds(1)); continue }
            throw Fehler.netz
        }
        throw Fehler.netz
    }

    static func suchen(_ text: String) async throws -> [Lebensmittel] {
        var teile = URLComponents(string: "https://search.openfoodfacts.org/search")
        teile?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "page_size", value: "30"),
            URLQueryItem(name: "langs", value: "de"),
            URLQueryItem(name: "fields", value: ErnaehrungLogik.offFelder),
        ]
        guard let url = teile?.url else { return [] }
        let (data, status) = try await laden(url)
        guard (200..<300).contains(status) else { throw Fehler.netz }
        return ErnaehrungLogik.offSuche(data)
    }

    private static func laden(_ url: URL, timeout: TimeInterval = 15) async throws -> (Data, Int) {
        var anfrage = URLRequest(url: url)
        anfrage.setValue(agent, forHTTPHeaderField: "User-Agent")
        anfrage.timeoutInterval = timeout
        let (data, antwort) = try await URLSession.shared.data(for: anfrage)
        return (data, (antwort as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
