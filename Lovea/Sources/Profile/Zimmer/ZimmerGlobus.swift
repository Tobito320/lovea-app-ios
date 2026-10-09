import SwiftUI

/// p63: der Globus mit der Wunschliste. Die Orte sind die Date-Ideen mit Ort (oder Kategorie Reisen):
/// abgehakt = besucht, der Pin leuchtet. Kein eigenes Modell, kein Sync: Abhaken geht über `DateSpeicher`.
struct GlobusPin: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let besucht: Bool
}

enum ZimmerGlobus {
    /// Die Wunschliste: Ideen mit Ort oder aus der Kategorie Reisen, offene zuerst.
    static func wunschliste(_ ideen: [DateIdee]) -> [DateIdee] {
        let liste = ideen.filter { !$0.geloescht && ($0.ort != nil || $0.kategorie == .reisen) }
        return liste.filter { !$0.erledigt } + liste.filter(\.erledigt)
    }

    /// Nur was eine Koordinate hat, kann auf der Kugel stehen.
    static func pins(_ ideen: [DateIdee]) -> [GlobusPin] {
        wunschliste(ideen).compactMap { i in
            guard let ort = i.ort, DateLogik.hatKoordinate(ort) else { return nil }
            return GlobusPin(id: i.id, name: ort.name.isEmpty ? i.titel : ort.name, lat: ort.lat, lon: ort.lon, besucht: i.erledigt)
        }
    }

    static let europa: (lat: Double, lon: Double) = (50, 10)

    /// Wohin der Globus schaut: der Mittelwert der Pins auf der Kugel (nicht der Zahlen, sonst wäre
    /// der Mittelwert von 170 und -170 Grad bei 0). Ohne Pins: Europa.
    static func mitte(_ pins: [GlobusPin]) -> (lat: Double, lon: Double) {
        guard !pins.isEmpty else { return europa }
        var x = 0.0, y = 0.0, z = 0.0
        for p in pins {
            let b = p.lat * .pi / 180, l = p.lon * .pi / 180
            x += cos(b) * cos(l)
            y += cos(b) * sin(l)
            z += sin(b)
        }
        guard (x * x + y * y + z * z).squareRoot() > 1e-6 else { return europa }
        return (atan2(z, hypot(x, y)) * 180 / .pi, atan2(y, x) * 180 / .pi)
    }

    /// Senkrechte Projektion: Mitte der Kugel (0, 0), Rand bei Länge 1, y nach oben. `vorn`: sichtbare Seite.
    static func projiziere(lat: Double, lon: Double, mitte m: (lat: Double, lon: Double)) -> (x: Double, y: Double, vorn: Bool) {
        let p = lat * .pi / 180, p0 = m.lat * .pi / 180, dl = (lon - m.lon) * .pi / 180
        let x = cos(p) * sin(dl)
        let y = cos(p0) * sin(p) - sin(p0) * cos(p) * cos(dl)
        let z = sin(p0) * sin(p) + cos(p0) * cos(p) * cos(dl)
        return (x, y, z > 0)
    }

    /// Grobe Umrisse (Breite, Länge), mehr braucht eine Kugel von 30 bis 220 Punkt nicht.
    static let kontinente: [[(Double, Double)]] = [
        // Eurasien
        [(37, -9), (43, -9), (43, -2), (48, -5), (51, 2), (54, 8), (57, 10), (56, 13), (55, 21), (60, 23), (60, 30), (66, 24), (70, 28),
         (71, 40), (73, 60), (76, 100), (72, 130), (68, 170), (62, 165), (60, 150), (55, 137), (50, 140), (43, 132), (39, 127), (35, 129),
         (30, 122), (22, 114), (20, 108), (10, 107), (9, 100), (1, 104), (8, 98), (16, 94), (22, 90), (20, 86), (8, 78), (21, 72), (24, 67),
         (26, 57), (30, 48), (24, 52), (24, 56), (17, 55), (13, 45), (21, 39), (28, 34), (31, 34), (36, 36), (37, 27), (40, 22), (44, 9),
         (43, 3), (37, -1)],
        // Afrika
        [(35, -6), (37, 10), (32, 32), (22, 37), (12, 44), (11, 51), (0, 42), (-10, 40), (-26, 33), (-34, 26), (-34, 18), (-22, 14),
         (-10, 13), (4, 9), (5, -5), (8, -13), (15, -17), (21, -17), (28, -13)],
        // Nordamerika
        [(60, -165), (70, -155), (70, -125), (68, -95), (62, -92), (55, -80), (60, -70), (52, -56), (47, -53), (44, -66), (41, -70),
         (35, -76), (30, -81), (25, -80), (30, -88), (29, -95), (22, -98), (18, -95), (21, -87), (16, -88), (9, -83), (15, -92), (20, -105),
         (31, -114), (32, -117), (40, -124), (48, -124), (58, -136), (60, -148), (56, -160)],
        // Südamerika
        [(12, -72), (10, -62), (5, -52), (-1, -48), (-7, -35), (-13, -38), (-23, -42), (-35, -57), (-41, -62), (-54, -68), (-52, -74),
         (-42, -73), (-30, -71), (-18, -70), (-5, -81), (2, -79), (8, -77)],
        // Australien
        [(-11, 132), (-12, 142), (-19, 147), (-28, 153), (-38, 147), (-35, 137), (-32, 127), (-35, 117), (-22, 114), (-15, 124)],
        // Grönland und Großbritannien
        [(60, -44), (70, -22), (83, -30), (83, -60), (76, -70), (68, -54)],
        [(50, -5), (51, 1), (54, 0), (58, -3), (58, -6), (54, -5), (52, -5)],
    ]
}

// MARK: - Zeichnung

enum ZimmerGlobusZeichnung {
    /// Die Kugel mit Land, Schatten und Pins. Besuchte Pins leuchten gold, offene sind rosa Punkte.
    static func zeichne(_ g: GraphicsContext, mitte m: CGPoint, radius r: CGFloat, zentrum: (lat: Double, lon: Double), pins: [GlobusPin]) {
        let kugel = kreis(m, r)
        let meer = Pal.himmel
        g.fill(kugel, with: .radialGradient(Gradient(colors: [meer.mix(Pal.weiss, 0.4).farbe, meer.farbe]),
                                            center: P(m.x - r * 0.35, m.y - r * 0.4), startRadius: 0, endRadius: r * 1.5))
        var k = g
        k.clip(to: kugel)
        for umriss in ZimmerGlobus.kontinente {
            let pfad = Path { p in
                for (n, punkt) in umriss.enumerated() {
                    let q = ZimmerGlobus.projiziere(lat: punkt.0, lon: punkt.1, mitte: zentrum)
                    var x = q.x, y = q.y
                    if !q.vorn {
                        let l = max(hypot(x, y), 1e-6)
                        x /= l
                        y /= l
                    }
                    let c = P(m.x + CGFloat(x) * r, m.y - CGFloat(y) * r)
                    if n == 0 { p.move(to: c) } else { p.addLine(to: c) }
                }
                p.closeSubpath()
            }
            k.fill(pfad, with: .color(Pal.gruen.farbe))
            k.stroke(pfad, with: .color(Pal.gruen.mal(0.7).farbe), style: StrokeStyle(lineWidth: max(0.7, r * 0.02), lineJoin: .round))
        }
        k.fill(kugel, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.3)]),
                                            center: P(m.x - r * 0.3, m.y - r * 0.35), startRadius: r * 0.5, endRadius: r * 1.25))
        g.stroke(kugel, with: .color(meer.mal(0.55).farbe), style: StrokeStyle(lineWidth: max(1, r * 0.045)))
        for pin in pins {
            let q = ZimmerGlobus.projiziere(lat: pin.lat, lon: pin.lon, mitte: zentrum)
            guard q.vorn else { continue }
            let c = P(m.x + CGFloat(q.x) * r, m.y - CGFloat(q.y) * r)
            let punkt = max(1.4, r * 0.055)
            if pin.besucht {
                g.fill(kreis(c, punkt * 3.6), with: .radialGradient(Gradient(colors: [Pal.gelb.farbe.opacity(0.85), .clear]),
                                                                    center: c, startRadius: 0, endRadius: punkt * 3.6))
                g.fill(kreis(c, punkt), with: .color(Pal.gelb.farbe))
            } else {
                g.fill(kreis(c, punkt), with: .color(Pal.rose.farbe))
            }
            g.stroke(kreis(c, punkt), with: .color(.white), style: StrokeStyle(lineWidth: max(0.6, punkt * 0.4)))
        }
    }

    /// Der kleine Globus im Regal: Kugel im Ring auf einem Fuß.
    static func zeichneImRegal(_ g: GraphicsContext, mitte m: CGPoint, radius r: CGFloat, zentrum: (lat: Double, lon: Double), pins: [GlobusPin]) {
        let holz = Pal.holz
        teil(g, box(m.x - r * 0.55, m.y + r + 2, r * 1.1, 3.4, 1.6), holz, 1.2)
        linie(g, strich(P(m.x, m.y + r), P(m.x, m.y + r + 3)), holz.mal(0.6).farbe, 1.6)
        zeichne(g, mitte: m, radius: r, zentrum: zentrum, pins: pins)
        let ring = Path { p in p.addArc(center: m, radius: r + 2.2, startAngle: .degrees(120), endAngle: .degrees(-150), clockwise: true) }
        linie(g, ring, Pal.gold.mal(0.8).farbe, 1.4)
    }
}

// MARK: - Blatt

/// Das Blatt zum Globus: drehbar mit dem Finger, darunter die Wunschliste zum Abhaken.
struct ZimmerGlobusBlatt: View {
    private let speicher = DateSpeicher.shared
    @State private var lat = ZimmerGlobus.europa.lat
    @State private var lon = ZimmerGlobus.europa.lon
    @State private var anker: (lat: Double, lon: Double)?

    var body: some View {
        let ideen = speicher.ideen
        let pins = ZimmerGlobus.pins(ideen)
        let liste = ZimmerGlobus.wunschliste(ideen)
        let besucht = liste.filter(\.erledigt).count
        VStack(spacing: 10) {
            Text("Wunschliste").font(.headline).padding(.top, 20)
            Canvas { g, groesse in
                ZimmerGlobusZeichnung.zeichne(g, mitte: CGPoint(x: groesse.width / 2, y: groesse.height / 2),
                                              radius: min(groesse.width, groesse.height) / 2 - 6, zentrum: (lat: lat, lon: lon), pins: pins)
            }
            .frame(height: 230)
            .gesture(DragGesture().onChanged { w in
                let b = anker ?? (lat: lat, lon: lon)
                anker = b
                lon = b.lon - Double(w.translation.width) * 0.5
                lat = min(max(b.lat + Double(w.translation.height) * 0.5, -80), 80)
            }.onEnded { _ in anker = nil })
            .accessibilityLabel("Globus mit \(pins.count) Orten, \(besucht) besucht")
            if liste.isEmpty {
                Text("Orte trägst du bei den Date-Ideen ein. Hier leuchten die besuchten.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 8)
            } else {
                Text("\(besucht) von \(liste.count) besucht").font(.caption).foregroundStyle(.secondary)
                List(liste) { idee in
                    HStack(spacing: 12) {
                        Button { speicher.abhaken(idee.id, erledigt: !idee.erledigt) } label: {
                            Image(systemName: idee.erledigt ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(idee.erledigt ? Pal.gelb.farbe : Color.loveaRose)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(idee.erledigt ? "Als offen markieren" : "Als besucht markieren")
                        Button { hinschauen(idee) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(idee.titel).foregroundStyle(.primary)
                                if let ort = idee.ort, !ort.name.isEmpty, ort.name != idee.titel {
                                    Text(ort.name).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            let m = ZimmerGlobus.mitte(pins)
            lat = m.lat
            lon = m.lon
        }
        .presentationDetents([.large])
    }

    private func hinschauen(_ idee: DateIdee) {
        guard let ort = idee.ort, DateLogik.hatKoordinate(ort) else { return }
        lat = ort.lat
        lon = ort.lon
    }
}
