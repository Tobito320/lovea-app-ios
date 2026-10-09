import Foundation
import Observation

/// p71: gespeicherte Looks (5 Plätze je Person, Tippen = anziehen) und das Outfit des Tages mit Herz.
/// Alles sind eigene, optionale Sync-Ops; ältere Builds ignorieren sie. Der Server nimmt jede Op-Art an,
/// eine Push-Regel dafür gibt es noch nicht (nur Hinweis in der offenen App, `BannerZentrale`).
struct PlatzD: Codable, Equatable { let platz: Int; let look: FigurAussehen }
struct TagesOutfitD: Codable, Equatable { let tag: String; let look: FigurAussehen }
struct OutfitHerzD: Codable, Equatable { let fuer: Person; let tag: String }

struct LookStand: Equatable {
    /// Plätze 0...4 je Person, der Schreiber ist immer `op.von`.
    var plaetze: [Person: [Int: FigurAussehen]] = [:]
    /// Das Outfit des jüngsten Tages je Person.
    var tagesOutfit: [Person: TagesOutfitD] = [:]
    /// "fuer|tag|von": wer wem für welchen Tag ein Herz gab.
    var herzen: Set<String> = []
}

enum LookLogik {
    static let plaetze = 5

    static func herzSchluessel(fuer: Person, tag: String, von: Person) -> String { "\(fuer.rawValue)|\(tag)|\(von.rawValue)" }

    /// Faltet eine Op in den Stand. Wer schreibt, bestimmt `op.von`: niemand legt Looks oder Herzen für andere ab.
    static func falten(_ stand: inout LookStand, _ op: Op) {
        switch op.art {
        case "look.platz":
            guard let d = op.daten(PlatzD.self), (0..<plaetze).contains(d.platz) else { return }
            stand.plaetze[op.von, default: [:]][d.platz] = d.look
        case "outfit.tag":
            guard let d = op.daten(TagesOutfitD.self) else { return }
            // Ein älterer Tag überschreibt nie einen jüngeren (yyyy-MM-dd sortiert als Text).
            if let alt = stand.tagesOutfit[op.von], alt.tag > d.tag { return }
            stand.tagesOutfit[op.von] = d
        case "outfit.herz":
            // Ein Herz für das eigene Outfit zählt nicht.
            guard let d = op.daten(OutfitHerzD.self), d.fuer != op.von else { return }
            stand.herzen.insert(herzSchluessel(fuer: d.fuer, tag: d.tag, von: op.von))
        default:
            break
        }
    }

    /// Text für den In-App-Hinweis zu einer frischen Op des Partners, sonst nil.
    static func hinweis(_ op: Op, ich: Person?) -> String? {
        guard let ich, op.von != ich else { return nil }
        switch op.art {
        case "outfit.tag":
            return "\(op.von.name) hat das Outfit für heute gewählt"
        case "outfit.herz":
            return op.daten(OutfitHerzD.self)?.fuer == ich ? "\(op.von.name) gibt deinem Outfit ein Herz" : nil
        default:
            return nil
        }
    }
}

extension LookStand {
    func tagesLook(_ person: Person, tag: String) -> FigurAussehen? {
        guard let t = tagesOutfit[person], t.tag == tag else { return nil }
        return t.look
    }

    func herz(von: Person, fuer: Person, tag: String) -> Bool {
        herzen.contains(LookLogik.herzSchluessel(fuer: fuer, tag: tag, von: von))
    }
}

extension FigurAussehen {
    /// Nur die Kleidung von `q` übernehmen: Oberteil, Jacke, Hose, Schuhe samt Farben, Kopfbedeckung, Brille,
    /// Ohrringe, AirPods und Alltagsschmuck. Gesicht, Haare, Bart, Körper, Bauch und die gekauften Teile
    /// (Tasche, Uhr, Schmuck, Haustier) bleiben, wie sie sind.
    func mitKleidung(von q: FigurAussehen) -> FigurAussehen {
        var a = self
        a.oberteil = q.oberteil; a.oberteilfarbe = q.oberteilfarbe; a.oberteilfarbeHex = q.oberteilfarbeHex
        a.jacke = q.jacke; a.jackenfarbe = q.jackenfarbe; a.jackenfarbeHex = q.jackenfarbeHex
        a.hose = q.hose; a.hosenfarbe = q.hosenfarbe; a.hosenfarbeHex = q.hosenfarbeHex
        a.schuhe = q.schuhe; a.schuhfarbe = q.schuhfarbe; a.schuhfarbeHex = q.schuhfarbeHex
        a.kopfbedeckung = q.kopfbedeckung; a.muetzenfarbe = q.muetzenfarbe
        a.brille = q.brille; a.ohrringe = q.ohrringe; a.airpods = q.airpods
        a.kette = q.kette; a.ring = q.ring; a.armband = q.armband; a.uhrAlltag = q.uhrAlltag
        return a
    }
}

@MainActor @Observable
final class LookSpeicher {
    static let shared = LookSpeicher()

    private(set) var stand = LookStand()
    /// Von `BannerZentrale` gesetzt: ein frischer Hinweistext des Partners.
    var aufFrisch: ((String) -> Void)?
    private var gesehen: Set<String> = []

    private init() {
        Raum.shared.beobachten(["look.platz", "outfit.tag", "outfit.herz"]) { [weak self] op in
            self?.verarbeiten(op)
        }
    }

    /// Eigene Ops kommen doppelt an (optimistisch und bestätigt), darum nach `Op.id` entdoppeln.
    private func verarbeiten(_ op: Op) {
        guard gesehen.insert(op.id).inserted else { return }
        LookLogik.falten(&stand, op)
        if Date().timeIntervalSince(op.zeit) < 60, let text = LookLogik.hinweis(op, ich: Raum.shared.ich) { aufFrisch?(text) }
    }

    func plaetze(_ person: Person) -> [Int: FigurAussehen] { stand.plaetze[person] ?? [:] }

    func platzSichern(_ platz: Int, _ look: FigurAussehen) {
        Raum.shared.senden("look.platz", PlatzD(platz: platz, look: look))
    }

    func tagesOutfitSetzen(_ look: FigurAussehen, tag: String = Datum.text(Date())) {
        Raum.shared.senden("outfit.tag", TagesOutfitD(tag: tag, look: look))
    }

    func herzGeben(fuer: Person, tag: String) {
        Raum.shared.senden("outfit.herz", OutfitHerzD(fuer: fuer, tag: tag))
    }
}
