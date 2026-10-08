import SwiftUI

/// Die Muskelkarte: Körperumriss mit Muskelflächen aus `muskelkarte.json`, vier Ansichten (Mann und Frau,
/// vorne und hinten). Herkunft der Geometrie und Lizenzen: `tools/opengym/NOTICE.md` (openGym, AGPL-3.0,
/// freigegeben für die private App; die Pfade selbst sind von MuscleMap, MIT). Erzeugt mit
/// `node tools/muskelkarte-bauen.mjs`. Einmal geladen je Person (`ahmed` = Mann, `annika` = Frau).
enum MuskelPfade {
    enum Seite: Sendable { case vorne, hinten }

    /// Eine Muskelfläche in Karten-Koordinaten. Ein Muskel besteht oft aus mehreren Flächen (links, rechts).
    struct Flaeche: Sendable {
        let gruppe: MuskelGruppe
        let seite: Seite
        let pfad: Path
    }

    /// Teil der Silhouette ohne Training: Kopf, Haare, Hals, Hände, Füße, Knie, Knöchel.
    struct Still: Sendable {
        let haar: Bool
        let pfad: Path
    }

    /// Eine Ansicht mit eigenem Kartenrahmen (viewBox der Quelle).
    struct Bild: Sendable {
        let rahmen: CGRect
        let still: [Still]
        /// In Zeichenreihenfolge: später gezeichnet liegt oben und gewinnt beim Treffertest.
        let flaechen: [Flaeche]

        func massstab(in groesse: CGSize) -> CGFloat {
            min(groesse.width / rahmen.width, groesse.height / rahmen.height)
        }

        /// Ein Punkt in der Fläche `groesse` (Karte passt mittig hinein, Seitenverhältnis bleibt) als Kartenpunkt.
        func kartenpunkt(_ ort: CGPoint, in groesse: CGSize) -> CGPoint {
            let s = massstab(in: groesse)
            let dx = (groesse.width - rahmen.width * s) / 2, dy = (groesse.height - rahmen.height * s) / 2
            return CGPoint(x: rahmen.minX + (ort.x - dx) / s, y: rahmen.minY + (ort.y - dy) / s)
        }
    }

    /// Alles, was eine Person zum Zeichnen und für Treffer braucht.
    struct Figur: Sendable {
        let bildVorne: Bild
        let bildHinten: Bild

        fileprivate init(_ koerper: MuskelKarteRoh.Koerper?) {
            bildVorne = MuskelPfade.bild(koerper?.front, .vorne)
            bildHinten = MuskelPfade.bild(koerper?.back, .hinten)
        }

        var flaechen: [Flaeche] { bildVorne.flaechen + bildHinten.flaechen }

        /// Vorder- und Rückseite einer Person sind gleich groß, so passt eine Höhe für beide.
        var seitenverhaeltnis: CGFloat { bildVorne.rahmen.width / bildVorne.rahmen.height }

        func bild(hinten: Bool) -> Bild { hinten ? bildHinten : bildVorne }

        /// Die Gruppe an einem Kartenpunkt der Ansicht, oder `nil` (Silhouette, Lücke, neben dem Körper).
        func gruppe(bei p: CGPoint, hinten: Bool) -> MuskelGruppe? {
            bild(hinten: hinten).flaechen.last(where: { $0.pfad.contains(p) })?.gruppe
        }

        /// Welche Seite eine Gruppe zeigt: hinten nur, wenn sie vorne keine Fläche hat.
        func hinten(fuer g: MuskelGruppe) -> Bool {
            !bildVorne.flaechen.contains(where: { $0.gruppe == g })
        }
    }

    static let ahmed = Figur(karte?.male)
    static let annika = Figur(karte?.female)

    static func figur(_ p: Person) -> Figur { p == .annika ? annika : ahmed }

    /// Muskel der Quelle zu Lovea-Gruppe. Lovea führt "Trapez" unter Rücken (`rTrapezOben`), "Kopfwender" und
    /// "Schulterblattheber" unter Nacken. Darum: hinten ist der große Trapez ein Rückenmuskel, vorne ist der
    /// Trapez am Hals der sichtbare Nacken. Das ist ein Kompromiss der Anzeige, die Quelle trennt beides nicht.
    /// Bauch fasst die ganze Rumpfmitte (gerade, schräg, Sägemuskel, Hüftbeuger), Beine alles ab dem Gesäß.
    static func gruppe(slug: String, hinten: Bool) -> MuskelGruppe? {
        switch slug {
        case "trapezius":
            return hinten ? .ruecken : .nacken
        case "deltoids":
            return .schulter
        case "chest":
            return .brust
        case "upper-back", "lower-back":
            return .ruecken
        case "biceps":
            return .bizeps
        case "triceps":
            return .trizeps
        case "forearm":
            return .unterarme
        case "abs", "obliques", "serratus", "hip-flexors":
            return .bauch
        case "gluteal", "quadriceps", "hamstring", "adductors", "calves", "tibialis":
            return .beine
        default:
            return nil
        }
    }

    // MARK: Laden

    fileprivate static func bild(_ ansicht: MuskelKarteRoh.Ansicht?, _ seite: Seite) -> Bild {
        // Fehlt die Datei, bleibt die Figur leer statt abzustürzen; der Test prüft, dass sie da ist.
        guard let ansicht, ansicht.vb.count == 4 else {
            return Bild(rahmen: CGRect(x: 0, y: 0, width: 727, height: 1280), still: [], flaechen: [])
        }
        let rahmen = CGRect(x: ansicht.vb[0], y: ansicht.vb[1], width: ansicht.vb[2], height: ansicht.vb[3])
        let still = ansicht.still.flatMap { teil in
            teil.d.map { Still(haar: teil.slug == "hair", pfad: MuskelPfade.pfad($0)) }
        }
        let flaechen = ansicht.muskeln.flatMap { teil -> [Flaeche] in
            guard let gruppe = MuskelPfade.gruppe(slug: teil.slug, hinten: seite == .hinten) else { return [] }
            return teil.d.map { Flaeche(gruppe: gruppe, seite: seite, pfad: MuskelPfade.pfad($0)) }
        }
        return Bild(rahmen: rahmen, still: still, flaechen: flaechen)
    }

    /// `Bundle(for:)` statt `.main`: im XCTest ist `.main` leer.
    private final class Marke {}

    private static let karte: MuskelKarteRoh? = {
        let bundle = Bundle(for: Marke.self)
        guard let url = bundle.url(forResource: "muskelkarte", withExtension: "json")
                ?? bundle.url(forResource: "muskelkarte", withExtension: "json", subdirectory: "Health/Koerper"),
              let daten = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MuskelKarteRoh.self, from: daten)
    }()

    /// Ein normalisierter Pfad ("M x y L x y C x1 y1 x2 y2 x y Z", jeder Befehl mit Buchstabe, durch Leerzeichen
    /// getrennt) zu einem `Path`. Das erzeugt `tools/muskelkarte-bauen.mjs`.
    static func pfad(_ text: String) -> Path {
        let t = text.split(separator: " ")
        var p = Path()
        var i = 0
        func zahl() -> CGFloat {
            guard i < t.count else { return 0 }
            defer { i += 1 }
            return CGFloat(Double(t[i]) ?? 0)
        }
        while i < t.count {
            let befehl = t[i]
            i += 1
            switch befehl {
            case "M":
                p.move(to: CGPoint(x: zahl(), y: zahl()))
            case "L":
                p.addLine(to: CGPoint(x: zahl(), y: zahl()))
            case "C":
                let c1 = CGPoint(x: zahl(), y: zahl())
                let c2 = CGPoint(x: zahl(), y: zahl())
                let ende = CGPoint(x: zahl(), y: zahl())
                p.addCurve(to: ende, control1: c1, control2: c2)
            case "Z":
                p.closeSubpath()
            default:
                break
            }
        }
        return p
    }
}

/// Die JSON-Datei, so wie sie vorliegt: je Körper und Seite der Kartenrahmen `vb` (x, y, Breite, Höhe),
/// die Silhouette und die Muskeln in Zeichenreihenfolge, jeweils mit ihren Pfaden.
fileprivate struct MuskelKarteRoh: Decodable, Sendable {
    struct Teil: Decodable, Sendable {
        let slug: String
        let d: [String]
    }

    struct Ansicht: Decodable, Sendable {
        let vb: [Double]
        let still: [Teil]
        let muskeln: [Teil]
    }

    struct Koerper: Decodable, Sendable {
        let front: Ansicht
        let back: Ansicht
    }

    let male: Koerper
    let female: Koerper
}
