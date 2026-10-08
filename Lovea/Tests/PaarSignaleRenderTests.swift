import SwiftUI
import XCTest
@testable import Lovea

/// p60/p61: die Paar-Signale als Standbilder: Blasen, Umschlag, Stapel, Zettel, Box, Schalter, Lampe
/// und das Zimmer im Dunkeln. Die Bühne läuft fest (kein Takt), jede Zelle ist ein Bild.
@MainActor
final class PaarSignaleRenderTests: XCTestCase {
    private func berlin(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        Calendar.berlin.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde, minute: minute))!
    }

    private func gruss(_ nacht: Date) -> (nacht: Date?, morgen: Date?) { (nacht, nil) }

    /// Annikas Briefstapel mit `n` Liebesbriefen von Ahmed, alle noch zu.
    private func post(_ n: Int) -> BriefeSpeicher {
        var ich = Person.ahmed
        let s = BriefeSpeicher(ich: { ich }, senden: { _ in })
        for i in 0..<n {
            s.schreiben(titel: SignaleLogik.liebesbriefTitel, text: "Ich denk an dich \(i)", frei: true)
        }
        ich = .annika
        return s
    }

    private func zimmer(_ zeit: Tageszeit, nacht: Bool = false, uhr: Date, gruesse: NachtLogik.Gruesse = [:], briefe: Int = 0,
                        leuchtet: Bool = false, stimmungen: Bool = false) -> AnyView {
        let speicher = SignaleSpeicher(ich: { .annika }, senden: { _ in })
        if stimmungen {
            speicher.einarbeiten([
                Op.neu(SignaleLogik.artStimmung, SignaleLogik.StimmungD(art: Gefuehl.verliebt.rawValue), von: .annika),
                Op.neu(SignaleLogik.artStimmung, SignaleLogik.StimmungD(art: Gefuehl.muede.rawValue), von: .ahmed),
            ])
        }
        let stand = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: 0))
        let szene = ZuhauseBuehne(nacht: nacht, fest: stand) { f in
            FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
                .overlay(alignment: .top) {
                    if f.zustand != .schlaeft {
                        StimmungBlase(person: f.person, figurHoehe: f.groesse, ganzkoerper: f.ganzkoerper, speicher: speicher) {}
                    }
                }
        } paar: {
            EmptyView()
        }
        let ebene = PaarSignaleEbene(blatt: .constant(nil), speicher: speicher, briefe: post(briefe), gruesse: gruesse, jetzt: uhr, leuchtet: leuchtet)
        return AnyView(ZStack { szene; ebene }.frame(width: 390, height: 430).clipped())
    }

    private func bild(_ raster: CGSize, breite: CGFloat, _ zeichne: @escaping (GraphicsContext) -> Void) -> some View {
        SignaleBild(raster: raster, zeichne: zeichne).frame(width: breite, height: breite * raster.height / raster.width)
    }

    func testSignaleBrett() {
        let blasen = AnyView(HStack(spacing: 8) {
            bild(SignaleZeichnung.blasenRaster, breite: 44) { SignaleZeichnung.blase($0, nil) }
            ForEach(Gefuehl.allCases, id: \.self) { s in
                bild(SignaleZeichnung.blasenRaster, breite: 44) { SignaleZeichnung.blase($0, s) }
            }
        })
        let gesichter = AnyView(HStack(spacing: 8) {
            ForEach(Gefuehl.allCases, id: \.self) { s in
                bild(CGSize(width: 40, height: 40), breite: 56) { SignaleZeichnung.gesicht($0, s) }
            }
        })
        let dinge = AnyView(HStack(spacing: 8) {
            bild(CGSize(width: 40, height: 40), breite: 52, SignaleZeichnung.umschlag)
            bild(CGSize(width: 40, height: 40), breite: 52, SignaleZeichnung.stapel)
            bild(SignaleZeichnung.zettelRaster, breite: 52, SignaleZeichnung.zettel)
            bild(SignaleZeichnung.geschenkRaster, breite: 60, SignaleZeichnung.geschenkBox)
            bild(SignaleZeichnung.schalterRaster, breite: 38) { SignaleZeichnung.schalter($0, an: false) }
            bild(SignaleZeichnung.schalterRaster, breite: 38) { SignaleZeichnung.schalter($0, an: true) }
        })

        let abend = berlin(9, 21)
        let beide = berlin(9, 23)
        let annika: NachtLogik.Gruesse = [.annika: gruss(berlin(9, 20, 55))]
        let beideGedrueckt: NachtLogik.Gruesse = [.annika: gruss(berlin(9, 22, 50)), .ahmed: gruss(berlin(9, 22, 58))]

        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Stimmung: leere Blase mit Plus und sechs Gefühle", ansicht: blasen),
            (titel: "Die sechs Gesichter groß", ansicht: gesichter),
            (titel: "Umschlag, Stapel, Zettel, Box, Schalter aus und an", ansicht: dinge),
            (titel: "Mittag: Blasen über beiden, ein Brief", ansicht: zimmer(.tag, uhr: berlin(9, 13), briefe: 1, stimmungen: true)),
            (titel: "Abend: zwei Briefe, Stapel, Zettel, Box, Schalter", ansicht: zimmer(.abend, uhr: abend, briefe: 2)),
            (titel: "Annika drückt Gute Nacht, wartet auf Ahmed", ansicht: zimmer(.abend, uhr: abend, gruesse: annika)),
            (titel: "Beide gedrückt: Licht aus, Sterne", ansicht: zimmer(.nacht, nacht: true, uhr: beide, gruesse: beideGedrueckt)),
            (titel: "Ich-denk-an-dich: die Lampe leuchtet kurz", ansicht: zimmer(.abend, uhr: abend, leuchtet: true)),
            (titel: "Morgen: kein Brief, kein Schalter", ansicht: zimmer(.morgen, uhr: berlin(10, 8))),
        ]
        RenderTafel.speichern("p61-signale", spalten: 3, zellen: zellen)
    }
}
