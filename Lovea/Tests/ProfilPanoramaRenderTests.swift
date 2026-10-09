import SwiftUI
import XCTest
@testable import Lovea

/// p65 A2: the profile scene as the panorama, as still pictures. `ImageRenderer` cannot draw a scroll view, so
/// each cell stacks the same layers the app scrolls (`ProfilWandSchicht`, the world in `.panorama`) at a fixed
/// scroll offset, the wall pushed back by `ProfilPanoramaLayout.wandVersatz` like the parallax does.
@MainActor
final class ProfilPanoramaRenderTests: XCTestCase {
    private let heute = "2026-10-08"
    private let lied = "4cOdK2wGLETKBW3PvgPWqT"
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var abend: Date { Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 21))! }

    private var zimmer: Zimmer { Zimmer(rahmen: (0..<3).map { Zimmer.Rahmen(slot: $0, medienId: "rahmen-\($0)") }) }

    private func lebenStand(nacht: Bool) -> ZimmerLebenStand {
        ZimmerLebenStand(
            termin: ZimmerTermin(titel: "Kino", tag: "2026-10-14", uhrzeit: "19:30"),
            himmel: ZimmerHimmel(wetter: .wolken, nacht: nacht), andere: .zuhause,
            polaroids: (0..<3).map { ZimmerPolaroid(id: "p\($0)", medienId: "snap-\($0)", zeit: t0.addingTimeInterval(Double(-$0) * 60)) },
            pokale: [ZimmerPokal(art: .xo, ahmed: 7, annika: 3), ZimmerPokal(art: .memory, ahmed: 2, annika: 6)],
            film: ZimmerFilm(id: "f", titel: "Up", serie: false, gesehen: false),
            pflanze: ZimmerPflanzenStand(stufe: 3, haengt: false, serie: 9),
            ziel: ZimmerZiel(titel: "Rom", koffer: false, ziel: 500, gespart: 350))
    }

    /// The whole 975-unit world with every layer the profile puts on it, filled like a lived-in home.
    private func welt(_ zeit: Tageszeit, schritt: Int, hoehe: CGFloat, k: CGFloat) -> some View {
        let zimmer = zimmer
        let stand = lebenStand(nacht: zeit == .nacht)
        let fest = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: schritt), mitGeste: true)
        let ich = Person.ahmed
        let alltag = AlltagSpeicher(ich: { ich }, senden: { _ in })
        alltag.einarbeiten([
            Op.neu(AlltagLogik.artPlatte, AlltagLogik.PlatteD(id: lied, titel: "Perfect", kuenstler: "Ed Sheeran", cover: nil), von: .ahmed),
            Op.neu(AlltagLogik.artWecker, AlltagLogik.WeckerD(min: 6 * 60 + 30, an: true), von: .ahmed),
            Op.neu(AlltagLogik.artZettel, AlltagLogik.ZettelD(id: "z1", text: "Milch", erledigt: false, link: nil, notiz: nil, bild: nil), von: .ahmed),
        ])
        let szene = ZuhauseBuehne(straeusse: ZuhauseStraeusse(schrank: ["rosen", "tulpen"], vase: "sonnenblumen"), nacht: zeit == .nacht,
                                  fest: fest, welt: .panorama,
                                  wandDinge: { z in AnyView(ZimmerLebenBild(zimmer: zimmer, person: ich, nacht: z.dunkel, stand: stand, welt: .panorama)) }) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper, pose: f.pose)
        } paar: {
            EmptyView()
        }
        return szene
            .overlay { ZimmerLebenTippen(zimmer: zimmer, person: ich, stand: stand, welt: .panorama) }
            .overlay { PaarSignaleEbene(blatt: .constant(nil), speicher: SignaleSpeicher(ich: { ich }, senden: { _ in }),
                                        briefe: BriefeSpeicher(ich: { ich }, senden: { _ in }), gruesse: [:], jetzt: abend, welt: .panorama) }
            .overlay { AlltagEbene(speicher: alltag, heute: heute, pruefen: false, welt: .panorama) }
            .frame(width: ProfilSlots.weltBreite * k, height: hoehe)
    }

    /// What the phone shows at `scroll` design units: the wall at 60 % of the world's speed, the world at full.
    /// `oben` is the status bar the wall bleeds into.
    private func ansicht(breite: CGFloat, oben: CGFloat = 0, scroll: CGFloat, _ zeit: Tageszeit = .tag, schritt: Int = 0) -> AnyView {
        let k = ProfilPanoramaLayout.massstab(breite: breite)
        let hoehe = oben + ProfilPanoramaLayout.szeneHoehe(breite: breite)
        return AnyView(
            ZStack(alignment: .topLeading) {
                ProfilWandSchicht(wahl: .standard, k: k, hoehe: hoehe)
                    .offset(x: (-scroll + ProfilPanoramaLayout.wandVersatz(scroll: scroll)) * k)
                welt(zeit, schritt: schritt, hoehe: hoehe, k: k)
                    .offset(x: -scroll * k)
            }
            .frame(width: breite, height: hoehe, alignment: .topLeading)
            .background(FigurFarbe(ZimmerWahl.standard.teil(.wand).farbe).farbe)
            .clipped()
        )
    }

    func testPanoramaGanzeWelt() {
        // The whole world flat, wall not scrolled: nothing sits over anything else.
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Mittag: ganze Welt, Sofa, Platte und Bilder getrennt", ansicht: ansicht(breite: ProfilSlots.weltBreite, scroll: 0)),
            (titel: "Nacht: ganze Welt, beide schlafen", ansicht: ansicht(breite: ProfilSlots.weltBreite, scroll: 0, .nacht)),
        ]
        RenderTafel.speichern("p65-panorama-welt", spalten: 1, zellen: zellen)
    }

    func testPanoramaZonen() {
        let schlaf = ProfilSlots.anker(.schlaf), wohn = ProfilSlots.anker(.wohn), regal = ProfilSlots.anker(.regal)
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Schlaf: Bett, Fenster, Nachttisch", ansicht: ansicht(breite: 390, scroll: schlaf)),
            (titel: "Wohn: Sofa, beide sitzen, Fernseher", ansicht: ansicht(breite: 390, scroll: wohn)),
            (titel: "Regal: Spiegel, Regal, Pokale", ansicht: ansicht(breite: 390, scroll: regal)),
            (titel: "Wohn mit Statusleiste (iPhone mit Notch), 393 pt", ansicht: ansicht(breite: 393, oben: 59, scroll: wohn)),
            (titel: "Mitten im Wischen: Wand langsamer als die Möbel", ansicht: ansicht(breite: 390, scroll: 150)),
            (titel: "Abend: beide im Bett", ansicht: ansicht(breite: 390, scroll: schlaf, .abend)),
            (titel: "Nacht: beide schlafen", ansicht: ansicht(breite: 390, scroll: schlaf, .nacht)),
            (titel: "Kleines Handy 375 pt, Wohn", ansicht: ansicht(breite: 375, oben: 20, scroll: wohn)),
            (titel: "Breites Handy 430 pt, Wohn", ansicht: ansicht(breite: 430, oben: 59, scroll: wohn)),
        ]
        RenderTafel.speichern("p65-panorama-zonen", spalten: 3, zellen: zellen)
    }
}
