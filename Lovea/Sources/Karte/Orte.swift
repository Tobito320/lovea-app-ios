import CoreLocation
import Foundation

/// A saved place, folded from `ort.setzen`/`ort.loeschen` (schnittstellen.md). `kategorie` uses
/// the same raw values as `FigurZustand` (`zuhause`, `gym`, `schule`, `arbeit`, `fahrschule`,
/// `supermarkt`) plus `"sonstiges"`, so Block 7 can map a place straight to a figure state.
struct Ort: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var person: Person
    var name: String
    var kategorie: String
    var lat: Double
    var lon: Double
    var radius: Double
    var melden: String // "ankunft" | "verlassen" | "beides" | "nichts"
}

/// One CLVisit, normalized (no `.distantPast`/`.distantFuture` sentinels) and persisted locally.
struct Besuch: Codable, Sendable, Equatable {
    let lat: Double
    let lon: Double
    let ankunft: Date
    let verlassen: Date?
}

/// A candidate place `OrteModell` can offer to save. Purely geometric - naming and "Zuhause"
/// happen afterwards (POI lookup, night count) since those aren't pure.
struct OrtVorschlag: Sendable, Equatable {
    let lat: Double
    let lon: Double
    let tage: Int
    let naechte: Int
}

enum Orte {
    static let clusterRadius: CLLocationDistance = 150
    private static let fenster: TimeInterval = 14 * 86_400

    /// Z-8.4: mindestens 3 verschiedene Tage in 14 Tagen im Umkreis von 150 m ergibt einen
    /// Vorschlag. `jetzt` ist der Bezug für die 14 Tage - im Betrieb der Default, in Tests explizit.
    static func vorschlaege(besuche: [Besuch], gespeichert: [Ort], jetzt: Date = Date()) -> [OrtVorschlag] {
        let grenze = jetzt.addingTimeInterval(-fenster)
        let kandidaten = besuche
            .filter { $0.ankunft >= grenze }
            .filter { besuch in !gespeichert.contains { istIn($0, besuch) } }

        // ponytail: greedy single-link clustering in visit order - simple and deterministic for
        // well-separated places, order-dependent if two clusters overlap. Upgrade to a proper
        // geo-clustering pass (e.g. DBSCAN) if that turns out to matter in practice.
        var cluster: [[Besuch]] = []
        for besuch in kandidaten {
            if let i = cluster.firstIndex(where: { nah(besuch, $0) }) {
                cluster[i].append(besuch)
            } else {
                cluster.append([besuch])
            }
        }

        return cluster.compactMap { gruppe in
            let tage = Set(gruppe.map { Calendar.berlin.startOfDay(for: $0.ankunft) })
            guard tage.count >= 3 else { return nil }
            let mitte = zentrum(gruppe)
            return OrtVorschlag(lat: mitte.lat, lon: mitte.lon, tage: tage.count, naechte: gruppe.filter(istNachtBesuch).count)
        }
    }

    private static func istIn(_ ort: Ort, _ besuch: Besuch) -> Bool {
        distanz(ort.lat, ort.lon, besuch.lat, besuch.lon) <= ort.radius
    }

    private static func nah(_ besuch: Besuch, _ gruppe: [Besuch]) -> Bool {
        let mitte = zentrum(gruppe)
        return distanz(mitte.lat, mitte.lon, besuch.lat, besuch.lon) <= clusterRadius
    }

    private static func zentrum(_ gruppe: [Besuch]) -> (lat: Double, lon: Double) {
        (gruppe.map(\.lat).reduce(0, +) / Double(gruppe.count), gruppe.map(\.lon).reduce(0, +) / Double(gruppe.count))
    }

    private static func distanz(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> CLLocationDistance {
        CLLocation(latitude: lat1, longitude: lon1).distance(from: CLLocation(latitude: lat2, longitude: lon2))
    }

    /// True if the stay overlaps the Berlin night window (22-6 Uhr) at any point, not just if
    /// it started at night - arriving home at 18:00 and sleeping over still counts.
    private static func istNachtBesuch(_ b: Besuch) -> Bool {
        let ende = min(b.verlassen ?? b.ankunft.addingTimeInterval(3600), b.ankunft.addingTimeInterval(48 * 3600))
        var t = b.ankunft
        var schritte = 0
        while t < ende, schritte < 48 {
            let stunde = Calendar.berlin.component(.hour, from: t)
            if stunde >= 22 || stunde < 6 { return true }
            t = t.addingTimeInterval(3600)
            schritte += 1
        }
        return false
    }
}
