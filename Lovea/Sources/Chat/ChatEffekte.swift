import SwiftUI
import UIKit

/// Z-33.2: full-screen effects (Spec 2.5). The sender decides (`ChatModell.nachrichtSenden`), the
/// op carries the raw value as `effekt`.
enum ChatEffekt: String, CaseIterable, Sendable {
    case herzen, sterne, sonne, ballons, konfetti, glitzer, kuesse

    var titel: String {
        switch self {
        case .herzen: "Herzen"
        case .sterne: "Sterne"
        case .sonne: "Sonnenaufgang"
        case .ballons: "Ballons"
        case .konfetti: "Konfetti"
        case .glitzer: "Glitzer"
        case .kuesse: "Küsse"
        }
    }

    var symbol: String {
        switch self {
        case .herzen: "heart.fill"
        case .sterne: "moon.stars.fill"
        case .sonne: "sun.horizon.fill"
        case .ballons: "balloon.fill"
        case .konfetti: "party.popper.fill"
        case .glitzer: "sparkles"
        case .kuesse: "mouth.fill"
        }
    }

    /// Spec 2.5 trigger words, first matching effect wins. "vermisse dich" is the everyday spelling of
    /// "vermiss dich", which whole-word matching would otherwise miss.
    private static let ausloeser: [(effekt: ChatEffekt, woerter: [String])] = [
        (.herzen, ["ich liebe dich", "hdl", "love you"]),
        (.sterne, ["gute nacht"]),
        (.sonne, ["guten morgen"]),
        (.ballons, ["alles gute", "happy birthday"]),
        (.konfetti, ["glückwunsch"]),
        (.glitzer, ["vermiss dich", "vermisse dich"]),
        (.kuesse, ["kuss", "küsschen"]),
    ]

    /// Whole words only ("gute Nachtschicht", "Kussmund" don't count), anywhere in the text, case
    /// and umlaut spelling ignored ("Küsschen" = "Kuesschen" = "KÜSSCHEN").
    static func erkennen(_ text: String) -> ChatEffekt? {
        let t = normalisiert(text)
        return ausloeser.first { eintrag in eintrag.woerter.contains { enthaeltWort(t, normalisiert($0)) } }?.effekt
    }

    private static func normalisiert(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "ae", with: "a")
            .replacingOccurrences(of: "oe", with: "o")
            .replacingOccurrences(of: "ue", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func enthaeltWort(_ text: String, _ wort: String) -> Bool {
        var ab = text.startIndex
        while ab < text.endIndex, let treffer = text.range(of: wort, range: ab..<text.endIndex) {
            let davor: Character? = treffer.lowerBound > text.startIndex ? text[text.index(before: treffer.lowerBound)] : nil
            let danach: Character? = treffer.upperBound < text.endIndex ? text[treffer.upperBound] : nil
            if !istWortzeichen(davor), !istWortzeichen(danach) { return true }
            ab = text.index(after: treffer.lowerBound)
        }
        return false
    }

    private static func istWortzeichen(_ zeichen: Character?) -> Bool {
        guard let zeichen else { return false }
        return zeichen.isLetter || zeichen.isNumber
    }
}

/// Plays effects full screen. Each message's effect once, the first time it's seen (ids kept on
/// this device), tapping the bubble replays it. "Bewegung reduzieren" → no effects at all.
@MainActor
@Observable
final class ChatEffektSpieler {
    static let shared = ChatEffektSpieler()
    nonisolated static let dauer: TimeInterval = 3.2

    private(set) var laeuft: (effekt: ChatEffekt, start: Date)?
    @ObservationIgnored private var gesehen: [String] = UserDefaults.standard.stringArray(forKey: "lovea.chat.effekteGesehen") ?? []
    @ObservationIgnored private var wartend: ChatModell.Nachricht?
    @ObservationIgnored private var beobachter: NSObjectProtocol?

    func spielen(_ effekt: ChatEffekt) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let start = Date()
        laeuft = (effekt, start)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.dauer))
            if self?.laeuft?.start == start { self?.laeuft = nil }
        }
    }

    /// Row appeared. Only messages younger than a day play, so a reinstall doesn't replay history.
    func erstesSehen(_ nachricht: ChatModell.Nachricht) {
        guard let effekt = nachricht.effekt, !gesehen.contains(nachricht.id) else { return }
        // Arrived while the app is in the background with the chat open: wait until she actually looks.
        guard UIApplication.shared.applicationState == .active else {
            wartend = nachricht
            if beobachter == nil {
                beobachter = NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
                ) { _ in
                    MainActor.assumeIsolated {
                        let s = ChatEffektSpieler.shared
                        if let n = s.wartend { s.wartend = nil; s.erstesSehen(n) }
                    }
                }
            }
            return
        }
        // ponytail: newest 200 ids in UserDefaults; older ones are past the one-day window anyway.
        gesehen = Array((gesehen + [nachricht.id]).suffix(200))
        UserDefaults.standard.set(gesehen, forKey: "lovea.chat.effekteGesehen")
        if Date().timeIntervalSince(nachricht.zeit) < 86_400 { spielen(effekt) }
    }
}

/// Full-screen layer over the conversation; never takes touches.
struct ChatEffektEbene: View {
    var body: some View {
        if let laeuft = ChatEffektSpieler.shared.laeuft {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { kontext in
                ChatEffektAnsicht(effekt: laeuft.effekt, zeit: kontext.date.timeIntervalSince(laeuft.start))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
        }
    }
}

/// One frame of an effect at `zeit` seconds: Canvas particles, each a pure function of its index
/// and the time (no state), fading out towards `ChatEffektSpieler.dauer`.
struct ChatEffektAnsicht: View {
    let effekt: ChatEffekt
    let zeit: Double

    var body: some View {
        Canvas { g, groesse in
            var kontext = g
            let rest = ChatEffektSpieler.dauer - zeit
            kontext.opacity = max(0, min(1, rest / 0.6, zeit / 0.25))
            ChatEffektZeichner(zeit: zeit, groesse: groesse).zeichne(effekt, in: kontext)
        }
    }
}

private struct ChatEffektZeichner {
    let zeit: Double
    let groesse: CGSize

    /// Deterministic 0..<1 per particle and channel.
    func zufall(_ i: Int, _ k: Int) -> CGFloat {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    func zeichne(_ effekt: ChatEffekt, in g: GraphicsContext) {
        switch effekt {
        case .herzen: fallend(g, anzahl: 34) { g, i, p, s in g.fill(herzPfad(p, s), with: .color(farbe(i, [.pink, .red, Color.loveaRose]))) }
        case .kuesse: steigend(g, anzahl: 18) { g, i, p, s in g.draw(Text("💋").font(.system(size: s * 2)), at: p) }
        case .ballons: ballons(g)
        case .konfetti: konfetti(g)
        case .glitzer: funkeln(g, anzahl: 60, farben: [.yellow, .white, .orange])
        case .sterne: sterne(g)
        case .sonne: sonne(g)
        }
    }

    private func farbe(_ i: Int, _ farben: [Color]) -> Color { farben[i % farben.count] }

    /// Falling from above the top edge with a little sway (hearts).
    private func fallend(_ g: GraphicsContext, anzahl: Int, _ zeichnen: (GraphicsContext, Int, CGPoint, CGFloat) -> Void) {
        for i in 0..<anzahl {
            let t = zeit - Double(zufall(i, 2)) * 1.2
            guard t > 0 else { continue }
            let tempo = groesse.height / (1.6 + zufall(i, 3) * 0.9)
            let x = zufall(i, 1) * groesse.width + CGFloat(sin(t * 2 + Double(i))) * 18
            let y = -30 + CGFloat(t) * tempo
            zeichnen(g, i, CGPoint(x: x, y: y), 10 + zufall(i, 4) * 12)
        }
    }

    /// Rising from below the bottom edge (kisses, balloons).
    private func steigend(_ g: GraphicsContext, anzahl: Int, _ zeichnen: (GraphicsContext, Int, CGPoint, CGFloat) -> Void) {
        for i in 0..<anzahl {
            let t = zeit - Double(zufall(i, 2)) * 1.0
            guard t > 0 else { continue }
            let tempo = groesse.height / (1.8 + zufall(i, 3) * 1.0)
            let x = zufall(i, 1) * groesse.width + CGFloat(sin(t * 1.6 + Double(i))) * 22
            let y = groesse.height + 40 - CGFloat(t) * tempo
            zeichnen(g, i, CGPoint(x: x, y: y), 12 + zufall(i, 4) * 10)
        }
    }

    private func ballons(_ g: GraphicsContext) {
        let farben: [Color] = [.red, .yellow, .blue, .green, .purple, .orange, .pink]
        steigend(g, anzahl: 14) { g, i, p, s in
            let r = s * 1.8
            var faden = Path()
            faden.move(to: CGPoint(x: p.x, y: p.y + r * 1.15))
            faden.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r * 3), control: CGPoint(x: p.x + r * 0.4, y: p.y + r * 2))
            g.stroke(faden, with: .color(.white.opacity(0.8)), lineWidth: 1.2)
            g.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.85, y: p.y - r, width: r * 1.7, height: r * 2.15)), with: .color(farbe(i, farben)))
            g.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.45, y: p.y - r * 0.7, width: r * 0.35, height: r * 0.55)), with: .color(.white.opacity(0.45)))
        }
    }

    private func konfetti(_ g: GraphicsContext) {
        let farben: [Color] = [.red, .yellow, .blue, .green, .pink, .orange, .purple, .mint]
        fallend(g, anzahl: 90) { g, i, p, s in
            var stueck = g
            stueck.translateBy(x: p.x, y: p.y)
            stueck.rotate(by: .radians(zeit * Double(2 + zufall(i, 5) * 5) + Double(i)))
            stueck.fill(Path(CGRect(x: -s * 0.35, y: -s * 0.18, width: s * 0.7, height: s * 0.36)), with: .color(farbe(i, farben)))
        }
    }

    private func funkeln(_ g: GraphicsContext, anzahl: Int, farben: [Color]) {
        for i in 0..<anzahl {
            let phase = sin(zeit * Double(3 + zufall(i, 3) * 4) + Double(zufall(i, 4)) * 6.3)
            let s = (4 + zufall(i, 5) * 9) * CGFloat(max(0, phase))
            guard s > 0.5 else { continue }
            let p = CGPoint(x: zufall(i, 1) * groesse.width, y: zufall(i, 2) * groesse.height)
            g.fill(stern(p, s), with: .color(farbe(i, farben)))
        }
    }

    /// Night sky: a dark veil, twinkling stars and a crescent moon.
    private func sterne(_ g: GraphicsContext) {
        g.fill(Path(CGRect(origin: .zero, size: groesse)), with: .color(Color(red: 0.05, green: 0.07, blue: 0.2).opacity(0.35)))
        funkeln(g, anzahl: 45, farben: [.white, .yellow])
        let mitte = CGPoint(x: groesse.width * 0.78, y: groesse.height * 0.16 + CGFloat(sin(zeit)) * 4)
        let mond = kreis(mitte, 34).subtracting(kreis(CGPoint(x: mitte.x + 16, y: mitte.y - 10), 30))
        g.fill(mond, with: .color(Color(red: 1, green: 0.93, blue: 0.62)))
    }

    /// Sunrise glow from the bottom edge with slowly turning rays.
    private func sonne(_ g: GraphicsContext) {
        let aufgang = CGFloat(min(zeit / 1.2, 1))
        let mitte = CGPoint(x: groesse.width / 2, y: groesse.height + 60 - aufgang * 160)
        let radius = groesse.height * 0.75
        g.fill(
            Path(ellipseIn: CGRect(x: mitte.x - radius, y: mitte.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(Gradient(colors: [.orange.opacity(0.55), .yellow.opacity(0.25), .clear]), center: mitte, startRadius: 20, endRadius: radius)
        )
        for i in 0..<12 {
            let winkel = Double(i) / 12 * 2 * .pi + zeit * 0.15
            var strahl = Path()
            strahl.move(to: mitte)
            strahl.addLine(to: CGPoint(x: mitte.x + CGFloat(cos(winkel)) * radius, y: mitte.y + CGFloat(sin(winkel)) * radius))
            g.stroke(strahl, with: .color(.yellow.opacity(0.18)), lineWidth: 10)
        }
        g.fill(kreis(mitte, 56), with: .color(.orange.opacity(0.9)))
    }

    private func stern(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: c)
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: c)
            p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: c)
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: c)
        }
    }
}
