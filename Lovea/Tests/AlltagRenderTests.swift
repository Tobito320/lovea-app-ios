import SwiftUI
import XCTest
@testable import Lovea

/// p64: der Paar-Alltag als Standbilder: die fünf Dinge einzeln und das gemeinsame Zimmer leer, belegt,
/// mit Wärme-Set und zusammen mit den Paar-Signalen (p60/p61), damit man Überdeckungen sieht.
@MainActor
final class AlltagRenderTests: XCTestCase {
    private let heute = "2026-10-08"
    private let lied = "4cOdK2wGLETKBW3PvgPWqT"
    private var abend: Date { Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 21))! }

    /// Fertige Ops wie vom Server: Ahmed hat Platte, Wecker, Outfit und Zettel gesetzt, Annika einen Zettel.
    private func belegt() -> [Op] {
        [
            Op.neu(AlltagLogik.artPlatte, AlltagLogik.PlatteD(id: lied, titel: "Perfect", kuenstler: "Ed Sheeran", cover: nil), von: .ahmed),
            Op.neu(AlltagLogik.artWecker, AlltagLogik.WeckerD(min: 6 * 60 + 30, an: true), von: .ahmed),
            Op.neu(AlltagLogik.artWecker, AlltagLogik.WeckerD(min: 7 * 60 + 15, an: true), von: .annika),
            Op.neu(AlltagLogik.artSpiegel, AlltagLogik.SpiegelD(medium: "m-outfit", tag: heute), von: .ahmed),
            Op.neu(AlltagLogik.artZettel, AlltagLogik.ZettelD(id: "z1", text: "Milch", erledigt: false, link: nil, notiz: nil, bild: nil), von: .ahmed),
            Op.neu(AlltagLogik.artZettel, AlltagLogik.ZettelD(id: "z2", text: "Reis", erledigt: true, link: nil, notiz: nil, bild: nil), von: .annika),
            Op.neu(AlltagLogik.artZettel, AlltagLogik.ZettelD(id: "z3", text: "Pfannkuchen", erledigt: false, link: "https://www.tiktok.com/@x/video/1", notiz: "mit Beeren", bild: nil), von: .annika),
        ]
    }

    private func waerme() -> [Op] {
        [Op.neu(AlltagLogik.artWaerme, AlltagLogik.WaermeD(tag: heute, an: true), von: .annika)]
    }

    private func zimmer(_ zeit: Tageszeit, nacht: Bool = false, ich: Person = .annika, ops: [Op] = [], signale: Bool = false) -> AnyView {
        let speicher = AlltagSpeicher(ich: { ich }, senden: { _ in })
        speicher.einarbeiten(ops)
        let stand = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: 0))
        let szene = ZuhauseBuehne(nacht: nacht, fest: stand) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
        } paar: {
            EmptyView()
        }
        let alltag = AlltagEbene(speicher: speicher, heute: heute)
        let signaleEbene = PaarSignaleEbene(blatt: .constant(nil), speicher: SignaleSpeicher(ich: { ich }, senden: { _ in }),
                                            briefe: BriefeSpeicher(ich: { ich }, senden: { _ in }), gruesse: [:], jetzt: abend)
        return AnyView(ZStack { szene; if signale { signaleEbene }; alltag }.frame(width: 390, height: 430).clipped())
    }

    private func bild(_ raster: CGSize, breite: CGFloat, _ zeichne: @escaping (GraphicsContext) -> Void) -> some View {
        SignaleBild(raster: raster, zeichne: zeichne).frame(width: breite, height: breite * raster.height / raster.width)
    }

    func testAlltagBrett() {
        let dinge = AnyView(HStack(spacing: 10) {
            bild(AlltagZeichnung.platteRaster, breite: 90) { AlltagZeichnung.plattenspieler($0, winkel: 0, bespielt: false) }
            bild(AlltagZeichnung.platteRaster, breite: 90) { AlltagZeichnung.plattenspieler($0, winkel: 1, bespielt: true) }
            bild(AlltagZeichnung.waermeRaster, breite: 80, AlltagZeichnung.waermeSet)
        })
        let moebel = AnyView(HStack(spacing: 10) {
            bild(AlltagZeichnung.nachttischRaster, breite: 60) { AlltagZeichnung.nachttisch($0, gestellt: false) }
            bild(AlltagZeichnung.nachttischRaster, breite: 60) { AlltagZeichnung.nachttisch($0, gestellt: true) }
            bild(AlltagZeichnung.kuehlRaster, breite: 50) { AlltagZeichnung.kuehlschrank($0, zettel: 0) }
            bild(AlltagZeichnung.kuehlRaster, breite: 50) { AlltagZeichnung.kuehlschrank($0, zettel: 3) }
            bild(AlltagZeichnung.spiegelRaster, breite: 56) { AlltagZeichnung.spiegel($0, haengt: false) }
            bild(AlltagZeichnung.spiegelRaster, breite: 56) { AlltagZeichnung.spiegel($0, haengt: true) }
        })

        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Plattenspieler leer, mit Platte gedreht, Tee und Wärmflasche", ansicht: dinge),
            (titel: "Nachttisch aus und mit Wecker, Kühlschrank leer und mit Zetteln, Spiegel leer und mit Outfit", ansicht: moebel),
            (titel: "Zimmer Mittag, noch nichts gesetzt", ansicht: zimmer(.tag)),
            (titel: "Annika: Platte, Ahmeds Wecker, sein Outfit, Zettel", ansicht: zimmer(.tag, ops: belegt())),
            (titel: "Ahmed: Annikas Wecker, kein Outfit von ihr, Zettel", ansicht: zimmer(.tag, ich: .ahmed, ops: belegt())),
            (titel: "Schwerer Tag: Tee, Wärmflasche und etwas Süßes", ansicht: zimmer(.abend, ops: belegt() + waerme())),
            (titel: "Mit Paar-Signalen zusammen, Überdeckung prüfen", ansicht: zimmer(.abend, ops: belegt() + waerme(), signale: true)),
            (titel: "Nacht", ansicht: zimmer(.nacht, nacht: true, ops: belegt())),
        ]
        RenderTafel.speichern("p64-alltag", spalten: 2, zellen: zellen)
    }
}
