import SwiftUI

/// Square game cover, drawn at any size: the starter grid, the chat card thumbnail and the
/// profile tally all show the same picture, so a game is recognised without reading.
struct SpielCover: View {
    let art: SpielArt

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                LinearGradient(colors: art.coverFarben, startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                motiv(s)
            }
            .frame(width: s, height: s)
            .clipShape(RoundedRectangle(cornerRadius: s * 0.22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: s * 0.22, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: max(0.5, s * 0.008)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var partner: Person { Raum.shared.ich?.partner ?? .annika }
    private var ich: Person { partner.partner }

    @ViewBuilder
    private func motiv(_ s: CGFloat) -> some View {
        switch art {
        case .duell: duell(s)
        case .xo: xo(s)
        case .ssp: ssp(s)
        case .kennen: kennen(s)
        case .reaktion: reaktion(s)
        case .memory: memory(s)
        case .eher: eher(s)
        case .wordle: wordle(s)
        case .schiffe: schiffe(s)
        }
    }

    private func symbol(_ name: String, _ groesse: CGFloat, _ farbe: Color = .white) -> some View {
        Image(systemName: name)
            .font(.system(size: groesse, weight: .bold))
            .foregroundStyle(farbe)
            .shadow(color: .black.opacity(0.18), radius: groesse * 0.08, y: groesse * 0.04)
    }

    /// Two canvases side by side, a pencil between them, a timer in the corner.
    private func duell(_ s: CGFloat) -> some View {
        ZStack {
            leinwand(s, "scribble", Color.person(ich)).rotationEffect(.degrees(-9)).offset(x: -s * 0.18, y: s * 0.08)
            leinwand(s, "scribble.variable", Color.person(partner)).rotationEffect(.degrees(9)).offset(x: s * 0.18, y: s * 0.08)
            symbol("pencil", s * 0.3).rotationEffect(.degrees(-10)).offset(y: -s * 0.02)
            symbol("timer", s * 0.17).offset(x: s * 0.29, y: -s * 0.3)
        }
    }

    private func leinwand(_ s: CGFloat, _ kritzel: String, _ farbe: Color) -> some View {
        RoundedRectangle(cornerRadius: s * 0.05, style: .continuous)
            .fill(.white)
            .frame(width: s * 0.34, height: s * 0.44)
            .overlay(Image(systemName: kritzel).font(.system(size: s * 0.17, weight: .semibold)).foregroundStyle(farbe))
            .shadow(color: .black.opacity(0.18), radius: s * 0.03, y: s * 0.015)
    }

    /// 3×3 grid, the two figure heads as marks.
    private func xo(_ s: CGFloat) -> some View {
        let g = s * 0.72, zelle = g / 3
        return ZStack {
            Path { p in
                for i in 1...2 {
                    let t = zelle * CGFloat(i)
                    p.move(to: CGPoint(x: t, y: 0)); p.addLine(to: CGPoint(x: t, y: g))
                    p.move(to: CGPoint(x: 0, y: t)); p.addLine(to: CGPoint(x: g, y: t))
                }
            }
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
            .frame(width: g, height: g)
            FigurKopf(person: ich, groesse: zelle * 0.82).offset(x: -zelle, y: -zelle)
            FigurKopf(person: partner, groesse: zelle * 0.82)
        }
    }

    private func ssp(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(.white.opacity(0.16)).frame(width: s * 0.62)
            Text("✌️").offset(y: -s * 0.2)
            Text("✊").offset(x: -s * 0.2, y: s * 0.15)
            Text("✋").offset(x: s * 0.2, y: s * 0.15)
        }
        .font(.system(size: s * 0.26))
    }

    /// Both heads, a question bubble and a heart above them.
    private func kennen(_ s: CGFloat) -> some View {
        ZStack {
            FigurKopf(person: ich, groesse: s * 0.36).offset(x: -s * 0.18, y: s * 0.17)
            FigurKopf(person: partner, groesse: s * 0.36).offset(x: s * 0.18, y: s * 0.17)
            symbol("questionmark.bubble.fill", s * 0.26).offset(x: -s * 0.14, y: -s * 0.22)
            symbol("heart.fill", s * 0.18).offset(x: s * 0.2, y: -s * 0.24)
        }
    }

    /// A lightning bolt, the partner's head popping up from the bottom edge.
    private func reaktion(_ s: CGFloat) -> some View {
        ZStack {
            symbol("bolt.fill", s * 0.4).offset(y: -s * 0.17)
            FigurKopf(person: partner, groesse: s * 0.46)
                .overlay(Circle().strokeBorder(.white, lineWidth: s * 0.025))
                .offset(y: s * 0.34)
        }
    }

    /// Two face-down cards fanned around one flipped photo card.
    private func memory(_ s: CGFloat) -> some View {
        ZStack {
            karte(s) { symbol("heart.fill", s * 0.12, .loveaRose) }.rotationEffect(.degrees(-16)).offset(x: -s * 0.2, y: s * 0.05)
            karte(s) { symbol("heart.fill", s * 0.12, .loveaRose) }.rotationEffect(.degrees(16)).offset(x: s * 0.2, y: s * 0.05)
            karte(s) {
                LinearGradient(colors: [Color(red: 0.55, green: 0.8, blue: 1), Color(red: 1, green: 0.8, blue: 0.55)], startPoint: .top, endPoint: .bottom)
                    .overlay(Image(systemName: "photo.fill").font(.system(size: s * 0.14, weight: .semibold)).foregroundStyle(.white))
                    .clipShape(RoundedRectangle(cornerRadius: s * 0.03, style: .continuous))
                    .padding(s * 0.025)
            }
            .offset(y: -s * 0.02)
        }
    }

    /// Both heads under a heart, a question bubble above.
    private func eher(_ s: CGFloat) -> some View {
        ZStack {
            FigurKopf(person: ich, groesse: s * 0.34).offset(x: -s * 0.19, y: s * 0.2)
            FigurKopf(person: partner, groesse: s * 0.34).offset(x: s * 0.19, y: s * 0.2)
            symbol("heart.fill", s * 0.2).offset(y: s * 0.2)
            symbol("hand.point.up.left.fill", s * 0.24).offset(y: -s * 0.2)
        }
    }

    /// Five letter tiles in the three Wordle colours.
    private func wordle(_ s: CGFloat) -> some View {
        let farben: [Color] = [
            Color(red: 0.33, green: 0.65, blue: 0.38), Color(red: 0.85, green: 0.66, blue: 0.2),
            Color(red: 0.36, green: 0.37, blue: 0.4), Color(red: 0.33, green: 0.65, blue: 0.38),
            Color(red: 0.85, green: 0.66, blue: 0.2),
        ]
        let buchstaben = Array("LIEBE")
        let kachel = s * 0.15
        return VStack(spacing: s * 0.03) {
            ForEach(0..<2, id: \.self) { reihe in
                HStack(spacing: s * 0.03) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: s * 0.025, style: .continuous)
                            .fill(reihe == 0 ? farben[(i + 2) % 5] : farben[i])
                            .frame(width: kachel, height: kachel)
                            .overlay(
                                Text(reihe == 0 ? "" : String(buchstaben[i]))
                                    .font(.system(size: kachel * 0.6, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: .black.opacity(0.15), radius: s * 0.01, y: s * 0.008)
                    }
                }
            }
        }
    }

    /// A ship with a wake on the water and a hit marker.
    private func schiffe(_ s: CGFloat) -> some View {
        ZStack {
            Capsule().fill(.white.opacity(0.25)).frame(width: s * 0.7, height: s * 0.07).offset(y: s * 0.27)
            Capsule().fill(.white.opacity(0.15)).frame(width: s * 0.5, height: s * 0.05).offset(y: s * 0.35)
            symbol("ferry.fill", s * 0.42).offset(y: s * 0.03)
            symbol("scope", s * 0.2, Color(red: 1, green: 0.85, blue: 0.4)).offset(x: s * 0.22, y: -s * 0.24)
        }
    }

    private func karte<Inhalt: View>(_ s: CGFloat, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        RoundedRectangle(cornerRadius: s * 0.05, style: .continuous)
            .fill(.white)
            .frame(width: s * 0.3, height: s * 0.42)
            .overlay(inhalt())
            .shadow(color: .black.opacity(0.2), radius: s * 0.03, y: s * 0.015)
    }
}

extension SpielArt {
    fileprivate var coverFarben: [Color] {
        switch self {
        case .duell: [Color(red: 1, green: 0.62, blue: 0.27), Color(red: 0.95, green: 0.3, blue: 0.45)]
        case .xo: [Color(red: 0.36, green: 0.42, blue: 0.96), Color(red: 0.2, green: 0.64, blue: 0.98)]
        case .ssp: [Color(red: 0.2, green: 0.8, blue: 0.62), Color(red: 0.08, green: 0.54, blue: 0.74)]
        case .kennen: [Color(red: 1, green: 0.42, blue: 0.6), Color(red: 0.6, green: 0.34, blue: 0.94)]
        case .reaktion: [Color(red: 1, green: 0.8, blue: 0.2), Color(red: 0.98, green: 0.44, blue: 0.2)]
        case .memory: [Color(red: 0.36, green: 0.84, blue: 0.94), Color(red: 0.3, green: 0.48, blue: 0.95)]
        case .eher: [Color(red: 0.98, green: 0.45, blue: 0.55), Color(red: 0.95, green: 0.62, blue: 0.3)]
        case .wordle: [Color(red: 0.22, green: 0.25, blue: 0.34), Color(red: 0.12, green: 0.14, blue: 0.22)]
        case .schiffe: [Color(red: 0.15, green: 0.5, blue: 0.75), Color(red: 0.05, green: 0.25, blue: 0.5)]
        }
    }
}
