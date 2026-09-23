import Foundation
import SwiftUI

/// Z-27.5: weather at the partner's location, via Open-Meteo (free, no key) from the own device,
/// using `Standort.positionen[partner]`. Exposed as `WetterModell.shared.partner` for widgets (H).
@MainActor @Observable
final class WetterModell {
    static let shared = WetterModell()

    struct Stand: Codable, Sendable, Equatable { let symbol: String; let temperatur: Double }

    private(set) var partner: Stand?
    private var letzteAbfrage: Date?

    private init() {
        Task { @MainActor [weak self] in
            while let self {
                await self.aktualisierenFallsFaellig()
                try? await Task.sleep(for: .seconds(300)) // pollt Standort öfter, ruft Open-Meteo aber höchstens alle 30 min
            }
        }
    }

    private func aktualisierenFallsFaellig() async {
        guard let partnerPerson = Raum.shared.ich?.partner, let pos = Standort.shared.positionen[partnerPerson] else { return }
        if let letzte = letzteAbfrage, Date().timeIntervalSince(letzte) < 1800 { return }
        letzteAbfrage = Date()
        guard let stand = await Self.laden(lat: pos.lat, lon: pos.lon) else { return }
        partner = stand
    }

    private static func laden(lat: Double, lon: Double) async -> Stand? {
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code") else { return nil }
        guard let (daten, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let antwort = try? JSONDecoder().decode(OpenMeteoAntwort.self, from: daten) else { return nil }
        return Stand(symbol: WetterSymbol.sfSymbol(fuer: antwort.current.weatherCode), temperatur: antwort.current.temperature2m)
    }
}

private struct OpenMeteoAntwort: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int
        enum CodingKeys: String, CodingKey { case temperature2m = "temperature_2m"; case weatherCode = "weather_code" }
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
