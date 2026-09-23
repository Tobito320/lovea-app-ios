import SwiftUI

/// Vector jewelry. Shop pieces (Z-23.3, Z-39.2) are keyed by catalog id, the free everyday pieces
/// (Z-39.3) by index: `FigurAussehen.ketten`/`ringe`/`armbaender` derive their names from the
/// tables below, so names and drawings never drift apart. Each style has one anchor: necklaces at
/// the collar, bracelets on the forearm, rings on the hand, earrings at the ears (`zeichneOhrschmuck`).
enum SchmuckStil: Sendable {
    case kette, ketteHerz, kettePerlen, ketteEdelstein, kugelkette, panzerkette, lederband, choker, layering
    case armreif, armreifLove, perlenArmband, lederArmband, kettchen, freundschaftsband
    case ring, ringStein, siegelring, stapelringe, ringLove
    case ohrringCC

    enum Ort: Sendable { case hals, handgelenk, hand, ohr }

    var ort: Ort {
        switch self {
        case .kette, .ketteHerz, .kettePerlen, .ketteEdelstein, .kugelkette, .panzerkette, .lederband, .choker, .layering: .hals
        case .armreif, .armreifLove, .perlenArmband, .lederArmband, .kettchen, .freundschaftsband: .handgelenk
        case .ring, .ringStein, .siegelring, .stapelringe, .ringLove: .hand
        case .ohrringCC: .ohr
        }
    }
}

typealias SchmuckEintrag = (name: String, geschlecht: FigurGeschlecht, stil: SchmuckStil, farbe: FigurFarbe)

let schmuckKatalog: [String: (stil: SchmuckStil, farbe: FigurFarbe)] = [
    "schmuck.kette-silber": (.kette, Pal.silber),
    "schmuck.kette-gold": (.kette, Pal.gold),
    "schmuck.cartier-kette": (.ketteHerz, Pal.gold),
    "schmuck.perlenkette": (.kettePerlen, FigurFarbe(0xF4F1EE)),
    "schmuck.tiffany-kette": (.ketteEdelstein, Pal.himmel),
    "schmuck.gold-kette": (.ketteEdelstein, Pal.gold),
    // Z-39.2 Luxus
    "schmuck.cartier-love": (.armreifLove, Pal.gold),
    "schmuck.cartier-love-ring": (.ringLove, Pal.gold),
    "schmuck.chanel-ohrringe": (.ohrringCC, Pal.gold),
]

/// Z-39.3: free everyday jewelry. Index + 1 = the stored `kette`/`ring`/`armband` value (0 = none).
let alltagsKetten: [SchmuckEintrag] = [
    ("Kugelkette", .n, .kugelkette, Pal.silber),
    ("Panzerkette", .n, .panzerkette, Pal.gold),
    ("Lederband", .n, .lederband, FigurFarbe(0x3B2A20)),
    ("Herzanhänger", .w, .ketteHerz, Pal.silber),
    ("Choker", .w, .choker, FigurFarbe(0x2B2830)),
    ("Layering-Ketten", .w, .layering, Pal.gold),
]

let alltagsRinge: [SchmuckEintrag] = [
    ("Silberring", .n, .ring, Pal.silber),
    ("Goldring", .n, .ring, Pal.gold),
    ("Siegelring", .n, .siegelring, Pal.gold),
    ("Ring mit Stein", .w, .ringStein, Pal.silber),
    ("Stapelringe", .w, .stapelringe, Pal.gold),
]

let alltagsArmbaender: [SchmuckEintrag] = [
    ("Perlenarmband", .n, .perlenArmband, FigurFarbe(0x7A5234)),
    ("Lederarmband", .n, .lederArmband, FigurFarbe(0x3B2A20)),
    ("Goldkettchen", .w, .kettchen, Pal.gold),
    ("Freundschaftsband", .n, .freundschaftsband, Pal.rose),
    ("Silberreif", .n, .armreif, Pal.silber),
]

/// Draws one piece at its anchor. `hals`: the collar point below the chin. `arm`: the forearm the
/// piece sits on (bracelets near the wrist, rings on the hand), `nil` when that arm is hidden.
/// Earrings are drawn with the head (`zeichneOhrschmuck`). `groesse` scales it (0.66 on the full body).
func zeichneSchmuck(_ g: GraphicsContext, _ stil: SchmuckStil, _ farbe: FigurFarbe, hals: CGPoint,
                    arm: (ellbogen: CGPoint, hand: CGPoint)?, bei anteil: CGFloat = 0.72, groesse: CGFloat = 1) {
    switch stil.ort {
    case .hals:
        var h = g
        h.translateBy(x: hals.x, y: hals.y)
        h.scaleBy(x: groesse, y: groesse)
        halsSchmuck(h, stil, farbe)
    case .handgelenk, .hand:
        guard let arm else { return }
        let dx = arm.hand.x - arm.ellbogen.x
        let dy = arm.hand.y - arm.ellbogen.y
        let t: CGFloat = stil.ort == .hand ? 1 : anteil
        var h = g
        h.translateBy(x: arm.ellbogen.x + dx * t, y: arm.ellbogen.y + dy * t)
        // Local y runs down the forearm toward the fingers, x across it.
        h.rotate(by: .radians(atan2(Double(dy), Double(dx)) - Double.pi / 2))
        h.scaleBy(x: groesse, y: groesse)
        if stil.ort == .hand { ringSchmuck(h, stil, farbe) } else { armSchmuck(h, stil, farbe) }
    case .ohr:
        break
    }
}

/// Shop pieces by catalog id (unknown ids draw nothing).
func zeichneSchmuck(_ g: GraphicsContext, id: String, hals: CGPoint, arm: (ellbogen: CGPoint, hand: CGPoint)?, groesse: CGFloat = 1) {
    guard let e = schmuckKatalog[id] else { return }
    zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: arm, bei: 0.56, groesse: groesse)
}

/// Necklaces around the origin (the collar point).
private func halsSchmuck(_ h: GraphicsContext, _ stil: SchmuckStil, _ f: FigurFarbe) {
    let kette = bogen(P(-14, 0), P(14, 0), P(0, 14))
    switch stil {
    case .kette:
        linie(h, kette, f.farbe, 2)
        teil(h, kreis(P(0, 14), 3), f, 1)
    case .ketteHerz:
        linie(h, kette, f.farbe, 2)
        teil(h, herzPfad(P(0, 16), 4), Pal.rose, 1)
    case .kettePerlen:
        linie(h, kette, f.farbe, 2)
        for dx in stride(from: CGFloat(-14), through: 14, by: 5) {
            teil(h, kreis(P(dx, 10 - abs(dx) * 0.3), 2.2), f, 1)
        }
    case .ketteEdelstein:
        linie(h, kette, f.farbe, 2)
        teil(h, oval(P(0, 15), 3.5, 4.5), f, 1)
        h.fill(kreis(P(-1, 13), 1), with: .color(.white.opacity(0.8)))
    case .kugelkette:
        for dx in stride(from: CGFloat(-13), through: 13, by: 3.25) {
            let y: CGFloat = 7 - abs(dx) * abs(dx) / 26
            h.fill(kreis(P(dx, y + 5), 1.3), with: .color(f.farbe))
        }
        teil(h, box(-3, 12, 6, 8, 1.5), f, 1)
    case .panzerkette:
        let kurz = bogen(P(-13, -1), P(13, -1), P(0, 11))
        linie(h, kurz, f.kontur, 5.5)
        linie(h, kurz, f.farbe, 3.8)
        for dx in stride(from: CGFloat(-9), through: 9, by: 4.5) {
            let y: CGFloat = 4.3 - abs(dx) * abs(dx) / 30
            linie(h, strich(P(dx - 1.2, y - 1.2), P(dx + 1.2, y + 1.2)), f.kontur.opacity(0.7), 1)
        }
    case .lederband:
        linie(h, bogen(P(-13, -2), P(13, -2), P(0, 16)), f.farbe, 1.8)
        linie(h, kreis(P(0, 9), 3), Pal.silber.kontur, 3)
        linie(h, kreis(P(0, 9), 3), Pal.silber.farbe, 1.8)
    case .choker:
        let band = bogen(P(-12, -12), P(12, -12), P(0, -7))
        linie(h, band, f.farbe, 4)
        teil(h, kreis(P(0, -9), 1.8), Pal.gold, 0.8)
    case .layering:
        linie(h, bogen(P(-13, -1), P(13, -1), P(0, 9)), f.farbe, 1.4)
        linie(h, bogen(P(-15, 1), P(15, 1), P(0, 21)), f.farbe, 1.4)
        teil(h, kreis(P(0, 11), 1.8), f, 0.8)
    default:
        break
    }
}

/// Bracelets across the forearm at the origin (local y points to the hand).
private func armSchmuck(_ h: GraphicsContext, _ stil: SchmuckStil, _ f: FigurFarbe) {
    switch stil {
    case .armreif, .armreifLove:
        teil(h, box(-9, -2.6, 18, 5.2, 2.6), f, 1.4)
        h.fill(box(-6, -1.6, 7, 1.2, 0.6), with: .color(.white.opacity(0.55)))
        if stil == .armreifLove {
            for x in [CGFloat(-4.5), 4.5] {
                h.fill(kreis(P(x, 0.2), 1), with: .color(f.kontur))
                linie(h, strich(P(x - 0.7, 0.2), P(x + 0.7, 0.2)), f.mix(Pal.weiss, 0.6).farbe, 0.5)
            }
        }
    case .perlenArmband:
        for x in stride(from: CGFloat(-8), through: 8, by: 4) { teil(h, kreis(P(x, 0), 2.2), f, 0.8) }
    case .lederArmband:
        teil(h, box(-9, -2, 18, 4, 2), f, 1)
        teil(h, kreis(P(0, 0), 1.6), Pal.silber, 0.6)
    case .kettchen:
        linie(h, strich(P(-8.5, 0), P(8.5, 0)), f.farbe, 1.4)
        teil(h, kreis(P(2, 2.5), 1.3), f, 0.6)
    case .freundschaftsband:
        teil(h, box(-9, -2.4, 18, 4.8, 2.4), f, 1)
        linie(h, strich(P(-8, -0.8), P(8, -0.8)), Pal.gelb.farbe, 1.1)
        linie(h, strich(P(-8, 1), P(8, 1)), Pal.himmel.farbe, 1.1)
    default:
        break
    }
}

/// Rings on the hand circle at the origin (local y points away from the wrist).
private func ringSchmuck(_ h: GraphicsContext, _ stil: SchmuckStil, _ f: FigurFarbe) {
    switch stil {
    case .ring, .ringLove:
        teil(h, box(-4.5, 2, 9, 3.2, 1.6), f, 1)
        if stil == .ringLove { for x in [CGFloat(-2), 2] { h.fill(kreis(P(x, 3.6), 0.7), with: .color(f.kontur)) } }
    case .ringStein:
        teil(h, box(-4.5, 2, 9, 3, 1.5), f, 1)
        teil(h, kreis(P(0, 2), 2.3), Pal.himmel, 0.8)
        h.fill(kreis(P(-0.7, 1.3), 0.7), with: .color(.white.opacity(0.9)))
    case .siegelring:
        teil(h, box(-4.5, 2.4, 9, 2.8, 1.4), f, 1)
        teil(h, box(-2.8, 0.8, 5.6, 4.4, 1.2), f.mal(0.9), 0.9)
    case .stapelringe:
        teil(h, box(-4.5, 0.6, 9, 2.2, 1.1), f, 0.8)
        teil(h, box(-4.5, 3.6, 9, 2.2, 1.1), Pal.silber, 0.8)
    default:
        break
    }
}

/// Earrings from the shop, in the head space (ears at x 42 and 158, y ≈ 110).
func zeichneOhrschmuck(_ g: GraphicsContext, id: String) {
    guard let e = schmuckKatalog[id], e.stil == .ohrringCC else { return }
    for x in [CGFloat(42), 158] {
        // Two C's back to back: the left one opens to the left, the right one to the right.
        let links = Path { p in p.addArc(center: P(x - 1.6, 115), radius: 3.6, startAngle: .degrees(230), endAngle: .degrees(130), clockwise: false) }
        let rechts = Path { p in p.addArc(center: P(x + 1.6, 115), radius: 3.6, startAngle: .degrees(50), endAngle: .degrees(310), clockwise: false) }
        for bogenC in [links, rechts] {
            linie(g, bogenC, e.farbe.kontur, 3)
            linie(g, bogenC, e.farbe.farbe, 1.6)
        }
        linie(g, strich(P(x, 108), P(x, 111.4)), e.farbe.farbe, 1.4)
    }
}
