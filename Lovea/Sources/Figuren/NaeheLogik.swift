import Foundation

/// Teil 2 (Nähe): how close the pair is drawn. Pure logic, the views read it.
enum NaeheLogik {
    /// Messages of both in the last 2 hours: 0-5 = 0, 6-20 = 1, 21-50 = 2, more = 3.
    static func stufe(nachrichten: [Date], jetzt: Date) -> Int {
        let grenze = jetzt.addingTimeInterval(-2 * 60 * 60)
        let anzahl = nachrichten.filter { $0 > grenze && $0 <= jetzt }.count
        switch anzahl {
        case ...5: return 0
        case ...20: return 1
        case ...50: return 2
        default: return 3
        }
    }

    /// Together = same saved place, or less than 100 m apart.
    static func zusammen(a: (lat: Double, lon: Double)?, b: (lat: Double, lon: Double)?, ortA: String?, ortB: String?) -> Bool {
        if let ortA, let ortB, ortA == ortB { return true }
        guard let a, let b else { return false }
        return abstandMeter(a, b) < 100
    }

    /// Haversine distance in metres.
    static func abstandMeter(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let r = 6_371_000.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}

@MainActor
extension NaeheLogik {
    /// Current level from the chat: user messages only (system notices do not count).
    static var aktuelleStufe: Int {
        let zeiten = ChatModell.shared.nachrichten.filter { $0.system == nil }.map(\.zeit)
        return stufe(nachrichten: zeiten, jetzt: Date())
    }

    /// Whether Ahmed and Annika are together right now.
    static var sindZusammen: Bool {
        let pos = Standort.shared.positionen
        let a = pos[.ahmed].map { (lat: $0.lat, lon: $0.lon) }
        let n = pos[.annika].map { (lat: $0.lat, lon: $0.lon) }
        let ortA = a.flatMap { OrteModell.shared.aktuellerOrt(.ahmed, lat: $0.lat, lon: $0.lon)?.name }
        let ortN = n.flatMap { OrteModell.shared.aktuellerOrt(.annika, lat: $0.lat, lon: $0.lon)?.name }
        return zusammen(a: a, b: n, ortA: ortA, ortB: ortN)
    }
}
