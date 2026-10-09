import SwiftUI

/// Kleine Bilder für die Paar-Rituale (Worker D). Alles aus einfachen SwiftUI-Formen in Entwurfseinheiten
/// (`e` = Punkte je Entwurfseinheit), ohne Takt und ohne Animationsschleife.
enum ZimmerRitualeZeichnung {
    static let stoff = Color(red: 0.93, green: 0.62, blue: 0.66)
    static let stoffDunkel = Color(red: 0.80, green: 0.45, blue: 0.52)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.28)
    static let glas = Color.white.opacity(0.35)
    static let glasRand = Color.white.opacity(0.75)

    /// Ein Vorhang-Flügel: Stoff mit zwei Falten.
    struct Vorhang: View {
        let breite: CGFloat
        let hoehe: CGFloat

        var body: some View {
            ZStack {
                UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3).fill(stoff)
                HStack(spacing: breite / 4) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(stoffDunkel.opacity(0.45)).frame(width: max(1, breite / 14))
                    }
                }
            }
            .frame(width: breite, height: hoehe)
            .accessibilityHidden(true)
        }
    }

    /// Weicher Lichtstrahl vom Fenster in den Raum. Nimmt keine Taps an.
    struct Sonnenstrahl: View {
        let breite: CGFloat
        let hoehe: CGFloat

        var body: some View {
            Path { p in
                p.move(to: CGPoint(x: breite * 0.1, y: 0))
                p.addLine(to: CGPoint(x: breite * 0.9, y: 0))
                p.addLine(to: CGPoint(x: breite, y: hoehe))
                p.addLine(to: CGPoint(x: -breite * 0.1, y: hoehe))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [gold.opacity(0.32), gold.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: breite, height: hoehe)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Kleines Nachtlicht (Mond-Lampe), leuchtet, wenn jemand Gute Nacht gesagt hat.
    struct Nachtlicht: View {
        let an: Bool
        let e: CGFloat

        var body: some View {
            ZStack {
                if an { Circle().fill(gold.opacity(0.28)).frame(width: 44 * e, height: 44 * e) }
                Circle().fill(an ? gold : Color.gray.opacity(0.55)).frame(width: 20 * e, height: 20 * e)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 11 * e))
                    .foregroundStyle(Color.white.opacity(an ? 0.9 : 0.6))
            }
            .frame(width: 44 * e, height: 44 * e)
            .accessibilityHidden(true)
        }
    }

    /// Einmachglas mit Herzen: Kussglas (rosa) oder Wunschglas (Sterne, erfüllte golden).
    struct Glas: View {
        let herzen: Int
        let leuchtet: Bool
        let e: CGFloat

        var body: some View {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6 * e).fill(glas)
                RoundedRectangle(cornerRadius: 6 * e).stroke(leuchtet ? Color.loveaRose : glasRand, lineWidth: leuchtet ? 2 : 1)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(8 * e), spacing: 0), count: 4), spacing: 0) {
                    ForEach(0..<herzen, id: \.self) { _ in
                        Image(systemName: "heart.fill").font(.system(size: 7 * e)).foregroundStyle(Color.loveaRose)
                    }
                }
                .frame(width: 34 * e, alignment: .bottom)
                .padding(.bottom, 4 * e)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 2 * e).fill(stoffDunkel).frame(width: 26 * e, height: 6 * e).offset(y: -5 * e)
            }
            .frame(width: 38 * e, height: 44 * e)
            .shadow(color: leuchtet ? Color.loveaRose.opacity(0.7) : .clear, radius: 8)
            .accessibilityHidden(true)
        }
    }

    struct Wunschglas: View {
        let wuensche: Int
        let gold: Int
        let e: CGFloat

        var body: some View {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6 * e).fill(ZimmerRitualeZeichnung.glas)
                RoundedRectangle(cornerRadius: 6 * e).stroke(ZimmerRitualeZeichnung.glasRand, lineWidth: 1)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(8 * e), spacing: 0), count: 4), spacing: 0) {
                    ForEach(0..<min(wuensche, 16), id: \.self) { i in
                        Image(systemName: "star.fill").font(.system(size: 7 * e))
                            .foregroundStyle(i < gold ? ZimmerRitualeZeichnung.gold : Color.white.opacity(0.8))
                    }
                }
                .frame(width: 34 * e, alignment: .bottom)
                .padding(.bottom, 4 * e)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 2 * e).fill(ZimmerRitualeZeichnung.stoffDunkel).frame(width: 26 * e, height: 6 * e).offset(y: -5 * e)
            }
            .frame(width: 38 * e, height: 44 * e)
            .accessibilityHidden(true)
        }
    }

    /// Glückskeks, geöffnet, wenn beide heute geantwortet haben.
    struct Keks: View {
        let offen: Bool
        let e: CGFloat

        var body: some View {
            ZStack {
                Ellipse().fill(Color(red: 0.95, green: 0.78, blue: 0.45)).frame(width: 30 * e, height: 20 * e)
                Ellipse().stroke(Color(red: 0.75, green: 0.52, blue: 0.22), lineWidth: 1).frame(width: 30 * e, height: 20 * e)
                if offen {
                    Rectangle().fill(Color.white).frame(width: 14 * e, height: 5 * e).rotationEffect(.degrees(-12)).offset(y: -9 * e)
                }
            }
            .frame(width: 44 * e, height: 36 * e)
            .accessibilityHidden(true)
        }
    }

    /// Teekanne mit zwei Tassen, die sich füllen.
    struct Tee: View {
        let gemacht: Bool
        let e: CGFloat

        var body: some View {
            HStack(alignment: .bottom, spacing: 3 * e) {
                tasse
                ZStack {
                    RoundedRectangle(cornerRadius: 7 * e).fill(Color(red: 0.55, green: 0.70, blue: 0.78)).frame(width: 22 * e, height: 18 * e)
                    Capsule().fill(Color(red: 0.40, green: 0.55, blue: 0.64)).frame(width: 9 * e, height: 4 * e).offset(y: -10 * e)
                    if gemacht {
                        Image(systemName: "heart.fill").font(.system(size: 7 * e)).foregroundStyle(.white.opacity(0.9))
                    }
                }
                tasse
            }
            .frame(width: 64 * e, height: 44 * e, alignment: .bottom)
            .accessibilityHidden(true)
        }

        private var tasse: some View {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3 * e).fill(Color.white.opacity(0.9)).frame(width: 12 * e, height: 11 * e)
                if gemacht {
                    RoundedRectangle(cornerRadius: 2 * e).fill(Color(red: 0.72, green: 0.45, blue: 0.22)).frame(width: 9 * e, height: 6 * e).padding(.bottom, 1)
                }
            }
        }
    }
}
