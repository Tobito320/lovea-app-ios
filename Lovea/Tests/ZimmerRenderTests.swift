import SwiftUI
import XCTest
@testable import Lovea

/// p61: the render board `p62-gestalten.png`: the header for two, the room with each shop piece, the
/// cat in its states. The stage runs fixed (no driver), so every cell is one still picture.
@MainActor
final class ZimmerRenderTests: XCTestCase {
    private let katze = ZuhauseKatze(id: ZimmerKatze.standardId, gestreichelt: false, streicheln: { 0 })

    private func figuren(_ f: ZuhauseFigur) -> some View {
        FigurView(.standard(for: f.person), zustand: f.zustand, groesse: f.groesse, animiert: false, ganzkoerper: f.ganzkoerper)
    }

    private func raum(_ zeit: Tageszeit, schritt: Int = 0, _ wahl: ZimmerWahl = .standard, katze: ZuhauseKatze? = nil, outfit: Bool = false) -> AnyView {
        let stand = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.aufstellung(zeit, schritt: schritt), mitGeste: true)
        let szene = ZuhauseBuehne(fest: stand, wahl: wahl, katze: katze, outfit: outfit ? {} : nil) { f in
            figuren(f)
        } paar: {
            EmptyView()
        }
        return AnyView(szene.frame(width: 390, height: 430).clipped())
    }

    /// The profile header as `kopf` builds it: the scene behind, the pair's avatars and the title in front.
    private func kopf(online: [Person]) -> AnyView {
        let titel = VStack(alignment: .leading, spacing: 2) {
            Text(ProfilPaarAvatare.titel).font(.title2.bold())
            Text("zusammen seit 26.08.2026").font(.subheadline.weight(.medium)).opacity(0.9)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        let avatare = HStack(spacing: 6) {
            ForEach(Person.allCases, id: \.self) { p in ProfilAvatar(person: p, online: online.contains(p), d: 56) }
        }
        return AnyView(
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 10) {
                    avatare
                    titel
                }
                .padding(16)
            }
            .frame(width: 390, height: 430)
            .background(alignment: .bottom) { raum(.tag, katze: katze, outfit: true) }
        )
    }

    /// The cat alone on a floor strip, `s` 1.6 so the details show.
    private func katzeAllein(_ zustand: KatzenZustand, wuenscht: Bool, geht: Bool = false, streichelt: Int? = nil, rechts: Bool = false) -> AnyView {
        let s: CGFloat = 1.6
        let szene = KatzenSzene(zustand: zustand, ort: CGPoint(x: 75, y: 118), nachRechts: rechts)
        return AnyView(
            ZStack(alignment: .topLeading) {
                Color(red: 0.98, green: 0.94, blue: 0.88)
                ZimmerKatzeSicht(id: ZimmerKatze.standardId, szene: szene, wuenscht: wuenscht, geht: geht, streichelt: streichelt, s: s, oben: 0, tippen: {})
            }
            .frame(width: 240, height: 200)
            .clipped()
        )
    }

    func testGestaltenBrett() {
        let rose = ZimmerWahl.standard.einrichten("zimmer.wand-rose")
        let salbei = ZimmerWahl.standard.einrichten("zimmer.wand-salbei")
        let himmel = ZimmerWahl.standard.einrichten("zimmer.wand-himmel")
        let alles = ZimmerWahl.standard.einrichten("zimmer.wand-himmel").einrichten("zimmer.teppich-wolke")
            .einrichten("zimmer.bett-streifen").einrichten("zimmer.lampe-laterne")
        let zellen: [(titel: String, ansicht: AnyView)] = [
            (titel: "Kopf zu zweit: Ahmed & Annika, Ahmed online", ansicht: kopf(online: [.ahmed])),
            (titel: "Kopf zu zweit: beide online", ansicht: kopf(online: [.ahmed, .annika])),
            (titel: "Standard: Stange und Regal oben rechts", ansicht: raum(.tag, katze: katze, outfit: true)),
            (titel: "Wand Rosé", ansicht: raum(.tag, 0, rose)),
            (titel: "Wand Salbei", ansicht: raum(.tag, 0, salbei)),
            (titel: "Wand Himmel", ansicht: raum(.tag, 0, himmel)),
            (titel: "Wolkenteppich", ansicht: raum(.tag, 0, .standard.einrichten("zimmer.teppich-wolke"))),
            (titel: "Herzteppich", ansicht: raum(.tag, 0, .standard.einrichten("zimmer.teppich-herz"))),
            (titel: "Bettwäsche Salbei", ansicht: raum(.tag, 3, .standard.einrichten("zimmer.bett-salbei"))),
            (titel: "Bettwäsche Streifen", ansicht: raum(.tag, 3, .standard.einrichten("zimmer.bett-streifen"))),
            (titel: "Bettwäsche Herzen", ansicht: raum(.tag, 3, .standard.einrichten("zimmer.bett-herzen"))),
            (titel: "Rattanlampe", ansicht: raum(.tag, 0, .standard.einrichten("zimmer.lampe-rattan"))),
            (titel: "Laterne", ansicht: raum(.tag, 0, .standard.einrichten("zimmer.lampe-laterne"))),
            (titel: "Alles neu, am Tag", ansicht: raum(.tag, 0, alles)),
            (titel: "Alles neu, Abend im Bett", ansicht: raum(.abend, 0, alles, katze: katze)),
            (titel: "Alles neu, Nacht", ansicht: raum(.nacht, 0, alles, katze: katze)),
            (titel: "Katze schläft auf dem leeren Bett", ansicht: raum(.tag, 0, .standard, katze: katze)),
            (titel: "Katze folgt Annika zum Fenster", ansicht: raum(.tag, 2, .standard, katze: katze)),
            (titel: "Katze will gestreichelt werden (Blumen)", ansicht: raum(.tag, 1, .standard, katze: katze)),
            (titel: "Katze am Morgen, Annika am Fenster", ansicht: raum(.morgen, 0, .standard, katze: katze)),
            (titel: "Katze: schläft", ansicht: katzeAllein(.schlaeft, wuenscht: false)),
            (titel: "Katze: Herzblase, will streicheln", ansicht: katzeAllein(.will, wuenscht: true)),
            (titel: "Katze: gestreichelt, +10", ansicht: katzeAllein(.will, wuenscht: false, streichelt: KatzeLogik.punkte)),
            (titel: "Katze: nochmal gestreichelt, ohne Punkte", ansicht: katzeAllein(.will, wuenscht: false, streichelt: 0)),
            (titel: "Katze: läuft mit Annika", ansicht: katzeAllein(.folgt, wuenscht: true, geht: true, rechts: true)),
        ]
        RenderTafel.speichern("p62-gestalten", spalten: 4, zellen: zellen)
    }

    func testJedesTeilZeichnetTagUndNachtOhneAbsturz() {
        // Each piece by day and by night once, plus its shop picture: no crash, no empty image.
        for id in ZimmerTeile.alle.keys.sorted() {
            for zeit in [Tageszeit.tag, .nacht] {
                let ansicht = raum(zeit, 0, .nur(id), katze: katze)
                XCTAssertNotNil(ImageRenderer(content: ansicht).uiImage, "\(id) \(zeit)")
            }
            XCTAssertNotNil(ImageRenderer(content: ZimmerTeilVorschau(id: id).frame(width: 84, height: 96)).uiImage, id)
        }
    }
}
