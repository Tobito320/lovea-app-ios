import SwiftUI

// Cute decoration for the Zyklus area: hearts, flowers and sparkles as plain SwiftUI shapes.

struct ZyklusHerzForm: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        var pfad = Path()
        pfad.move(to: p(0.5, 0.95))
        pfad.addCurve(to: p(0, 0.32), control1: p(0.35, 0.82), control2: p(0, 0.62))
        pfad.addCurve(to: p(0.5, 0.25), control1: p(0, -0.05), control2: p(0.42, -0.02))
        pfad.addCurve(to: p(1, 0.32), control1: p(0.58, -0.02), control2: p(1, -0.05))
        pfad.addCurve(to: p(0.5, 0.95), control1: p(1, 0.62), control2: p(0.65, 0.82))
        pfad.closeSubpath()
        return pfad
    }
}

/// Five round petals around the centre.
struct ZyklusBluetenForm: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let mitte = CGPoint(x: rect.midX, y: rect.midY)
        var pfad = Path()
        for i in 0..<5 {
            let blatt = Path(ellipseIn: CGRect(x: -r * 0.34, y: -r, width: r * 0.68, height: r * 0.98))
            let drehung = CGAffineTransform(rotationAngle: CGFloat(i) * 2 * .pi / 5)
                .concatenating(CGAffineTransform(translationX: mitte.x, y: mitte.y))
            pfad.addPath(blatt.applying(drehung))
        }
        return pfad
    }
}

/// Four-pointed sparkle.
struct ZyklusSternchenForm: Shape {
    func path(in rect: CGRect) -> Path {
        let mitte = CGPoint(x: rect.midX, y: rect.midY)
        var pfad = Path()
        pfad.move(to: CGPoint(x: rect.midX, y: rect.minY))
        pfad.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: mitte)
        pfad.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: mitte)
        pfad.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: mitte)
        pfad.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: mitte)
        pfad.closeSubpath()
        return pfad
    }
}

/// Flower with a peach centre.
struct ZyklusBluemchen: View {
    var farbe: Color
    var mitte: Color
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZyklusBluetenForm().fill(farbe)
                Circle().fill(mitte).frame(width: geo.size.width * 0.26, height: geo.size.width * 0.26)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Scattered hearts, flowers and sparkles. Purely decorative; they float gently unless Reduce Motion is on.
struct ZyklusDeko: View {
    private enum Art { case herz, bluete, stern }
    private struct Stueck {
        let x: CGFloat, y: CGFloat, groesse: CGFloat, winkel: Double
        let art: Art
        let ton: Int
    }

    private static let stuecke: [Stueck] = [
        Stueck(x: 0.08, y: 0.10, groesse: 22, winkel: -12, art: .herz, ton: 0),
        Stueck(x: 0.88, y: 0.07, groesse: 26, winkel: 10, art: .bluete, ton: 1),
        Stueck(x: 0.52, y: 0.05, groesse: 14, winkel: 0, art: .stern, ton: 2),
        Stueck(x: 0.93, y: 0.42, groesse: 18, winkel: 14, art: .herz, ton: 1),
        Stueck(x: 0.05, y: 0.46, groesse: 24, winkel: -8, art: .bluete, ton: 0),
        Stueck(x: 0.20, y: 0.80, groesse: 16, winkel: 0, art: .stern, ton: 1),
        Stueck(x: 0.82, y: 0.88, groesse: 24, winkel: -10, art: .herz, ton: 0),
        Stueck(x: 0.50, y: 0.93, groesse: 20, winkel: 8, art: .bluete, ton: 2),
        Stueck(x: 0.70, y: 0.25, groesse: 12, winkel: 0, art: .stern, ton: 0),
        Stueck(x: 0.30, y: 0.30, groesse: 10, winkel: 0, art: .stern, ton: 2),
    ]

    var dichte: Double = 1
    @Environment(\.colorScheme) private var schema
    @Environment(\.accessibilityReduceMotion) private var weniger
    @State private var schwebt = false

    var body: some View {
        GeometryReader { geo in
            let anzahl = max(0, min(Self.stuecke.count, Int((Double(Self.stuecke.count) * dichte).rounded())))
            ForEach(0..<anzahl, id: \.self) { i in
                let s = Self.stuecke[i]
                stueck(s)
                    .frame(width: s.groesse, height: s.groesse)
                    .rotationEffect(.degrees(s.winkel))
                    .offset(y: weniger ? 0 : (schwebt ? -3 : 3))
                    .animation(weniger ? nil : .easeInOut(duration: 2.4 + Double(i) * 0.3).repeatForever(autoreverses: true), value: schwebt)
                    .position(x: geo.size.width * s.x, y: geo.size.height * s.y)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { schwebt = true }
    }

    private func farbe(_ ton: Int) -> Color {
        let wahl: ZyklusFarbe = ton == 0 ? .zuckerrosa : ton == 1 ? .pfirsich : .fliederweiss
        return wahl.farbe(schema).opacity(schema == .dark ? 0.55 : 0.85)
    }

    @ViewBuilder private func stueck(_ s: Stueck) -> some View {
        switch s.art {
        case .herz: ZyklusHerzForm().fill(farbe(s.ton))
        case .bluete: ZyklusBluemchen(farbe: farbe(s.ton), mitte: ZyklusFarbe.himbeere.farbe(schema).opacity(0.7))
        case .stern: ZyklusSternchenForm().fill(farbe(s.ton))
        }
    }
}
