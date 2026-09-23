import SwiftUI

/// Z-25.2/Z-23.3: profile backgrounds — ≥12 free ones plus the catalog's 8 purchased `backdrop.*`
/// items (2 animated). Free ids are prefixed `frei.` so they never collide with `backdrop.*`;
/// `profil.hintergrund.id` (Profile/ProfilHintergrund.swift) can hold either kind.
enum BackdropStil: Sendable { case verlauf, sonne, berge, sterne, wolken, wellen, punkte, streifen }

struct BackdropEintrag: Identifiable, Sendable {
    let id: String
    let name: String
    let farben: [FigurFarbe]
    var stil: BackdropStil = .verlauf
    var animiert = false
}

enum BackdropKatalog {
    static let kostenlos: [BackdropEintrag] = [
        BackdropEintrag(id: "frei.sonnenuntergang-berge", name: "Sonnenuntergang über Bergen",
                         farben: [FigurFarbe(0xC23A6B), FigurFarbe(0xE8703C), FigurFarbe(0xF2A65A)], stil: .berge),
        BackdropEintrag(id: "frei.pastell-himmel", name: "Pastell-Himmel",
                         farben: [FigurFarbe(0xF7B6C8), FigurFarbe(0x9B7BD8)]),
        BackdropEintrag(id: "frei.mintgruen", name: "Mint-Verlauf",
                         farben: [FigurFarbe(0x8ED8BE), FigurFarbe(0x3F7D52)]),
        BackdropEintrag(id: "frei.sternennacht", name: "Sternennacht",
                         farben: [FigurFarbe(0x221C1C), FigurFarbe(0x2C3E6B)], stil: .sterne),
        BackdropEintrag(id: "frei.strand", name: "Strand am Mittag",
                         farben: [FigurFarbe(0x7FB6E8), FigurFarbe(0xF5CE5A)], stil: .wellen),
        BackdropEintrag(id: "frei.konfetti", name: "Konfetti",
                         farben: [FigurFarbe(0xFF3B5C), FigurFarbe(0xF5C542)], stil: .punkte),
        BackdropEintrag(id: "frei.lavendelfeld", name: "Lavendelfeld",
                         farben: [FigurFarbe(0x9B7BD8), FigurFarbe(0xF7B6C8)], stil: .streifen),
        BackdropEintrag(id: "frei.sonnengelb", name: "Sonnengelb",
                         farben: [FigurFarbe(0xF5CE5A), FigurFarbe(0xF08A4B)], stil: .sonne),
        BackdropEintrag(id: "frei.waldgruen", name: "Waldgrün",
                         farben: [FigurFarbe(0x5DBB7A), FigurFarbe(0x221C1C)], stil: .berge),
        BackdropEintrag(id: "frei.rosegold", name: "Rosé Gold",
                         farben: [FigurFarbe(0xF5C542), FigurFarbe(0xF7B6C8)]),
        BackdropEintrag(id: "frei.ozeanblau", name: "Ozeanblau",
                         farben: [FigurFarbe(0x2C3E6B), FigurFarbe(0x7FB6E8)], stil: .wellen),
        BackdropEintrag(id: "frei.beerenmix", name: "Beerenmix",
                         farben: [FigurFarbe(0x6B2A4A), FigurFarbe(0xFF3B5C)], stil: .streifen),
    ]

    /// One entry per `ShopKatalog` `backdrop.*` id (`ShopKatalogTests.testAlleTeileHabenEineZeichnungOderZuordnung`).
    static let gekauft: [BackdropEintrag] = [
        BackdropEintrag(id: "backdrop.stadt-nacht", name: "Stadt bei Nacht",
                         farben: [FigurFarbe(0x1A1830), FigurFarbe(0x3D2A5A)], stil: .sterne),
        BackdropEintrag(id: "backdrop.strand", name: "Strand-Sonnenuntergang",
                         farben: [FigurFarbe(0xF08A4B), FigurFarbe(0xFF3B5C)], stil: .wellen),
        BackdropEintrag(id: "backdrop.regen-fenster", name: "Regen am Fenster",
                         farben: [FigurFarbe(0x6D7B86), FigurFarbe(0x2C3E6B)], stil: .streifen),
        BackdropEintrag(id: "backdrop.neon", name: "Neon-Skyline",
                         farben: [FigurFarbe(0x221C1C), FigurFarbe(0x9B7BD8)], stil: .berge),
        BackdropEintrag(id: "backdrop.konfetti", name: "Konfetti-Party",
                         farben: [FigurFarbe(0x9B7BD8), FigurFarbe(0xF5C542)], stil: .punkte),
        BackdropEintrag(id: "backdrop.wolken-animiert", name: "Wolken (animiert)",
                         farben: [FigurFarbe(0x7FB6E8), FigurFarbe(0xF4F1EE)], stil: .wolken, animiert: true),
        BackdropEintrag(id: "backdrop.sternenhimmel-animiert", name: "Sternenhimmel (animiert)",
                         farben: [FigurFarbe(0x0A0E2A), FigurFarbe(0x2C3E6B)], stil: .sterne, animiert: true),
        BackdropEintrag(id: "backdrop.herbstwald", name: "Herbstwald",
                         farben: [FigurFarbe(0xB5552B), FigurFarbe(0x7A5234)], stil: .berge),
    ]

    private static let nachId: [String: BackdropEintrag] = Dictionary(uniqueKeysWithValues: (kostenlos + gekauft).map { ($0.id, $0) })
    static func eintrag(_ id: String) -> BackdropEintrag? { nachId[id] }
}

/// Draws one backdrop by id, or a plain Lovea gradient fallback for `nil`/an unknown id.
struct BackdropView: View {
    let id: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var eintrag: BackdropEintrag? { id.flatMap(BackdropKatalog.eintrag) }

    var body: some View {
        ZStack { verlauf; akzent }
            .clipped()
            .accessibilityHidden(true)
    }

    private var verlauf: some View {
        let farben = (eintrag?.farben ?? [FigurFarbe(0x6B2A4A), FigurFarbe(0x9B7BD8)]).map(\.farbe)
        return LinearGradient(colors: farben, startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder private var akzent: some View {
        if let eintrag {
            let animiert = eintrag.animiert && !reduceMotion
            switch eintrag.stil {
            case .verlauf: EmptyView()
            case .sonne: SonnenKreis()
            case .berge: BergSilhouette(farbe: eintrag.farben.last?.mal(0.45).farbe ?? .black.opacity(0.4))
            case .sterne: SternenFeld(animiert: animiert)
            case .wolken: WolkenFeld(animiert: animiert)
            case .wellen: WellenBand()
            case .punkte: PunkteFeld()
            case .streifen: StreifenBand()
            }
        }
    }
}

private struct SonnenKreis: View {
    var body: some View {
        Circle().fill(.white.opacity(0.5)).frame(width: 70, height: 70).offset(y: -40)
    }
}

private struct BergSilhouette: View {
    let farbe: Color
    var body: some View {
        GeometryReader { p in
            Path { path in
                let w = p.size.width, h = p.size.height
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h * 0.72))
                path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.5))
                path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.68))
                path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.42))
                path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.66))
                path.addLine(to: CGPoint(x: w, y: h * 0.55))
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
            }
            .fill(farbe)
        }
    }
}

/// Deterministic, fixed positions (no per-render RNG) so the star field doesn't jitter on redraw.
private struct SternenFeld: View {
    let animiert: Bool
    @State private var hell = false
    private static let positionen: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.15, 3), (0.22, 0.3, 2), (0.35, 0.1, 2.5), (0.5, 0.22, 3.5), (0.62, 0.08, 2),
        (0.75, 0.28, 3), (0.88, 0.14, 2.5), (0.15, 0.42, 2), (0.45, 0.4, 2.5), (0.7, 0.45, 2),
        (0.9, 0.4, 3), (0.3, 0.55, 2),
    ]

    var body: some View {
        GeometryReader { p in
            ForEach(Array(Self.positionen.enumerated()), id: \.offset) { i, punkt in
                Circle()
                    .fill(.white.opacity(animiert ? (hell ? 0.95 : 0.35) : 0.85))
                    .frame(width: punkt.2, height: punkt.2)
                    .position(x: p.size.width * punkt.0, y: p.size.height * punkt.1)
                    .animation(animiert ? .easeInOut(duration: 1.3).repeatForever().delay(Double(i) * 0.15) : nil, value: hell)
            }
        }
        .onAppear { if animiert { hell = true } }
    }
}

private struct WolkenForm: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.3, width: rect.width * 0.6, height: rect.height * 0.7))
        p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.3, y: rect.minY, width: rect.width * 0.7, height: rect.height))
        p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.25, width: rect.width * 0.5, height: rect.height * 0.75))
        return p
    }
}

private struct WolkenFeld: View {
    let animiert: Bool
    @State private var verschoben = false
    private static let wolken: [(CGFloat, CGFloat, CGFloat)] = [(0.15, 0.25, 60), (0.55, 0.15, 80), (0.8, 0.35, 50)]

    var body: some View {
        GeometryReader { p in
            ForEach(Array(Self.wolken.enumerated()), id: \.offset) { i, w in
                WolkenForm()
                    .fill(.white.opacity(0.8))
                    .frame(width: w.2, height: w.2 * 0.5)
                    .position(x: p.size.width * w.0 + (verschoben ? 16 : -16), y: p.size.height * w.1)
                    .animation(animiert ? .easeInOut(duration: 5 + Double(i)).repeatForever(autoreverses: true) : nil, value: verschoben)
            }
        }
        .onAppear { if animiert { verschoben = true } }
    }
}

private struct WellenBand: View {
    var body: some View {
        GeometryReader { p in
            Path { path in
                let w = p.size.width, h = p.size.height
                let basisY = h * 0.8
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: basisY))
                path.addCurve(to: CGPoint(x: w, y: basisY - 6), control1: CGPoint(x: w * 0.3, y: basisY + 14), control2: CGPoint(x: w * 0.7, y: basisY - 20))
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
            }
            .fill(.white.opacity(0.22))
        }
    }
}

private struct PunkteFeld: View {
    private static let punkte: [(CGFloat, CGFloat, FigurFarbe)] = [
        (0.1, 0.2, Pal.weiss), (0.3, 0.1, Pal.gelb), (0.5, 0.25, Pal.weiss),
        (0.7, 0.12, Pal.gruen), (0.85, 0.22, Pal.weiss), (0.2, 0.4, Pal.himmel),
        (0.45, 0.45, Pal.weiss), (0.65, 0.38, Pal.rose), (0.9, 0.42, Pal.weiss),
        (0.35, 0.6, Pal.gelb), (0.6, 0.65, Pal.weiss), (0.15, 0.65, Pal.gruen),
    ]

    var body: some View {
        GeometryReader { p in
            ForEach(Array(Self.punkte.enumerated()), id: \.offset) { _, punkt in
                Circle().fill(punkt.2.farbe.opacity(0.85)).frame(width: 8, height: 8)
                    .position(x: p.size.width * punkt.0, y: p.size.height * punkt.1)
            }
        }
    }
}

private struct StreifenBand: View {
    var body: some View {
        GeometryReader { p in
            ForEach(0..<6, id: \.self) { i in
                Rectangle().fill(.white.opacity(0.08))
                    .frame(width: p.size.width * 1.4, height: 14)
                    .rotationEffect(.degrees(-18))
                    .position(x: p.size.width * 0.5, y: p.size.height * (0.15 + Double(i) * 0.16))
            }
        }
    }
}
