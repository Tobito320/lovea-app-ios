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

/// The awake pair in the partner profile. Level changes glide over 1.5 s; while a kiss plays
/// (fresh, own or a missed one replayed) the pair blends into Stufe 3 and back, driven by a
/// 30 fps clock, hearts rising along the way.
struct KussPaar<Figur: View>: View {
    /// Who stands in front while no kiss plays (the profile's person).
    let vorn: Person
    let stufe: Int
    let zusammen: Bool
    @ViewBuilder let figur: (Person, NaehePose, PaarEbene) -> Figur
    /// Bumped when the window ends: nothing in the model changes then, the pair must still let go.
    @State private var nachKuss = 0
    /// Stufe glide: the level shown before the last change and when it changed.
    @State private var vonStufe: Int?
    @State private var wechsel: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = nachKuss
        let beginn = FigurenModell.shared.kussBeginn
        let gleitet = wechsel.map { Date().timeIntervalSince($0) < 1.5 } ?? false
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: (beginn == nil && !gleitet) || reduceMotion)) { kontext in
            let stand = standBei(beginn, kontext.date)
            KussPaarBild(pose: pose(stand, kontext.date), herzen: stand != nil,
                         ahmedHerein: (stand.map { 1 - $0.weg } ?? 0) * (zusammen ? 0 : 150), figur: figur)
        }
        .onChange(of: stufe) { alt, _ in
            vonStufe = alt
            wechsel = Date()
        }
        .task(id: FigurenModell.shared.kussEreignis) {
            guard let beginn = FigurenModell.shared.kussBeginn else { return }
            try? await Task.sleep(for: .seconds(max(0, beginn.timeIntervalSinceNow + KussAblauf.dauer) + 0.05))
            nachKuss += 1
        }
    }

    private func standBei(_ beginn: Date?, _ jetzt: Date) -> KussAblauf.Stand? {
        guard let beginn else { return nil }
        return reduceMotion ? KussAblauf.voll : KussAblauf.stand(jetzt.timeIntervalSince(beginn))
    }

    /// Level pose (gliding 1.5 s after a change), blended into Stufe 3 while a kiss plays.
    private func pose(_ stand: KussAblauf.Stand?, _ jetzt: Date) -> NaehePose {
        let ziel = NaehePose.stufe(zusammen ? stufe : 0, vorn: vorn)
        var basis = ziel
        if let von = vonStufe, let wechsel, !reduceMotion {
            let t = min(1, CGFloat(jetzt.timeIntervalSince(wechsel) / 1.5))
            basis = NaehePose.mix(NaehePose.stufe(zusammen ? von : 0, vorn: vorn), ziel, t * t * (3 - 2 * t))
        }
        guard let stand else { return basis }
        var p = NaehePose.mix(basis, .stufe(3, vorn: vorn), stand.arme)
        if stand.geht { p.zustandAhmed = .laeuft }
        return p
    }
}

/// One frame of the pair in the partner profile: both bodies (front figure on top), then both pair
/// arms, like the `naehe-posen` board. While a kiss plays, hearts rise.
struct KussPaarBild<Figur: View>: View {
    let pose: NaehePose
    var herzen = false
    /// Extra sideways shift of Ahmed while he walks in from the right (kiss while apart).
    var ahmedHerein: CGFloat = 0
    @ViewBuilder let figur: (Person, NaehePose, PaarEbene) -> Figur
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            reihe(.ohneArm)
            reihe(.nurArm)
        }
        .overlay {
            if herzen, !reduceMotion {
                SteigendeHerzen().allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func reihe(_ ebene: PaarEbene) -> some View {
        HStack(alignment: .bottom, spacing: -64) {
            ForEach([Person.annika, .ahmed], id: \.self) { p in
                self.figur(p, self.pose, ebene)
                    .offset(x: self.pose.versatz(p) + (p == .ahmed ? self.ahmedHerein : 0))
                    .zIndex(p == self.pose.vorn ? 1 : 0)
            }
        }
    }
}

struct SteigendeHerzen: View {
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
