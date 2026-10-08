import SwiftUI

/// p63: das Erinnerungsalbum im Regal. Ein Blatt je Monat aus gespeicherten Snaps und den Chat-Highlights
/// (gemerkte und angeheftete Nachrichten). Liebesbriefe (p60) sind noch nicht dabei. Nur lesen, nichts doppelt speichern.
struct AlbumFoto: Equatable, Identifiable, Sendable {
    let medium: ChatModell.MedienEintrag
    let eigene: Bool
    var id: String { medium.id }
}

struct AlbumSatz: Equatable, Identifiable, Sendable {
    let id: String
    let text: String
    let von: Person
}

struct AlbumMonat: Equatable, Identifiable, Sendable {
    /// `yyyy-MM`
    let id: String
    let titel: String
    let fotos: [AlbumFoto]
    let saetze: [AlbumSatz]
}

enum ZimmerAlbumLogik {
    static let maxFotos = 4
    static let maxSaetze = 3

    /// Die Monatsblätter, ältester Monat zuerst. Monate ohne Foto und ohne Satz fehlen.
    /// Je Monat gewinnen die neuesten Einträge (höchstens `maxFotos` und `maxSaetze`).
    static func monate(aus nachrichten: [ChatModell.Nachricht], ich: Person?) -> [AlbumMonat] {
        let k = Calendar.berlin
        var fotos: [String: [AlbumFoto]] = [:]
        var saetze: [String: [AlbumSatz]] = [:]
        var erster: [String: Date] = [:]
        for n in nachrichten.sorted(by: { $0.zeit > $1.zeit }) where !n.geloescht && n.system == nil {
            let c = k.dateComponents([.year, .month], from: n.zeit)
            let schluessel = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            let gemerkt = !n.gemerkt.isEmpty || n.angeheftet
            let snapFoto = n.snap.map { n.snapGespeichert || $0.bleibt } ?? false
            if (snapFoto || gemerkt), let m = n.medien.first(where: { $0.typ == "foto" }) {
                if (fotos[schluessel]?.count ?? 0) < maxFotos { fotos[schluessel, default: []].append(AlbumFoto(medium: m, eigene: n.von == ich)) }
                erster[schluessel] = n.zeit
            }
            if gemerkt, n.snap == nil, let t = n.text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                if (saetze[schluessel]?.count ?? 0) < maxSaetze { saetze[schluessel, default: []].append(AlbumSatz(id: n.id, text: t, von: n.von)) }
                erster[schluessel] = n.zeit
            }
        }
        return erster.keys.sorted().compactMap { s in
            guard let zeit = erster[s] else { return nil }
            return AlbumMonat(id: s, titel: monatsTitel(zeit), fotos: fotos[s] ?? [], saetze: saetze[s] ?? [])
        }
    }

    static func monatsTitel(_ datum: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = Calendar.berlin.timeZone
        f.dateFormat = "LLLL yyyy"
        return f.string(from: datum)
    }
}

// MARK: - Zeichnung

enum ZimmerAlbumZeichnung {
    /// Die Bücher auf dem Regal: links angelehnt das Album, daneben zwei Buchrücken. `fuss`: Mitte der Unterkante.
    static func zeichne(_ g: GraphicsContext, fuss f: CGPoint) {
        let rot = Pal.rose.mix(Pal.weiss, 0.12)
        let buecher: [(dx: CGFloat, h: CGFloat, b: CGFloat, farbe: FigurFarbe)] = [
            (14, 25, 6, Pal.himmel), (20.5, 29, 5.5, Pal.mint),
        ]
        for b in buecher {
            teil(g, box(f.x + b.dx, f.y - b.h, b.b, b.h, 1.2), b.farbe, 1.2)
            linie(g, strich(P(f.x + b.dx + 1.4, f.y - b.h + 5), P(f.x + b.dx + b.b - 1.4, f.y - b.h + 5)), .white.opacity(0.8), 0.9)
        }
        // Das Album: dicker Einband mit Herz, leicht geneigt, Seitenschnitt rechts.
        var a = g
        a.translateBy(x: f.x, y: f.y)
        a.rotate(by: .degrees(-6))
        teil(a, box(-12, -30, 26, 30, 2), Pal.weiss.mal(0.93), 1.2)
        teil(a, box(-14, -31, 26, 30, 2.4), rot, 1.5)
        linie(a, strich(P(-10.6, -29), P(-10.6, -2)), rot.mal(0.7).farbe, 1.1)
        teil(a, herzPfad(P(1.2, -17), 5.6), Pal.weiss, 0.9)
        a.fill(box(-8, -9, 17, 2.4, 1), with: .color(.white.opacity(0.7)))
        a.fill(box(-8, -5.4, 12, 2, 1), with: .color(.white.opacity(0.5)))
    }
}

// MARK: - Blatt

/// Das Buch: eine Seite je Monat, durch Wischen blättern.
struct ZimmerAlbumBlatt: View {
    @State private var monate: [AlbumMonat]
    @State private var seite: String?

    init(nachrichten: [ChatModell.Nachricht], ich: Person?) {
        let m = ZimmerAlbumLogik.monate(aus: nachrichten, ich: ich)
        _monate = State(initialValue: m)
        _seite = State(initialValue: m.last?.id)
    }

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.96, blue: 0.91).ignoresSafeArea()
            if monate.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(Color.loveaRose)
                    Text("Noch leer").font(.headline)
                    Text("Gemerkte Nachrichten und gespeicherte Snaps landen hier, ein Blatt je Monat.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                VStack(spacing: 6) {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(monate) { m in
                                ZimmerAlbumSeite(monat: m)
                                    .containerRelativeFrame(.horizontal)
                                    .id(m.id)
                                    .scrollTransition(axis: .horizontal) { inhalt, phase in
                                        inhalt
                                            .rotation3DEffect(.degrees(phase.value * -32), axis: (x: 0, y: 1, z: 0), anchor: phase.value < 0 ? .trailing : .leading, perspective: 0.5)
                                            .opacity(1 - abs(phase.value) * 0.35)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $seite)
                    .scrollIndicators(.hidden)
                    Text(zaehler).font(.caption).foregroundStyle(.secondary).padding(.bottom, 10)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var zaehler: String {
        let i = monate.firstIndex { $0.id == seite } ?? monate.count - 1
        return "\(i + 1) von \(monate.count)"
    }
}

struct ZimmerAlbumSeite: View {
    let monat: AlbumMonat

    var body: some View {
        VStack(spacing: 18) {
            Text(monat.titel)
                .font(.system(.title, design: .serif).weight(.semibold))
                .padding(.top, 28)
            if !monat.fotos.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(Array(monat.fotos.enumerated()), id: \.element.id) { n, foto in
                        MedienKachel(medium: foto.medium, eigene: foto.eigene)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                            .background(.white, in: RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            .rotationEffect(.degrees(n % 2 == 0 ? -2 : 2))
                    }
                }
                .padding(.horizontal, 28)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(monat.saetze) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\u{201E}\(s.text)\u{201C}").font(.system(.body, design: .serif)).italic().lineLimit(3)
                        Text(s.von.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
    }
}
