import Foundation
import Observation

/// Tagebuch, eigene Lebensmittel, Rezepte, Favoriten und Fasten beider Personen (`ErnaehrungFaltung`).
/// Ziele liegen als `ziel.ernaehrung.*` in `HealthModell`, das Gewicht im Gewicht-Habit.
@MainActor @Observable
final class ErnaehrungModell {
    static let shared = ErnaehrungModell()
    private var faltung = ErnaehrungFaltung()

    private init() {
        Raum.shared.beobachten(ErnaehrungFaltung.arten) { [weak self] op in self?.faltung.anwenden(op) }
    }

    var ich: Person { Raum.shared.ich ?? .ahmed }

    // MARK: - Lesen

    func eintraege(_ p: Person, _ tag: String) -> [EssenEintrag] { faltung.eintraege(p, tag) }
    func eintraege(_ p: Person, _ tag: String, _ m: Mahlzeit) -> [EssenEintrag] { faltung.eintraege(p, tag).filter { $0.mahlzeit == m } }
    func summe(_ p: Person, _ tag: String) -> Naehrwerte { ErnaehrungLogik.summe(eintraege(p, tag)) }
    func tage(_ p: Person) -> Set<String> { faltung.tage(p) }
    func zuletzt(_ p: Person) -> [Lebensmittel] { faltung.zuletzt(p) }
    func letzteMenge(_ p: Person, _ l: Lebensmittel) -> (menge: Double, einheit: Einheit)? { faltung.letzteMenge(p, l.id) }
    var eigene: [Lebensmittel] { faltung.eigeneLebensmittel }
    func favoriten(_ p: Person) -> [Lebensmittel] { faltung.favoritenListe(p) }
    func istFavorit(_ l: Lebensmittel) -> Bool { faltung.istFavorit(ich, l.id) }
    var rezepte: [Rezept] { faltung.rezepte }
    func fasten(_ p: Person) -> FastenD? { faltung.fasten(p) }
    func offline(barcode: String) -> Lebensmittel? { faltung.lebensmittel(barcode: barcode, ich) }

    func ziele(_ p: Person) -> ErnaehrungsZiele {
        var z = ErnaehrungsZiele()
        for feld in ErnaehrungsZiele.felder {
            if let w = HealthModell.shared.ziel("ziel.ernaehrung.\(feld)", p) { z.setzen(feld, w) }
        }
        return z
    }

    /// Neuestes Gewicht aus dem Gewicht-Habit, nil wenn nie eingetragen.
    func gewichtKg(_ p: Person) -> Double? {
        HealthModell.shared.habitWerte(Habit.gewicht.id, p).filter { $0.value > 0 }
            .max { $0.key < $1.key }
            .map { Double($0.value) / 10 }
    }

    /// Aktive Kalorien aus Apple Health (nur Anzeige, zählt nicht zum Ziel).
    func verbrannt(_ p: Person, _ tag: String) -> Int? { HealthModell.shared.extrasAm(p, tag)?.kcal }

    // MARK: - Schreiben (eigene Person)

    func eintragen(_ l: Lebensmittel, menge: Double, einheit: Einheit, mahlzeit: Mahlzeit, datum: String) {
        let e = EssenEintrag(id: UUID().uuidString, datum: datum, mahlzeit: mahlzeit, menge: menge, einheit: einheit,
                             lebensmittel: l, geloescht: nil)
        let vorher = summe(ich, datum).protein
        Raum.shared.senden("essen.setzen", e)
        proteinPruefen(datum, protein: vorher + e.naehrwerte.protein)
    }

    func aendern(_ e: EssenEintrag) {
        let ohne = eintraege(ich, e.datum).filter { $0.id != e.id }
        Raum.shared.senden("essen.setzen", e)
        proteinPruefen(e.datum, protein: ErnaehrungLogik.summe(ohne).protein + e.naehrwerte.protein)
    }

    func loeschen(_ e: EssenEintrag) {
        var weg = e
        weg.geloescht = true
        Raum.shared.senden("essen.setzen", weg)
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
        guard protein >= Double(ziele(ich).protein), HealthModell.shared.habitWert(Habit.protein.id, ich, datum) == 0 else { return }
        HealthModell.shared.setzeHabit(Habit.protein.id, datum: datum, wert: 1)
    }
}

/// Open Food Facts: Produkt per Barcode (15 Anfragen/min) und Textsuche über search.openfoodfacts.org
/// (10/min, deshalb nur auf Absenden, nie beim Tippen).
enum OFFClient {
    enum Fehler: Error { case netz }

    private static let agent = "Lovea-iOS/1.0"

    /// nil = Produkt unbekannt oder ohne Nährwerte.
    static func produkt(_ barcode: String) async throws -> Lebensmittel? {
        let ziffern = barcode.filter(\.isNumber)
        guard !ziffern.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(ziffern).json?fields=\(ErnaehrungLogik.offFelder)")
        else { return nil }
        let (data, status) = try await laden(url)
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw Fehler.netz }
        return ErnaehrungLogik.offProdukt(data)
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

    private static func laden(_ url: URL) async throws -> (Data, Int) {
        var anfrage = URLRequest(url: url)
        anfrage.setValue(agent, forHTTPHeaderField: "User-Agent")
        anfrage.timeoutInterval = 15
        let (data, antwort) = try await URLSession.shared.data(for: anfrage)
        return (data, (antwort as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
