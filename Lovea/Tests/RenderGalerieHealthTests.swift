import SwiftUI
import XCTest
@testable import Lovea

/// Render boards for Blocks 35/36 (common.md): habit tiles light and dark, rings, week chart,
/// month mini-ring calendar and the points chip. Pure views with fixed data, no singletons' state.
@MainActor
final class RenderGalerieHealthTests: XCTestCase {
    private let heute = "2026-09-23" // Mittwoch

    private func zelle(_ titel: String, _ ansicht: some View, _ schema: ColorScheme = .light) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.padding(12).background(Color(uiColor: .systemBackground)).environment(\.colorScheme, schema)))
    }

    private func werte(_ tage: [String], _ wert: Int = 1) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: tage.map { ($0, wert) })
    }

    func testHabitKacheln() {
        let gymWoche = werte(["2026-09-07", "2026-09-09", "2026-09-11", "2026-09-14", "2026-09-16", "2026-09-18", "2026-09-21", "2026-09-22"])
        var gymHeute = gymWoche
        gymHeute[heute] = 1
        let wasser = ["2026-09-21": 8, "2026-09-22": 6, heute: 5]
        let lesen = Habit(id: "h-lesen", name: "Lesen", symbol: "book.fill", farbe: HabitFarbe.indigo.rawValue, zaehlen: false, tagesziel: nil, haeufigkeit: .tage([1, 3, 5]), fuer: "beide")
        var zellen: [(titel: String, ansicht: AnyView)] = []
        for schema in [ColorScheme.light, .dark] {
            let name = schema == .light ? "hell" : "dunkel"
            zellen.append(zelle("Gym erledigt, \(name)", kachel(.gym, ziel: 3, gymHeute, partner: .annika), schema))
            zellen.append(zelle("Gym offen, \(name)", kachel(.gym, ziel: 3, gymWoche), schema))
            zellen.append(zelle("Wasser 5/8, \(name)", kachel(.wasser, ziel: 8, wasser), schema))
            zellen.append(zelle("Lesen Mo/Mi/Fr, \(name)", kachel(lesen, ziel: nil, werte(["2026-09-18", "2026-09-21", heute])), schema))
        }
        RenderTafel.speichern("health-habit-kacheln", spalten: 4, zellen: zellen)
    }

    private func kachel(_ habit: Habit, ziel: Int?, _ werte: [String: Int], partner: Person? = nil) -> some View {
        HabitKachel(habit: habit, ziel: ziel, werte: werte, heute: heute, partner: partner).frame(width: 172, height: 172)
    }

    func testRingeUndPunkte() {
        RenderTafel.speichern("health-ringe", spalten: 4, zellen: [
            zelle("Ahmed 8.596", SchritteSpalte(person: .ahmed, anzahl: 8596, ziel: 10_000, km: 6.12, etagen: 7)),
            zelle("Annika 14.210 (2. Runde)", SchritteSpalte(person: .annika, anzahl: 14_210, ziel: 10_000, km: 10.4, etagen: 12)),
            zelle("Keine Daten, dunkel", SchritteSpalte(person: .ahmed, anzahl: nil, ziel: 10_000, km: nil, etagen: nil), .dark),
            zelle("Punkte-Chip", VStack(spacing: 12) { PunkteKapsel(punkte: 12_480); LoveaMuenze(groesse: 64) }),
        ])
    }

    func testWocheUndMonat() {
        let tage = HabitLogik.wochenTage(heute: heute)
        let ahmed = [8596, 12_040, 6100, nil, nil, nil, nil]
        let annika = [9020, 7400, 11_800, nil, nil, nil, nil]
        let balken = tage.enumerated().flatMap { i, tag in
            [SchrittBalken(tag: tag, person: .ahmed, anzahl: ahmed[i]), SchrittBalken(tag: tag, person: .annika, anzahl: annika[i])]
        }
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: 0)
        let monat = LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 4), count: 7), spacing: 8) {
            ForEach(Array(gitter.enumerated()), id: \.offset) { i, tag in
                if let tag, tag <= self.heute {
                    MiniRing(anteil: tag == "2026-09-10" ? nil : Double((i * 37) % 13) / 10, farbe: Color.person(.ahmed), tag: tag)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
        }
        RenderTafel.speichern("health-woche-monat", spalten: 2, zellen: [
            zelle("Woche", SchritteWocheChart(balken: balken, auswahl: .constant(nil)).frame(width: 340)),
            zelle("Woche, Mi gewählt, dunkel", SchritteWocheChart(balken: balken, auswahl: .constant("Mi")).frame(width: 340), .dark),
            zelle("Monat mit Mini-Ringen", monat),
            zelle("Gym-Monat", HabitMonat(habit: .gym, werte: werte(["2026-09-01", "2026-09-03", "2026-09-08", "2026-09-21", heute]), ziel: 3, heute: heute, monateZurueck: 0).frame(width: 300)),
        ])
    }
}
