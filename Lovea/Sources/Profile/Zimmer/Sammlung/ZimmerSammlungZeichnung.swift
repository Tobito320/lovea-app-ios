import SwiftUI

/// Zeichnungen der Sammlungs-Objekte (Worker H). Jede Ansicht füllt ihr Rect in Entwurfseinheiten mal `e`.
enum ZimmerSammlungZeichnung {
    static let holz = Color(red: 0.62, green: 0.42, blue: 0.26)
    static let papier = Color(red: 0.97, green: 0.93, blue: 0.82)
    static let blatt = Color(red: 0.42, green: 0.66, blue: 0.34)
    static let herbst = Color(red: 0.88, green: 0.52, blue: 0.20)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.28)

    /// Stimmungsfarbe eines Tages (Rohwert von `Gefuehl`), `nil` = blasser Platzhalter.
    static func stimmungsfarbe(_ roh: String?) -> Color {
        switch roh.flatMap(Gefuehl.init(rawValue:)) {
        case .muede?: Color(red: 0.55, green: 0.60, blue: 0.82)
        case .verliebt?: Color(red: 0.93, green: 0.40, blue: 0.55)
        case .gestresst?: Color(red: 0.88, green: 0.45, blue: 0.30)
        case .gluecklich?: Color(red: 0.98, green: 0.80, blue: 0.30)
        case .krank?: Color(red: 0.55, green: 0.75, blue: 0.50)
        case .vermisse?: Color(red: 0.70, green: 0.48, blue: 0.82)
        case nil: Color.white.opacity(0.28)
        }
    }

    // MARK: Mixtape

    struct Kassette: View {
        let anzahl: Int
        let e: CGFloat
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 3 * e).fill(Color(red: 0.25, green: 0.25, blue: 0.30))
                RoundedRectangle(cornerRadius: 2 * e).fill(ZimmerSammlungZeichnung.papier).frame(width: 30 * e, height: 11 * e).offset(y: -3 * e)
                HStack(spacing: 10 * e) {
                    Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.4 * e).frame(width: 6 * e, height: 6 * e)
                    Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.4 * e).frame(width: 6 * e, height: 6 * e)
                }.offset(y: -3 * e)
                if anzahl > 1 {
                    Text("\(anzahl)").font(.system(size: 7 * e, weight: .bold)).foregroundStyle(.white).offset(x: 17 * e, y: 8 * e)
                }
            }
            .frame(width: 44 * e, height: 26 * e)
        }
    }

    // MARK: Rezeptkasten

    struct Rezeptkasten: View {
        let karten: Int
        let e: CGFloat
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 3 * e).fill(ZimmerSammlungZeichnung.holz).frame(width: 38 * e, height: 20 * e).offset(y: 5 * e)
                ForEach(0..<min(karten, 3), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5 * e).fill(ZimmerSammlungZeichnung.papier)
                        .frame(width: 28 * e, height: 12 * e)
                        .rotationEffect(.degrees(Double(i - 1) * 6))
                        .offset(x: CGFloat(i - 1) * 4 * e, y: -6 * e)
                }
                RoundedRectangle(cornerRadius: 3 * e).fill(ZimmerSammlungZeichnung.holz.opacity(0.9)).frame(width: 38 * e, height: 12 * e).offset(y: 9 * e)
                Image(systemName: "heart.fill").font(.system(size: 6 * e)).foregroundStyle(Color(red: 0.93, green: 0.40, blue: 0.55)).offset(y: 9 * e)
            }
            .frame(width: 40 * e, height: 30 * e)
        }
    }

    // MARK: Wunschrolle

    struct Wunschrolle: View {
        let offen: Int
        let erledigt: Int
        let e: CGFloat
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 2 * e).fill(ZimmerSammlungZeichnung.papier).frame(width: 26 * e, height: 38 * e)
                VStack(spacing: 4 * e) {
                    ForEach(0..<min(max(offen + erledigt, 1), 4), id: \.self) { i in
                        HStack(spacing: 2 * e) {
                            Circle().fill(i < erledigt ? ZimmerSammlungZeichnung.blatt : Color.gray.opacity(0.45)).frame(width: 3 * e, height: 3 * e)
                            Capsule().fill(Color.gray.opacity(0.4)).frame(width: 14 * e, height: 1.6 * e)
                        }
                    }
                }
                Capsule().fill(ZimmerSammlungZeichnung.holz).frame(width: 32 * e, height: 5 * e).offset(y: -20 * e)
                Capsule().fill(ZimmerSammlungZeichnung.holz).frame(width: 32 * e, height: 5 * e).offset(y: 20 * e)
            }
            .frame(width: 34 * e, height: 44 * e)
        }
    }

    // MARK: Stimmungsregenbogen

    /// Zwei Bögen: außen meine Woche, innen die des Partners. Je Tag ein Abschnitt, ältester links.
    struct Regenbogen: View {
        let aussen: [String?]
        let innen: [String?]
        let e: CGFloat
        var body: some View {
            Canvas { ctx, size in
                let mitte = CGPoint(x: size.width / 2, y: size.height - 2 * e)
                zeichnen(&ctx, mitte: mitte, radius: 38 * e, breite: 7 * e, tage: aussen)
                zeichnen(&ctx, mitte: mitte, radius: 28 * e, breite: 7 * e, tage: innen)
            }
            .frame(width: 84 * e, height: 48 * e)
        }

        private func zeichnen(_ ctx: inout GraphicsContext, mitte: CGPoint, radius: CGFloat, breite: CGFloat, tage: [String?]) {
            let n = max(tage.count, 1)
            let luecke = 3.0
            for (i, roh) in tage.enumerated() {
                let von = 180.0 + 180.0 * Double(i) / Double(n)
                let bis = 180.0 + 180.0 * Double(i + 1) / Double(n) - luecke
                var pfad = Path()
                pfad.addArc(center: mitte, radius: radius, startAngle: .degrees(von), endAngle: .degrees(bis), clockwise: false)
                ctx.stroke(pfad, with: .color(ZimmerSammlungZeichnung.stimmungsfarbe(roh)), style: StrokeStyle(lineWidth: breite, lineCap: .butt))
            }
        }
    }

    // MARK: Wachstumsleiste

    struct Wachstumsleiste: View {
        let erreicht: Int
        let gesamt: Int
        let e: CGFloat
        var body: some View {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2 * e).fill(Color(red: 0.90, green: 0.82, blue: 0.62)).frame(width: 14 * e, height: 82 * e)
                    .overlay(RoundedRectangle(cornerRadius: 2 * e).stroke(ZimmerSammlungZeichnung.holz, lineWidth: 1 * e))
                ForEach(0..<max(gesamt, 1), id: \.self) { i in
                    let von_unten = CGFloat(i)
                    Capsule()
                        .fill(i < erreicht ? Color(red: 0.93, green: 0.40, blue: 0.55) : Color.gray.opacity(0.4))
                        .frame(width: (i < erreicht ? 12 : 8) * e, height: 2.4 * e)
                        .offset(x: 1 * e, y: (74 - von_unten * 15) * e)
                }
            }
            .frame(width: 16 * e, height: 84 * e, alignment: .topLeading)
            .padding(.leading, 1 * e)
        }
    }

    // MARK: Dankbarkeitsbaum

    /// Krone aus festen, deterministischen Blattplätzen (kein Zufall, kein Flackern bei Neuzeichnen).
    struct Baum: View {
        let baum: Int
        let haufen: Int
        let herbst: Bool
        let e: CGFloat
        static let plaetze: [CGPoint] = (0..<24).map { i in
            let a = Double(i) * 2.399963 // Goldener Winkel
            let r = 5.0 + 17.0 * (Double(i) / 24.0).squareRoot()
            return CGPoint(x: 22 + CGFloat(cos(a) * r), y: 20 + CGFloat(sin(a) * r * 0.85))
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                Capsule().fill(ZimmerSammlungZeichnung.holz).frame(width: 6 * e, height: 30 * e).offset(x: 19 * e, y: 26 * e)
                Circle().fill(ZimmerSammlungZeichnung.blatt.opacity(0.22)).frame(width: 44 * e, height: 38 * e).offset(y: 1 * e)
                ForEach(0..<min(baum, Self.plaetze.count), id: \.self) { i in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 6 * e))
                        .foregroundStyle(herbst ? (i % 2 == 0 ? herbst_ : ZimmerSammlungZeichnung.gold) : ZimmerSammlungZeichnung.blatt)
                        .rotationEffect(.degrees(Double(i * 47 % 360)))
                        .position(x: Self.plaetze[i].x * e, y: Self.plaetze[i].y * e)
                }
                ForEach(0..<min(haufen, 8), id: \.self) { i in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 5 * e))
                        .foregroundStyle(herbst_)
                        .rotationEffect(.degrees(Double(i * 61 % 360)))
                        .position(x: (10 + CGFloat(i) * 3.6) * e, y: (59 - CGFloat(i % 3) * 2) * e)
                }
            }
            .frame(width: 44 * e, height: 64 * e, alignment: .topLeading)
        }

        private var herbst_: Color { ZimmerSammlungZeichnung.herbst }
    }

    // MARK: Kühlschrank-Aufkleber

    struct Aufkleber: View {
        let anzahl: Int
        let e: CGFloat
        private static let farben: [Color] = [
            Color(red: 0.93, green: 0.40, blue: 0.55), Color(red: 0.98, green: 0.80, blue: 0.30),
            Color(red: 0.42, green: 0.66, blue: 0.34), Color(red: 0.55, green: 0.60, blue: 0.82),
            Color(red: 0.88, green: 0.52, blue: 0.20), Color(red: 0.70, green: 0.48, blue: 0.82),
        ]
        var body: some View {
            ZStack {
                ForEach(0..<min(anzahl, Self.farben.count), id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 6 * e))
                        .foregroundStyle(Self.farben[i])
                        .rotationEffect(.degrees(Double(i) * 18 - 30))
                        .position(x: (6 + CGFloat(i % 3) * 11) * e, y: (6 + CGFloat(i / 3) * 10) * e)
                }
            }
            .frame(width: 36 * e, height: 24 * e)
        }
    }
}
