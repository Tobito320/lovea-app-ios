import SwiftUI
import XCTest
@testable import Lovea

/// p62: the home with its living objects in many states: weather, plant stages, goal, cups, TV,
/// calendar, board, frames and where the other one is. The stage runs fixed (no driver), so every
/// cell is one still picture; `render-galerie/p60-zimmer.png` is the CI artifact.
@MainActor
final class ZimmerLebenRenderTests: XCTestCase {
    private func raum(_ titel: String, _ zeit: Tageszeit, rahmen: Int = 0, _ stand: ZimmerLebenStand) -> (titel: String, ansicht: AnyView) {
        let zimmer = Zimmer(rahmen: (0..<rahmen).map { Zimmer.Rahmen(slot: $0, medienId: "rahmen-\($0)") })
        let fest = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: 0))
        let szene = ZuhauseBuehne(fest: fest, wandDinge: { z in
            AnyView(ZimmerLebenBild(zimmer: zimmer, person: .ahmed, nacht: z.dunkel, stand: stand))
        }) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
        } paar: {
            EmptyView()
        }
        .overlay { ZimmerLebenTippen(zimmer: zimmer, person: .ahmed, stand: stand) }
        return (titel: titel, ansicht: AnyView(szene.frame(width: 390, height: 430).clipped()))
    }

    private let termin = ZimmerTermin(titel: "Kino", tag: "2026-10-14", uhrzeit: "19:30")
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func polaroids(_ n: Int) -> [ZimmerPolaroid] {
        (0..<n).map { ZimmerPolaroid(id: "p\($0)", medienId: "snap-\($0)", zeit: t0.addingTimeInterval(Double(-$0) * 60)) }
    }

    private func pokale(_ n: Int, gold: Bool = false) -> [ZimmerPokal] {
        let alle = [ZimmerPokal(art: .xo, ahmed: gold ? 20 : 7, annika: 3), ZimmerPokal(art: .memory, ahmed: 2, annika: 6), ZimmerPokal(art: .ssp, ahmed: 1, annika: 0)]
        return Array(alle.prefix(n))
    }

    func testZimmerBrett() {
        let zellen: [(titel: String, ansicht: AnyView)] = [
            raum("Sonne: alles voll, Glas 70 %, Pflanze blüht", .tag, rahmen: 3, ZimmerLebenStand(
                termin: termin, himmel: ZimmerHimmel(wetter: .sonne, nacht: false), andere: .zuhause, polaroids: polaroids(3), pokale: pokale(3),
                film: ZimmerFilm(id: "f", titel: "Up", serie: false, gesehen: false), pflanze: ZimmerPflanzenStand(stufe: 4, haengt: false, serie: 20),
                ziel: ZimmerZiel(titel: "Rom", koffer: false, ziel: 500, gespart: 350))),
            raum("Wolken: Serie, Koffer 30 %, beim Sport", .tag, rahmen: 1, ZimmerLebenStand(
                termin: termin, himmel: ZimmerHimmel(wetter: .wolken, nacht: false), andere: .sport, polaroids: polaroids(1), pokale: pokale(2),
                film: ZimmerFilm(id: "f", titel: "Dark", serie: true, gesehen: false), pflanze: ZimmerPflanzenStand(stufe: 2, haengt: false, serie: 4),
                ziel: ZimmerZiel(titel: "Rom", koffer: true, ziel: 500, gespart: 150))),
            raum("Regen am Abend: Pflanze hängt, alles leer, im Bett", .abend, ZimmerLebenStand(
                himmel: ZimmerHimmel(wetter: .regen, nacht: false), andere: .bett, pflanze: ZimmerPflanzenStand(stufe: 3, haengt: true, serie: 0))),
            raum("Schnee am Morgen: Setzling, Koffer fertig, Gold", .morgen, rahmen: 2, ZimmerLebenStand(
                termin: termin, himmel: ZimmerHimmel(wetter: .schnee, nacht: false), polaroids: polaroids(2), pokale: pokale(1, gold: true),
                pflanze: ZimmerPflanzenStand(stufe: 0, haengt: false, serie: 0), ziel: ZimmerZiel(titel: "Rom", koffer: true, ziel: 500, gespart: 500))),
            raum("Klare Nacht: Pflanze Stufe 3, Glas fast leer", .nacht, ZimmerLebenStand(
                termin: termin, himmel: ZimmerHimmel(wetter: .sonne, nacht: true), andere: .bett, polaroids: polaroids(3),
                pflanze: ZimmerPflanzenStand(stufe: 3, haengt: false, serie: 9), ziel: ZimmerZiel(titel: "Rom", koffer: false, ziel: 500, gespart: 40))),
            raum("Regennacht: Pflanze Stufe 1, Glas voll", .nacht, ZimmerLebenStand(
                himmel: ZimmerHimmel(wetter: .regen, nacht: true), pflanze: ZimmerPflanzenStand(stufe: 1, haengt: false, serie: 2),
                ziel: ZimmerZiel(titel: "Rom", koffer: false, ziel: 500, gespart: 500))),
            raum("Wolkige Nacht, 3 Rahmen, Fernseher aus", .abend, rahmen: 3, ZimmerLebenStand(
                termin: termin, himmel: ZimmerHimmel(wetter: .wolken, nacht: true), polaroids: polaroids(2), pokale: pokale(3),
                pflanze: ZimmerPflanzenStand(stufe: 2, haengt: false, serie: 5))),
            raum("Ohne Wetterdaten, ohne Ziel (Plus), ohne Termin", .tag, ZimmerLebenStand()),
        ]
        RenderTafel.speichern("p60-zimmer", spalten: 4, zellen: zellen)
    }
}
