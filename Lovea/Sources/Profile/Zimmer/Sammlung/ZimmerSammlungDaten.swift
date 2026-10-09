import Foundation
import UIKit

/// Lesen und Schreiben der `zimmer.*`-Sammlungen (Worker H). Jede Person schreibt nur ihre eigenen Schlüssel
/// (`EinstellungenModell.setzen`), beide lesen über `werte[person]`. Zusammengesetzte Werte liegen als JSON-Text
/// in einem String-Schlüssel, wie bei `ZimmerRitualeDaten`.
@MainActor
enum ZimmerSammlungDaten {
    typealias L = ZimmerSammlungLogik

    static let kassettenKey = "zimmer.kassetten"
    static let rezepteKey = "zimmer.rezepte"
    static let gekochtListeKey = "zimmer.gekocht"
    static let wuenscheKey = "zimmer.wunschrolle"
    static let hakenKey = "zimmer.wunschhaken"
    static let stimmungsverlaufKey = "zimmer.stimmungsverlauf"
    static let markenKey = "zimmer.wachstum"

    static var ich: Person { Raum.shared.ich ?? .ahmed }
    static var heute: String { Datum.text(Date()) }

    private static func lesen<T: Decodable>(_ schluessel: String, von person: Person, als typ: T.Type) -> T? {
        guard case .string(let s)? = EinstellungenModell.shared.werte[person]?[schluessel],
              let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    private static func schreiben<T: Encodable>(_ schluessel: String, _ wert: T) {
        guard let d = try? JSONEncoder().encode(wert), let s = String(data: d, encoding: .utf8) else { return }
        EinstellungenModell.shared.setzen(schluessel, .string(s))
    }

    // MARK: Mixtape

    static func kassetten(von person: Person) -> [L.Kassette] {
        lesen(kassettenKey, von: person, als: [L.Kassette].self) ?? []
    }

    static func kassetteLegen(url: String, titel: String) {
        let neu = L.Kassette(woche: L.woche(Date()), url: url, titel: titel)
        schreiben(kassettenKey, L.kassetteEinlegen(kassetten(von: ich), neu: neu))
    }

    // MARK: Rezeptkasten

    /// Beide Rezeptlisten zusammen, meine zuerst.
    static func alleRezepte() -> [L.Rezept] {
        (lesen(rezepteKey, von: ich, als: [L.Rezept].self) ?? []) + (lesen(rezepteKey, von: ich.partner, als: [L.Rezept].self) ?? [])
    }

    static func meineRezepte() -> [L.Rezept] { lesen(rezepteKey, von: ich, als: [L.Rezept].self) ?? [] }

    static func rezeptSpeichern(_ r: L.Rezept) {
        schreiben(rezepteKey, Array((meineRezepte() + [r]).suffix(L.rezepteMaximum)))
    }

    static func rezeptLoeschen(id: String) {
        schreiben(rezepteKey, meineRezepte().filter { $0.id != id })
    }

    static func gekochtAlle() -> [String] {
        (lesen(gekochtListeKey, von: ich, als: [String].self) ?? []) + (lesen(gekochtListeKey, von: ich.partner, als: [String].self) ?? [])
    }

    static func nochmalGekocht(rezeptId: String) {
        let meine = lesen(gekochtListeKey, von: ich, als: [String].self) ?? []
        schreiben(gekochtListeKey, L.gekocht(meine, rezeptId: rezeptId, tag: heute))
    }

    /// Kleines JPEG-Vorschaubild (längste Seite 72 pt), damit der Sync-Wert klein bleibt.
    static func vorschau(_ bild: UIImage) -> Data? {
        let lang = max(bild.size.width, bild.size.height)
        guard lang > 0 else { return nil }
        let faktor = min(1, 72 / lang)
        let groesse = CGSize(width: bild.size.width * faktor, height: bild.size.height * faktor)
        return (bild.preparingThumbnail(of: groesse) ?? bild).jpegData(compressionQuality: 0.5)
    }

    // MARK: Wunschrolle

    static func wuensche(von person: Person) -> [L.Wunsch] { lesen(wuenscheKey, von: person, als: [L.Wunsch].self) ?? [] }

    static func alleWuensche() -> [L.Wunsch] { wuensche(von: ich) + wuensche(von: ich.partner) }

    static func wunschHinzu(_ text: String) {
        guard let t = L.bereinigt(text, maximal: L.titelMaximum) else { return }
        let alt = wuensche(von: ich)
        guard alt.count < L.wuenscheMaximum else { return }
        schreiben(wuenscheKey, alt + [L.Wunsch(id: UUID().uuidString, text: t)])
    }

    static func wunschLoeschen(id: String) {
        schreiben(wuenscheKey, wuensche(von: ich).filter { $0.id != id })
    }

    static func haken(von person: Person) -> [String] { lesen(hakenKey, von: person, als: [String].self) ?? [] }

    static func hakenUmschalten(id: String) {
        schreiben(hakenKey, L.umschalten(haken(von: ich), id: id))
    }

    static func erledigt() -> Set<String> {
        L.gemeinsamErledigt(haken(von: ich), haken(von: ich.partner))
    }

    // MARK: Stimmungsregenbogen

    static func verlauf(von person: Person) -> [String: String] {
        lesen(stimmungsverlaufKey, von: person, als: [String: String].self) ?? [:]
    }

    /// Merkt die eigene aktuelle Stimmung für heute (nur wenn sie sich geändert hat, kein unnötiger Schreibvorgang).
    static func stimmungMerken(_ art: Gefuehl?) {
        guard let art else { return }
        let alt = verlauf(von: ich)
        guard alt[heute] != art.rawValue else { return }
        schreiben(stimmungsverlaufKey, L.verlaufEintragen(alt, tag: heute, art: art.rawValue))
    }

    // MARK: Wachstumsleiste

    static func eigeneMarken() -> [L.EigeneMarke] {
        (lesen(markenKey, von: ich, als: [L.EigeneMarke].self) ?? []) + (lesen(markenKey, von: ich.partner, als: [L.EigeneMarke].self) ?? [])
    }

    static func markeHinzu(titel: String, tag: String) {
        guard let t = L.bereinigt(titel, maximal: 24), L.tagDatum(tag) != nil else { return }
        let meine = lesen(markenKey, von: ich, als: [L.EigeneMarke].self) ?? []
        schreiben(markenKey, Array((meine + [L.EigeneMarke(titel: t, tag: tag)]).suffix(10)))
    }

    // MARK: Dankbarkeitsbaum (nur auf dem Gerät)

    private static let dankeSchluessel = "lovea.zimmer.danke"

    /// Zählt "danke" in den geladenen Nachrichten und merkt sich den höchsten Stand (der Chat lädt nicht alles).
    static func dankeBlaetter() -> Int {
        let texte: [String?] = ChatModell.shared.nachrichten.filter { !$0.geloescht && $0.system == nil }.map { $0.text }
        let jetzt = L.dankeZaehlen(texte)
        let alt = UserDefaults.standard.integer(forKey: dankeSchluessel)
        if jetzt > alt { UserDefaults.standard.set(jetzt, forKey: dankeSchluessel) }
        return max(jetzt, alt)
    }
}
