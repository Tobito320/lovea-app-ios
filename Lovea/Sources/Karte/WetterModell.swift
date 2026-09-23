import Foundation
import SwiftUI

/// Z-27.5: weather at each person's location, via Open-Meteo (free, no key) from the own device,
/// using `Standort.positionen`. `partner` stays the entry point for widgets (H), chat and profile;
/// Z-41.1 adds the own weather so both figures on the map wear what fits their sky.
@MainActor @Observable
final class WetterModell {
    static let shared = WetterModell()

    /// `code` (WMO) and `tag` (Open-Meteo `is_day`) drive the map figure's extras (Z-41.1). Optional
    /// with defaults so `Stand(symbol:temperatur:)` keeps working for every other caller.
    struct Stand: Codable, Sendable, Equatable {
        let symbol: String
        let temperatur: Double
        var code: Int? = nil
        var tag: Bool? = nil
    }

    private(set) var staende: [Person: Stand] = [:]
    private var letzteAbfrage: [Person: Date] = [:]

    var partner: Stand? { Raum.shared.ich.flatMap { staende[$0.partner] } }

    private init() {
        Task { @MainActor [weak self] in
            while let self {
                await self.aktualisieren()
                try? await Task.sleep(for: .seconds(300)) // pollt Standort öfter, ruft Open-Meteo aber höchstens alle 30 min
            }
        }
    }

    /// At most one Open-Meteo call per person every 30 min. The map and the profile preview call this
    /// on appear, so the first weather doesn't wait for the next 5-minute poll.
    func aktualisieren() async {
        for person in Person.allCases {
            guard let pos = Standort.shared.positionen[person] else { continue }
            if let letzte = letzteAbfrage[person], Date().timeIntervalSince(letzte) < 1800 { continue }
            letzteAbfrage[person] = Date()
            if let stand = await Self.laden(lat: pos.lat, lon: pos.lon) { staende[person] = stand }
        }
    }

    private static func laden(lat: Double, lon: Double) async -> Stand? {
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,is_day") else { return nil }
        guard let (daten, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let jetzt = try? JSONDecoder().decode(OpenMeteoAntwort.self, from: daten).current else { return nil }
        return Stand(symbol: WetterSymbol.sfSymbol(fuer: jetzt.weatherCode), temperatur: jetzt.temperature2m, code: jetzt.weatherCode, tag: jetzt.isDay.map { $0 == 1 })
    }
}

private struct OpenMeteoAntwort: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int
        let isDay: Int?
        enum CodingKeys: String, CodingKey { case temperature2m = "temperature_2m"; case weatherCode = "weather_code"; case isDay = "is_day" }
    }
    let current: Current
}

/// WMO weather code (Open-Meteo `weather_code`) -> SF Symbol. Pure, testable.
enum WetterSymbol {
    static func sfSymbol(fuer code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}

/// Reusable small weather chip (chat header, map pin — Profil v3 kommt in Block 25/F dazu).
struct WetterChip: View {
    let stand: WetterModell.Stand

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: stand.symbol)
            Text("\(Int(stand.temperatur.rounded()))°")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(stand.temperatur.rounded())) Grad")
    }
}
