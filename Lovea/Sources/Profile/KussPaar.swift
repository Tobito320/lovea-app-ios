import SwiftUI

/// Brief K: in the partner profile the two figures play the kiss themselves (this replaced the
/// pink card with the kiss GIF). Annika stands left, Ahmed right: he walks in from the right,
/// they hug, kiss, and he steps back, all within the same 4 s `geste` window as every kiss
/// (fresh, own or a missed one replayed). Reduce Motion holds the hug-and-kiss pose, no hearts.
enum KussAblauf {
    static let dauer: TimeInterval = 4

    struct Stand: Equatable, Sendable {
        /// How far Ahmed has come in (0 = his usual place), the hug arms, the kiss; each 0…1.
        var weg: CGFloat
        var arme: CGFloat
        var kuss: CGFloat
        /// Ahmed's legs walk while he comes and goes.
        var geht: Bool
    }

    static let voll = Stand(weg: 1, arme: 1, kuss: 1, geht: false)

    /// `t`: seconds since the kiss began. Come in 0–0.7, hug from 0.5, kiss 1.4–3.3, let go
    /// from 3.1, step back 3.4–4.
    static func stand(_ t: TimeInterval) -> Stand {
        Stand(
            weg: rampe(t, 0, 0.7) * (1 - rampe(t, 3.4, dauer)),
            arme: rampe(t, 0.5, 1.0) * (1 - rampe(t, 3.1, 3.7)),
            kuss: rampe(t, 1.4, 1.9) * (1 - rampe(t, 2.9, 3.3)),
            geht: (0..<0.7).contains(t) || (3.4..<dauer).contains(t)
        )
    }

    /// Smoothstep from 0 at `a` to 1 at `b`, clamped.
    static func rampe(_ t: TimeInterval, _ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
        let x = min(max((t - a) / (b - a), 0), 1)
        return CGFloat(x * x * (3 - 2 * x))
    }
}

extension KussAblauf.Stand {
    /// Sideways shift in points of the profile's 340-pt figures (HStack spacing -64, centres 106 pt
    /// apart, 0.85 pt per canvas unit): hug at about 77 units, kiss at about 69.
    func versatz(_ p: Person) -> CGFloat { p == .ahmed ? -(35 * weg + 6 * kuss) : 6 * weg }

    func umarmung(_ p: Person) -> Umarmung {
        let abstand = (106 + versatz(.ahmed) - versatz(.annika)) / 0.85
        return Umarmung(seite: p == .ahmed ? -1 : 1, abstand: abstand, arme: arme, kuss: kuss)
    }

    func zustand(_ p: Person) -> FigurZustand {
        if kuss > 0.3 { return .kuss }
        return p == .ahmed && geht ? .laeuft : .ruhig
    }
}

extension FigurenModell {
    /// When the kiss playing right now began (either person), `nil` when none plays.
    var kussBeginn: Date? {
        let jetzt = Date()
        return geste.values
            .filter { $0.art == .kuss && $0.bis > jetzt }
            .map { $0.bis.addingTimeInterval(-KussAblauf.dauer) }
            .max()
    }
}

/// The awake pair in the partner profile, driven by one 30 fps clock only while a kiss plays.
struct KussPaar<Figur: View>: View {
    /// Who stands in front while no kiss plays (the profile's person).
    let vorn: Person
    @ViewBuilder let figur: (Person, KussAblauf.Stand?) -> Figur
    /// Bumped when the window ends: nothing in the model changes then, the pair must still let go.
    @State private var nachKuss = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = nachKuss
        let beginn = FigurenModell.shared.kussBeginn
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: beginn == nil || reduceMotion)) { kontext in
            KussPaarBild(vorn: vorn, stand: stand(beginn, kontext.date), figur: figur)
        }
        .task(id: FigurenModell.shared.kussEreignis) {
            guard let beginn = FigurenModell.shared.kussBeginn else { return }
            try? await Task.sleep(for: .seconds(max(0, beginn.timeIntervalSinceNow + KussAblauf.dauer) + 0.05))
            nachKuss += 1
        }
    }

    private func stand(_ beginn: Date?, _ jetzt: Date) -> KussAblauf.Stand? {
        guard let beginn else { return nil }
        return reduceMotion ? KussAblauf.voll : KussAblauf.stand(jetzt.timeIntervalSince(beginn))
    }
}

/// One frame of the pair, also drawn by the render board. While a kiss plays Ahmed is always in
/// front (his arm lies over her shoulders), the same on both phones.
struct KussPaarBild<Figur: View>: View {
    let vorn: Person
    let stand: KussAblauf.Stand?
    @ViewBuilder let figur: (Person, KussAblauf.Stand?) -> Figur
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: -64) {
            ForEach([Person.annika, .ahmed], id: \.self) { p in
                figur(p, stand)
                    .offset(x: stand?.versatz(p) ?? 0)
                    .zIndex((stand == nil ? p == vorn : p == .ahmed) ? 1 : 0)
            }
        }
        .overlay {
            if let stand, stand.kuss > 0, !reduceMotion {
                SteigendeHerzen()
                    .opacity(Double(stand.kuss))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct SteigendeHerzen: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { kontext in
            let t = kontext.date.timeIntervalSince(start)
            Canvas { g, groesse in
                for k in 0..<12 {
                    let p = (t * 0.32 + Double(k) / 12).truncatingRemainder(dividingBy: 1)
                    let basis = groesse.width * (0.25 + 0.5 * Double((k * 37) % 10) / 10)
                    let x = basis + sin(t * 2.2 + Double(k)) * 10
                    let herz = g.resolve(Text(Image(systemName: "heart.fill"))
                        .font(.system(size: CGFloat(16 + (k * 7) % 16)))
                        .foregroundColor(k % 3 == 0 ? .red : .pink))
                    g.opacity = 1 - p
                    g.draw(herz, at: CGPoint(x: x, y: groesse.height * (0.85 - 0.8 * p)))
                }
            }
        }
    }
}
