import SwiftUI

/// Zimmer-Objekte: die Vektorzeichnungen im Sticker-Stil der Figuren (`teil`, `linie`), je in einem
/// eigenen kleinen Raster, scharf bei jeder Größe. Gezeichnet wird über `SignaleBild`.
enum ZimmerObjekteZeichnung {
    static let briefkastenRaster = CGSize(width: 48, height: 70)
    static let umschlagRaster = CGSize(width: 20, height: 14)
    static let anrufRaster = CGSize(width: 64, height: 46)
    static let glasRaster = CGSize(width: 52, height: 56)
    static let herzRaster = CGSize(width: 12, height: 12)
    static let schweinRaster = CGSize(width: 56, height: 46)
    static let kalenderRaster = CGSize(width: 42, height: 56)
    static let rahmenRaster = CGSize(width: 64, height: 52)
    /// Das Bild im Rahmen (Raster-Einheiten): hier liegt das Foto.
    static let rahmenBild = CGRect(x: 7, y: 7, width: 50, height: 38)

    private static let papier = FigurFarbe(0xFFF6E6)
    private static let glas = FigurFarbe(0xE6F3FF)
    private static let schwein = FigurFarbe(0xF7A8B8)
    private static let schweinDunkel = FigurFarbe(0xE88DA0)
    private static let kasten = FigurFarbe(0x7FB6E8)
    private static let lampeAus = FigurFarbe(0x8A5560)

    // MARK: Briefkasten

    static func umschlag(_ g: GraphicsContext, winkel: Double = 0) {
        var k = g
        k.translateBy(x: 10, y: 7)
        k.rotate(by: .degrees(winkel))
        k.translateBy(x: -10, y: -7)
        teil(k, box(2, 2, 16, 10, 2), papier, 1.6)
        linie(k, bogen(P(3, 3.5), P(17, 3.5), P(10, 9)), Pal.rose.farbe, 1.2)
    }

    /// Briefkasten auf dem Pfosten: Umschläge ragen oben heraus (`stapel`), die Fahne steht bei Post,
    static func briefkasten(_ g: GraphicsContext, stapel: ZimmerObjekteLogik.Stapel, fahne: Bool) {
        teil(g, box(21, 34, 6, 34, 2), Pal.holz, 2.4)
        teil(g, box(14, 64, 20, 5, 2), Pal.holz, 2)
        // Umschläge hinter dem Kasten, leicht gefächert
        for i in 0..<stapel.sichtbar {
            var k = g
            k.translateBy(x: 9 + Double(i) * 5, y: 1 - Double(i % 2) * 3)
            umschlag(k, winkel: Double(i) * 9 - 14)
        }
        teil(g, box(4, 8, 40, 28, 12), kasten, 3)
        linie(g, bogen(P(10, 15), P(24, 12), P(16, 11)), Color.white.opacity(0.75), 2)
        teil(g, box(14, 22, 20, 4, 2), FigurFarbe(0x3A5A80), 1.4)
        teil(g, herzPfad(P(24, 31), 2.4), Pal.rose, 1.2)
        if stapel.ueberlauf > 0 {
            // Läuft über: ein Brief liegt schon unten vor dem Pfosten
            var k = g
            k.translateBy(x: 28, y: 56)
            umschlag(k, winkel: 18)
        }
        // Fahne
        linie(g, strich(P(44, 26), P(44, fahne ? 8 : 24)), Pal.tinte.farbe, 2.2)
        if fahne {
            teil(g, box(44, 6, 8, 6, 1.5), Pal.rose, 1.6)
        } else {
            teil(g, box(44, 22, 6, 5, 1.5), Pal.rose, 1.6)
        }
    }

    // MARK: Anrufbeantworter

    /// Kassettengerät auf einem Brett: zwei Spulen, rote Lampe (`lampe`), zweistellige Anzeige.
    static func anrufbeantworter(_ g: GraphicsContext, ziffern: String, lampe: Bool, hatNachricht: Bool) {
        teil(g, box(0, 40, 64, 6, 3), Pal.holz, 2)
        teil(g, box(6, 8, 52, 32, 9), FigurFarbe(0xEDE7F6), 3)
        teil(g, box(11, 12, 42, 14, 5), FigurFarbe(0x3B3A44), 1.4)
        for x in [22.0, 42.0] {
            let c = P(x, 19)
            g.fill(kreis(c, 5.2), with: .color(Color.white.opacity(0.92)))
            for a in stride(from: 0.0, to: 360.0, by: 120.0) {
                let w = (a + (hatNachricht ? 20 : 0)) * .pi / 180
                linie(g, strich(c, P(c.x + sin(w) * 3.6, c.y - cos(w) * 3.6)), Pal.tinte.farbe, 1.3)
            }
        }
        // Lampe
        let an = lampe && hatNachricht
        if an { g.fill(kreis(P(15, 33), 6), with: .color(Pal.rose.farbe.opacity(0.28))) }
        teil(g, kreis(P(15, 33), 3.2), an ? Pal.rose : lampeAus, 1.4)
        // Anzeige
        teil(g, box(25, 29, 18, 8, 2.5), FigurFarbe(0x2B2430), 1.2)
        g.draw(Text(ziffern).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(hatNachricht ? Pal.rose.farbe : Color.white.opacity(0.5)), at: P(34, 33.2))
        // Taste
        teil(g, kreis(P(49, 33), 3), Pal.gold, 1.2)
    }

    // MARK: Herzglas

    static let glasPlaetze: [CGPoint] = [P(19, 44), P(33, 44), P(26, 38), P(17, 34), P(35, 34), P(26, 29), P(26, 22)]

    /// Einmachglas auf einem Brett; `herzen` Herzen liegen unten drin.
    static func herzglas(_ g: GraphicsContext, herzen: Int) {
        teil(g, box(0, 50, 52, 6, 3), Pal.holz, 2)
        teil(g, box(14, 6, 24, 8, 3), Pal.gold, 2.2)
        let koerper = box(8, 13, 36, 38, 12)
        g.fill(koerper, with: .color(glas.farbe.opacity(0.55)))
        for i in 0..<min(max(herzen, 0), glasPlaetze.count) {
            teil(g, herzPfad(glasPlaetze[i], 5.4), i % 2 == 0 ? Pal.rose : Pal.zunge, 1.6)
        }
        g.stroke(koerper, with: .color(glas.kontur), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        linie(g, strich(P(14, 22), P(14, 36)), Color.white.opacity(0.85), 2.2)
    }

    static func herz(_ g: GraphicsContext) {
        teil(g, herzPfad(P(6, 6), 4.6), Pal.rose, 1.4)
    }

    // MARK: Sparschwein

    /// Sparschwein mit Münzhaufen davor: `stufe` (0...5) Münzen wachsen als Haufen, bei 5 ein Funkeln.
    static func sparschwein(_ g: GraphicsContext, stufe: Int) {
        let n = min(max(stufe, 0), ZimmerObjekteLogik.schweinStufen)
        // Beine und Schwanz hinter dem Körper
        teil(g, box(24, 34, 7, 10, 3), schweinDunkel, 2)
        teil(g, box(40, 34, 7, 10, 3), schweinDunkel, 2)
        linie(g, bogen(P(14, 24), P(10, 18), P(8, 26)), schwein.kontur, 2.4)
        teil(g, oval(P(32, 26), 19, 14), schwein, 3)
        // Ohr
        var ohr = Path()
        ohr.move(to: P(39, 14))
        ohr.addLine(to: P(44, 6))
        ohr.addLine(to: P(47, 17))
        ohr.closeSubpath()
        teil(g, ohr, schweinDunkel, 2)
        // Rüssel
        teil(g, oval(P(51, 28), 4.5, 5.5), schweinDunkel, 2)
        g.fill(kreis(P(50.5, 27), 0.8), with: .color(Pal.tinte.farbe))
        g.fill(kreis(P(50.5, 30), 0.8), with: .color(Pal.tinte.farbe))
        // Auge, Wange, Schlitz
        g.fill(kreis(P(44, 22), 1.7), with: .color(Pal.tinte.farbe))
        g.fill(oval(P(42, 28.5), 2.8, 1.8), with: .color(Pal.rose.farbe.opacity(0.35)))
        linie(g, strich(P(26, 13.5), P(35, 13.5)), schwein.kontur, 2.4)
        // Münzen: eine fällt in den Schlitz (ab Stufe 1), der Haufen liegt vorne links
        if n > 0 {
            teil(g, oval(P(30.5, 8.5), 3, 4.2), Pal.gold, 1.4)
        }
        let haufen: [CGPoint] = [P(7, 42), P(15, 43), P(11, 37), P(3.5, 38), P(19, 38.5)]
        for i in 0..<min(n, haufen.count) {
            teil(g, oval(haufen[i], 4.2, 2.6), Pal.gold, 1.4)
        }
        if n >= ZimmerObjekteLogik.schweinStufen {
            teil(g, funkel(P(8, 26), 4.5), Pal.weiss, 1.2)
        }
    }

    // MARK: Abreißkalender

    /// Der Rumpf: Aufhänger und Rücken mit Stapel. Die oberste Seite folgt in `kalenderSeite`.
    static func kalenderRumpf(_ g: GraphicsContext) {
        linie(g, strich(P(21, 1), P(21, 6)), Pal.tinte.farbe, 1.6)
        teil(g, box(2, 4, 38, 50, 5), Pal.rose, 2.6)
        teil(g, box(5, 22, 32, 30, 3), FigurFarbe(0xF1E2CF), 1.2)
        linie(g, strich(P(7, 51), P(35, 51)), FigurFarbe(0xD9C7B0).farbe, 1.4)
        teil(g, kreis(P(14, 7.5), 1.9), Pal.silber, 1)
        teil(g, kreis(P(28, 7.5), 1.9), Pal.silber, 1)
    }

    /// Die oberste Seite mit der Zahl der Tage bis zum nächsten Meilenstein.
    static func kalenderSeite(_ g: GraphicsContext, tage: Int, fest: Bool) {
        teil(g, box(5, 14, 32, 34, 3), Pal.weiss, 1.8)
        let ziel = fest ? Pal.rose : Pal.tinte
        let zahl = Text(String(max(tage, 0))).font(.system(size: tage > 99 ? 14 : 20, weight: .heavy, design: .rounded)).foregroundStyle(ziel.farbe)
        g.draw(zahl, at: P(21, 29))
        let wort = Text(tage == 1 ? "Tag" : "Tage").font(.system(size: 6.5, weight: .bold, design: .rounded)).foregroundStyle(Pal.tinte.farbe.opacity(0.7))
        g.draw(wort, at: P(21, 41))
    }

    /// Konfetti für den Meilenstein-Tag: `phase` 0...1, rein aus der Zeit berechnet.
    static func konfetti(_ g: GraphicsContext, phase: Double) {
        let farben: [FigurFarbe] = [Pal.rose, Pal.gold, Pal.himmel, Pal.mint, Pal.decke]
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi + Double(i % 3) * 0.4
            let weite = (8 + Double(i % 5) * 5) * min(phase * 1.6, 1)
            let x = 21 + cos(a) * weite * 1.4
            let y = 24 + sin(a) * weite - 6 + phase * phase * 22
            g.fill(box(x - 1.4, y - 1.4, 2.8, 2.8, 0.6), with: .color(farben[i % farben.count].farbe.opacity(1 - phase * 0.8)))
        }
    }

    // MARK: Bilderrahmen

    static func bilderrahmen(_ g: GraphicsContext) {
        linie(g, strich(P(32, 1), P(14, 5)), Pal.tinte.farbe.opacity(0.5), 1)
        linie(g, strich(P(32, 1), P(50, 5)), Pal.tinte.farbe.opacity(0.5), 1)
        teil(g, box(2, 4, 60, 46, 5), Pal.holz, 3)
        teil(g, box(5, 5.5, 54, 43, 3), Pal.popcorn, 1.2)
    }

    /// Das Bild, solange es noch kein Foto gibt: Sonne, Hügel, ein Herz.
    static func bildPlatzhalter(_ g: GraphicsContext) {
        let r = rahmenBild
        g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(Pal.himmel.farbe.opacity(0.55)))
        g.fill(kreis(P(r.minX + 36, r.minY + 11), 5), with: .color(Pal.gelb.farbe))
        var huegel = Path()
        huegel.move(to: P(r.minX, r.maxY))
        huegel.addQuadCurve(to: P(r.minX + 30, r.maxY - 8), control: P(r.minX + 10, r.maxY - 20))
        huegel.addQuadCurve(to: P(r.maxX, r.maxY - 6), control: P(r.minX + 44, r.maxY - 18))
        huegel.addLine(to: P(r.maxX, r.maxY))
        huegel.closeSubpath()
        g.fill(huegel, with: .color(Pal.gruen.farbe))
        teil(g, herzPfad(P(r.minX + 14, r.minY + 14), 4.4), Pal.rose, 1.4)
    }
}
