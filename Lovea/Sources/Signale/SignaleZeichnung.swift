import SwiftUI

/// Ein Standbild: zeichnet in einem festen Raster und streckt es auf den Rahmen. Kein Takt, keine Uhr.
struct SignaleBild: View {
    var raster = CGSize(width: 40, height: 40)
    let zeichne: (GraphicsContext) -> Void

    var body: some View {
        Canvas { g, groesse in
            var k = g
            k.scaleBy(x: groesse.width / raster.width, y: groesse.height / raster.height)
            zeichne(k)
        }
        .accessibilityHidden(true)
    }
}

/// p60: die Vektorzeichnungen der Paar-Signale im Zimmer, im Sticker-Stil der Figuren (`teil`).
/// Jede Zeichnung liegt in ihrem eigenen kleinen Raster und bleibt bei jeder Größe scharf.
enum SignaleZeichnung {
    static let blasenRaster = CGSize(width: 48, height: 56)
    static let zettelRaster = CGSize(width: 40, height: 44)
    static let geschenkRaster = CGSize(width: 40, height: 32)
    static let schalterRaster = CGSize(width: 28, height: 36)

    private static let papier = FigurFarbe(0xFFF6E6)

    // MARK: Stimmung

    static func farbe(_ s: Gefuehl) -> FigurFarbe {
        switch s {
        case .muede: FigurFarbe(0xB9CBF2)
        case .verliebt: FigurFarbe(0xFFB8CB)
        case .gestresst: FigurFarbe(0xFFB47A)
        case .gluecklich: FigurFarbe(0xFFDB5E)
        case .krank: FigurFarbe(0xC3E6A5)
        case .vermisse: FigurFarbe(0xCFC0F4)
        }
    }

    /// Das runde Gesicht einer Stimmung im 40 x 40 Raster.
    static func gesicht(_ g: GraphicsContext, _ s: Gefuehl) {
        let tinte = Pal.tinte.farbe
        teil(g, kreis(P(20, 20), 17), farbe(s), 2.5)
        if s != .krank {
            g.fill(kreis(P(8.5, 25), 3), with: .color(Pal.rose.farbe.opacity(0.28)))
            g.fill(kreis(P(31.5, 25), 3), with: .color(Pal.rose.farbe.opacity(0.28)))
        }
        switch s {
        case .gluecklich:
            linie(g, bogen(P(10, 19), P(17, 19), P(13.5, 12)), tinte, 2.2)
            linie(g, bogen(P(23, 19), P(30, 19), P(26.5, 12)), tinte, 2.2)
            let mund = Path { p in
                p.move(to: P(11, 25))
                p.addQuadCurve(to: P(29, 25), control: P(20, 38))
                p.closeSubpath()
            }
            g.fill(mund, with: .color(tinte))
            g.fill(oval(P(20, 30.5), 4.2, 2.4), with: .color(Pal.rose.farbe.opacity(0.8)))
        case .verliebt:
            teil(g, herzPfad(P(13.5, 18), 4.6), Pal.rose, 1)
            teil(g, herzPfad(P(26.5, 18), 4.6), Pal.rose, 1)
            linie(g, bogen(P(14, 27), P(26, 27), P(20, 33)), tinte, 2.2)
        case .muede:
            linie(g, bogen(P(9.5, 18), P(17, 18), P(13.25, 23)), tinte, 2.2)
            linie(g, bogen(P(23, 18), P(30.5, 18), P(26.75, 23)), tinte, 2.2)
            g.fill(oval(P(20, 28.5), 3, 3.8), with: .color(tinte))
            let z = Path { p in
                p.move(to: P(27, 6))
                p.addLine(to: P(33, 6))
                p.addLine(to: P(27, 12))
                p.addLine(to: P(33, 12))
            }
            linie(g, z, Pal.dunkel.farbe, 1.8)
        case .gestresst:
            linie(g, strich(P(9, 12), P(17, 15)), tinte, 2.2)
            linie(g, strich(P(31, 12), P(23, 15)), tinte, 2.2)
            g.fill(kreis(P(14, 20), 2), with: .color(tinte))
            g.fill(kreis(P(26, 20), 2), with: .color(tinte))
            let zacken = Path { p in
                p.move(to: P(11, 30))
                p.addLine(to: P(15.5, 26.5))
                p.addLine(to: P(20, 30))
                p.addLine(to: P(24.5, 26.5))
                p.addLine(to: P(29, 30))
            }
            linie(g, zacken, tinte, 2.2)
            let spitze = Path { p in
                p.move(to: P(33, 4.5))
                p.addLine(to: P(30.6, 10))
                p.addLine(to: P(35.4, 10))
                p.closeSubpath()
            }
            g.fill(spitze, with: .color(Pal.himmel.farbe))
            teil(g, kreis(P(33, 11), 2.8), Pal.himmel, 1)
        case .krank:
            linie(g, strich(P(10.5, 19), P(17.5, 19)), tinte, 2.2)
            linie(g, strich(P(22.5, 19), P(29.5, 19)), tinte, 2.2)
            linie(g, bogen(P(13, 29), P(24, 29), P(18.5, 26)), tinte, 2.2)
            linie(g, strich(P(22, 29), P(34, 24)), tinte, 5.6)
            linie(g, strich(P(22, 29), P(34, 24)), Pal.weiss.farbe, 3.4)
            linie(g, strich(P(22, 29), P(26.4, 27.2)), Pal.rose.farbe, 3.4)
        case .vermisse:
            linie(g, strich(P(9, 15.5), P(17, 12.5)), tinte, 2.2)
            linie(g, strich(P(31, 15.5), P(23, 12.5)), tinte, 2.2)
            g.fill(kreis(P(14, 21), 2.4), with: .color(tinte))
            g.fill(kreis(P(26, 21), 2.4), with: .color(tinte))
            g.fill(kreis(P(14.8, 20.2), 0.8), with: .color(.white))
            g.fill(kreis(P(26.8, 20.2), 0.8), with: .color(.white))
            linie(g, bogen(P(15, 30), P(25, 30), P(20, 26)), tinte, 2.2)
            teil(g, herzPfad(P(32, 7), 4.2), Pal.rose, 1)
        }
    }

    /// Die Sprechblase über der Figur. `nil`: leere Blase mit Plus, die die eigene Figur zum Setzen einlädt.
    static func blase(_ g: GraphicsContext, _ s: Gefuehl?) {
        if let s {
            let schwanz = Path { p in
                p.move(to: P(17, 43))
                p.addLine(to: P(24, 54))
                p.addLine(to: P(31, 43))
                p.closeSubpath()
            }
            verbunden(g, [kreis(P(24, 24), 22), schwanz], Pal.weiss, 3)
            var f = g
            f.translateBy(x: 8, y: 8)
            f.scaleBy(x: 0.8, y: 0.8)
            gesicht(f, s)
        } else {
            let kreisPfad = kreis(P(24, 24), 20)
            g.fill(kreisPfad, with: .color(.white.opacity(0.45)))
            g.stroke(kreisPfad, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [3, 5]))
            linie(g, strich(P(24, 16), P(24, 32)), .white, 3)
            linie(g, strich(P(16, 24), P(32, 24)), .white, 3)
        }
    }

    // MARK: Liebesbrief

    /// Der ungeöffnete Brief auf dem Tisch: Umschlag mit Herzsiegel.
    static func umschlag(_ g: GraphicsContext) {
        teil(g, box(3, 11, 34, 24, 3), papier, 2.5)
        let klappe = Path { p in
            p.move(to: P(4.5, 13))
            p.addLine(to: P(20, 25))
            p.addLine(to: P(35.5, 13))
        }
        linie(g, klappe, papier.kontur, 2)
        teil(g, herzPfad(P(20, 26), 4.2), Pal.rose, 1.2)
    }

    /// Der Briefstapel: alle schon geöffneten Briefe (oder noch keiner), tippen schreibt einen neuen.
    static func stapel(_ g: GraphicsContext) {
        teil(g, box(6, 26, 28, 9, 2), papier.mal(0.93), 2)
        teil(g, box(5, 20, 29, 9, 2), papier.mal(0.97), 2)
        teil(g, box(7, 14, 27, 9, 2), papier, 2)
        teil(g, herzPfad(P(20, 18.5), 3), Pal.rose, 1)
    }

    // MARK: Zettel, Geschenkbox, Schalter

    /// Der gelbe Zettel mit der Reißzwecke; das Fragezeichen setzt die Ansicht darüber.
    static func zettel(_ g: GraphicsContext) {
        let gelb = FigurFarbe(0xFFE88A)
        teil(g, box(5, 6, 30, 34, 2), gelb, 2.5)
        let ecke = Path { p in
            p.move(to: P(35, 30))
            p.addLine(to: P(35, 40))
            p.addLine(to: P(25, 40))
            p.closeSubpath()
        }
        g.fill(ecke, with: .color(gelb.mal(0.88).farbe))
        for y in [28, 33] as [CGFloat] {
            linie(g, strich(P(11, y), P(24, y)), gelb.mal(0.74).farbe, 1.6)
        }
        teil(g, kreis(P(20, 8.5), 2.8), Pal.rose, 1.2)
    }

    /// Die Geschenkbox: rosa Schachtel mit goldener Schleife.
    static func geschenkBox(_ g: GraphicsContext) {
        let rosa = FigurFarbe(0xFF8FB0)
        teil(g, box(5, 13, 30, 17, 3), rosa, 2.5)
        teil(g, box(3, 8, 34, 8, 3), rosa.mix(Pal.weiss, 0.25), 2.5)
        teil(g, box(17, 8, 6, 22, 1.5), Pal.gold, 1.5)
        teil(g, oval(P(14.5, 5), 5.5, 3.6), Pal.gold, 1.8)
        teil(g, oval(P(25.5, 5), 5.5, 3.6), Pal.gold, 1.8)
        teil(g, kreis(P(20, 6.5), 2.6), Pal.gold, 1.5)
    }

    /// Der Lichtschalter mit Mond. `an`: ich habe Gute Nacht gesagt, die Kippe steht unten.
    static func schalter(_ g: GraphicsContext, an: Bool) {
        teil(g, box(3, 2, 22, 32, 6), Pal.weiss, 2.5)
        g.fill(kreis(P(14, 11), 5.2), with: .color(Pal.gelb.farbe))
        g.fill(kreis(P(16.4, 9.4), 4.4), with: .color(Pal.weiss.farbe))
        teil(g, box(8, an ? 21 : 17, 12, 10, 4), an ? FigurFarbe(0x7E83D6) : FigurFarbe(0xD7D9E0), 2)
    }
}
