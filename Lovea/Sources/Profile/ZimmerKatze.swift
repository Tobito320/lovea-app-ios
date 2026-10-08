import SwiftUI

/// p61: the cat at home. It sleeps on the bed (always in the evening and at night), follows Annika
/// to the window, and sits down next to her at the flowers and wants to be stroked. Stroking gives
/// a few points, once a day and person. The cat has no clock of its own: where it is and what it
/// does follows from where Annika is in the scene's step (`ZuhauseBuehne`), so it moves exactly
/// when p58's driver takes its next step and costs nothing in between.
enum KatzenZustand: Sendable { case schlaeft, folgt, will }

struct KatzenSzene: Equatable, Sendable {
    var zustand: KatzenZustand
    /// Design space of the home scene: the feet on the floor, the belly on the blanket when asleep.
    var ort: CGPoint
    /// Looks to the right (towards Annika when it sits left of her).
    var nachRechts: Bool
}

enum ZimmerKatze {
    /// The black cuddly cat (p57); a bought cat of one of them takes its place.
    static let standardId = "tier.katze-schwarz"
    /// On the blanket at the right end of the bed.
    static let bettOrt = CGPoint(x: 140, y: 312)

    static func id(tiere: [String?]) -> String {
        tiere.compactMap { $0 }.first { $0.hasPrefix("tier.katze") } ?? standardId
    }

    static func szene(zeit: Tageszeit, annika: Platz) -> KatzenSzene {
        let schlaf = KatzenSzene(zustand: .schlaeft, ort: bettOrt, nachRechts: false)
        guard !zeit.dunkel else { return schlaf }
        switch annika {
        case .bett, .sofa:
            return schlaf
        case .fenster:
            return KatzenSzene(zustand: .folgt, ort: P(ZuhauseOrte.fuss(.fenster, .annika).x - 38, ZuhauseOrte.fussY), nachRechts: true)
        case .blumen:
            return KatzenSzene(zustand: .will, ort: P(ZuhauseOrte.fuss(.blumen, .annika).x + 40, ZuhauseOrte.fussY), nachRechts: false)
        }
    }

    /// The little heart bubble: only an awake cat that was not stroked today.
    static func wuenscht(_ zustand: KatzenZustand, gestreichelt: Bool) -> Bool {
        zustand != .schlaeft && !gestreichelt
    }
}

/// What the stage needs of the cat: which one, whether it was stroked today, and the stroke itself
/// (returns the points it gave, 0 when today's were taken already).
struct ZuhauseKatze {
    let id: String
    let gestreichelt: Bool
    let streicheln: () -> Int
}

/// Points for stroking: one op per day and person, so a second tap, a second phone or a replay after
/// a reinstall count once. The id carries the day and the person; an op whose id does not match is ignored.
enum KatzeLogik {
    static let art = "katze.streicheln"
    static let punkte = 10
    static let grund = "Katze gestreichelt"

    struct D: Codable { var tag: String }

    static func opId(tag: String, von: Person) -> String { "katze-\(tag)-\(von.rawValue)" }

    static func eintraege(_ ops: [(id: String, tag: String, von: Person)]) -> [PunkteLogik.Eintrag] {
        var gesehen = Set<String>()
        return ops
            .filter { $0.id == opId(tag: $0.tag, von: $0.von) && gesehen.insert($0.id).inserted }
            .map { PunkteLogik.Eintrag(datum: $0.tag, von: $0.von, grund: grund, punkte: punkte) }
    }

    static func op(tag: String, von: Person) -> Op {
        let neu = Op.neu(art, D(tag: tag), von: von)
        return Op(id: opId(tag: tag, von: von), seq: nil, art: art, von: von, zeit: neu.zeit, d: neu.d)
    }
}

/// The cat's picture: the pet drawer of p57 in a frame with its feet at the bottom centre, the heart
/// bubble above it when it wants to be stroked, hearts and the points for a few seconds after a
/// stroke, a "z" while it sleeps. One still drawing; the move between two steps is the stage's own
/// animation of `position`.
struct ZimmerKatzeSicht: View {
    let id: String
    let szene: KatzenSzene
    let wuenscht: Bool
    /// Annika is walking: the cat gets up and walks with her, it lies down when she has arrived.
    let geht: Bool
    /// Set for a few seconds after a stroke: the points it gave (0 for none).
    let streichelt: Int?
    /// The stage's scale (points per design point) and the top of the room drawing on screen.
    let s: CGFloat
    let oben: CGFloat
    let tippen: () -> Void

    var body: some View {
        let szene = szene
        let id = id
        let herzen = streichelt != nil
        let schlaf = szene.zustand == .schlaeft && !geht && !herzen
        let pose: HaustierPose = schlaf || herzen ? .liegt : .steht
        let blase = wuenscht && !herzen
        let punkte = streichelt ?? 0
        Canvas { g, size in
            let boden = P(size.width / 2, size.height - 4 * s)
            // The drawer looks left by default for `nachLinks: true`.
            zeichneHaustier(g, id: id, boden: boden, groesse: s * 0.8, nachLinks: !szene.nachRechts, pose: pose)
            let kopf = P(boden.x, boden.y - 50 * s)
            if blase {
                let b = P(kopf.x + 14 * s, kopf.y - 14 * s)
                g.fill(Path(roundedRect: CGRect(x: b.x - 11 * s, y: b.y - 9 * s, width: 22 * s, height: 18 * s), cornerRadius: 8 * s), with: .color(.white))
                g.fill(kreis(P(b.x - 7 * s, b.y + 10 * s), 2.2 * s), with: .color(.white))
                g.fill(herzPfad(b, 5 * s), with: .color(Pal.rose.farbe))
            }
            if herzen {
                for (dx, dy, r) in [(-14, -4, 4.5), (2, -14, 6), (16, -6, 4)] as [(CGFloat, CGFloat, CGFloat)] {
                    g.fill(herzPfad(P(kopf.x + dx * s, kopf.y + dy * s), r * s), with: .color(Pal.rose.farbe))
                }
                if punkte > 0 {
                    g.draw(Text("+\(punkte)").font(.system(size: 13 * s, weight: .heavy, design: .rounded)).foregroundStyle(Color.white), at: P(kopf.x, kopf.y - 28 * s))
                }
            }
            if schlaf {
                g.draw(Text("z").font(.system(size: 12 * s, weight: .heavy, design: .rounded)).foregroundStyle(Color.white.opacity(0.9)), at: P(boden.x + 14 * s, boden.y - 34 * s))
                g.draw(Text("z").font(.system(size: 9 * s, weight: .heavy, design: .rounded)).foregroundStyle(Color.white.opacity(0.75)), at: P(boden.x + 22 * s, boden.y - 42 * s))
            }
        }
        .frame(width: 100 * s, height: 100 * s)
        .contentShape(Rectangle().inset(by: 18 * s))
        .onTapGesture(perform: tippen)
        .sensoryFeedback(.success, trigger: streichelt) { _, neu in neu != nil }
        .position(x: szene.ort.x * s, y: oben + (szene.ort.y - 46) * s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(szene.zustand == .schlaeft ? "Katze, schläft" : "Katze")
        .accessibilityHint("Streicheln")
        .accessibilityAddTraits(.isButton)
    }
}
