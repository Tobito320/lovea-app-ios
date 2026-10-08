import SwiftUI

/// p63: das Wiedersehen-Schild mit dem Koffer an der Wand. Zeigt "noch 3 Tage" bis zum nächsten gemeinsamen
/// Treffen aus dem Kalender; am Tag selbst gibt es einmal eine kurze Feier.
enum ZimmerCountdown {
    enum Stand: Equatable, Sendable {
        case keins
        case noch(Int)
        case heute
    }

    /// `datum`: der Tag des nächsten Treffens (`yyyy-MM-dd`), `heute` ebenso. Ein Treffen in der Vergangenheit zählt nicht.
    static func stand(treffen datum: String?, heute: String) -> Stand {
        guard let datum else { return .keins }
        let tage = Datum.tageZwischen(heute, datum)
        return tage < 0 ? .keins : tage == 0 ? .heute : .noch(tage)
    }

    /// Der Text auf dem Schild.
    static func text(_ stand: Stand) -> String {
        switch stand {
        case .keins: "bald?"
        case .heute: "heute!"
        case .noch(let tage): tage == 1 ? "noch 1 Tag" : "noch \(tage) Tage"
        }
    }

    static let merkerSchluessel = "zimmer.wiedersehen.gefeiert"

    /// `true` genau einmal je Tag, und nur am Tag des Treffens. Merkt sich den Tag.
    static func feiern(_ stand: Stand, heute: String, merker: UserDefaults = .standard) -> Bool {
        guard stand == .heute, merker.string(forKey: merkerSchluessel) != heute else { return false }
        merker.set(heute, forKey: merkerSchluessel)
        return true
    }
}

// MARK: - Zeichnung

enum ZimmerCountdownZeichnung {
    /// Mitte des Schilds an der linken Wand.
    static let ort = CGPoint(x: 50, y: 103)
    static let schild = CGSize(width: 68, height: 22)

    static func zeichne(_ g: GraphicsContext, text: String, heute: Bool) {
        let holz = Pal.holz
        let m = ort
        // Zwei Nägel mit Schnur, dann das Brett.
        for dx in [-24, 24] as [CGFloat] {
            linie(g, strich(P(m.x + dx, m.y - 24), P(m.x + dx * 0.9, m.y - schild.height / 2 + 1)), Pal.dunkel.farbe.opacity(0.5), 1.1)
            teil(g, kreis(P(m.x + dx, m.y - 24), 1.8), Pal.silber, 0.8)
        }
        teil(g, box(m.x - schild.width / 2, m.y - schild.height / 2, schild.width, schild.height, 5), holz, 1.8)
        for dx in [-27, 27] as [CGFloat] { g.fill(kreis(P(m.x + dx, m.y - 6), 1), with: .color(holz.mal(0.55).farbe)) }
        linie(g, strich(P(m.x - 28, m.y - 8), P(m.x + 28, m.y - 8)), .white.opacity(0.22), 1)
        g.draw(Text(text).font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(heute ? Pal.rose.farbe : Pal.tinte.farbe), at: m)
        koffer(g, P(m.x, m.y + 33), heute: heute)
    }

    /// Ein kleiner Reisekoffer, der an einer Schnur unter dem Schild hängt. Mitte oben des Koffers bei `a`.
    private static func koffer(_ g: GraphicsContext, _ a: CGPoint, heute: Bool) {
        let leder = FigurFarbe(0xB4694A)
        linie(g, strich(P(a.x, a.y - 22), P(a.x, a.y - 8)), Pal.dunkel.farbe.opacity(0.5), 1.1)
        linie(g, bogen(P(a.x - 5, a.y - 6), P(a.x + 5, a.y - 6), P(a.x, a.y - 15)), Pal.dunkel.farbe, 2.4)
        teil(g, box(a.x - 15, a.y - 6, 30, 22, 4), leder, 1.8)
        teil(g, box(a.x - 15, a.y - 6, 30, 5, 3), leder.mix(Pal.weiss, 0.18), 1.2)
        for dx in [-8, 8] as [CGFloat] { teil(g, box(a.x + dx - 1.4, a.y - 6, 2.8, 22, 0.6), Pal.gold.mal(0.85), 0.8) }
        for dx in [-4, 4] as [CGFloat] { teil(g, box(a.x + dx - 1.6, a.y - 0.4, 3.2, 3.2, 0.8), Pal.gold, 0.7) }
        teil(g, herzPfad(P(a.x + 11, a.y + 9), 3.2), Pal.rose.mix(Pal.weiss, 0.2), 0.6)
        teil(g, kreis(P(a.x - 10.5, a.y + 10.5), 2.4), Pal.himmel, 0.6)
        g.fill(oval(P(a.x - 5, a.y + 3), 1.4, 3.4), with: .color(.white.opacity(0.3)))
        guard heute else { return }
        for (dx, dy, r) in [(-18, -4, 3.2), (17, 4, 2.6), (-14, 17, 2.2)] as [(CGFloat, CGFloat, CGFloat)] {
            g.fill(Path { p in
                let c = P(a.x + dx, a.y + dy)
                p.move(to: P(c.x, c.y - r))
                p.addQuadCurve(to: P(c.x + r, c.y), control: c)
                p.addQuadCurve(to: P(c.x, c.y + r), control: c)
                p.addQuadCurve(to: P(c.x - r, c.y), control: c)
                p.addQuadCurve(to: P(c.x, c.y - r), control: c)
            }, with: .color(Pal.gelb.farbe))
        }
    }
}

/// Die kurze Feier am Tag des Wiedersehens: Herzen und Konfetti steigen vom Schild auf. `fortschritt` 0 bis 1
/// wird von einer einzigen Animation gefahren, danach steht nichts mehr.
struct ZimmerFeierBild: View, @MainActor Animatable {
    var fortschritt: Double
    /// p65: in the panorama the sign is somewhere else, and the confetti rises from there.
    var welt: ProfilWelt = .einzel

    var animatableData: Double {
        get { fortschritt }
        set { fortschritt = newValue }
    }

    var body: some View {
        Canvas { g, groesse in
            guard fortschritt > 0, fortschritt < 1 else { return }
            let w = SzenenZeichnung.raum(g, groesse, welt: welt)
            let p = CGFloat(fortschritt)
            let farben = [Pal.rose, Pal.gelb, Pal.himmel, Pal.mint, Pal.decke]
            let start = welt.ort(ZimmerCountdownZeichnung.ort, .countdown)
            for i in 0..<22 {
                let seite = CGFloat((i * 37) % 17) / 8 - 1
                let tempo = 0.55 + CGFloat((i * 13) % 7) / 10
                let m = P(start.x + seite * 70 * p, start.y - 30 * tempo - 90 * p * tempo + 60 * p * p)
                let a = 1 - p * p
                let f = farben[i % farben.count].farbe.opacity(Double(a))
                if i % 3 == 0 {
                    w.fill(herzPfad(m, 4 + CGFloat(i % 3) * 1.5), with: .color(Pal.rose.farbe.opacity(Double(a))))
                } else {
                    w.fill(box(-2.5, -1.2, 5, 2.4, 0.8).applying(CGAffineTransform(rotationAngle: CGFloat(i) * 0.8 + p * 4)).offsetBy(dx: m.x, dy: m.y), with: .color(f))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
