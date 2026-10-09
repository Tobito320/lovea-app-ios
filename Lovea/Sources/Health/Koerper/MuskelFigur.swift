import SwiftUI
import UIKit

/// One side of the figure as a Canvas drawing: the silhouette (head, neck, hands, feet) in skin color,
/// hair in ink, then every muscle surface of the map in its group's color (`MuskelPfade`).
/// Pure values only, so the Canvas closure captures nothing that is actor-isolated.
struct MuskelAnsicht: Sendable {
    let person: Person
    let hinten: Bool
    let farben: [MuskelGruppe: Color]
    let fokus: MuskelGruppe?
    let gedrueckt: MuskelGruppe?

    private static let tinte = FigurFarbe(0x4A3128).farbe
    private static let fremd = FigurFarbe(0xD8B195).farbe
    private static let hautAhmed = FigurFarbe(0xF1C3A0).farbe
    private static let hautAnnika = FigurFarbe(0xF7D0B6).farbe

    func zeichne(_ ctx: GraphicsContext, _ size: CGSize) {
        var g = ctx
        let bild = MuskelPfade.figur(person).bild(hinten: hinten)
        let r = bild.rahmen
        let s = bild.massstab(in: size)
        // Karte mittig einpassen; der Weg zurück steht in `Bild.kartenpunkt` (Treffertest).
        g.translateBy(x: (size.width - r.width * s) / 2, y: (size.height - r.height * s) / 2)
        g.scaleBy(x: s, y: s)
        g.translateBy(x: -r.minX, y: -r.minY)
        let haut = person == .annika ? Self.hautAnnika : Self.hautAhmed

        for teil in bild.still { g.fill(teil.pfad, with: .color(teil.haar ? Self.tinte : haut)) }
        // Hairline in map units, so the outline looks the same on a 650 and a 727 wide map.
        let rand = StrokeStyle(lineWidth: r.width * 0.003, lineJoin: .round)
        for f in bild.flaechen {
            g.fill(f.pfad, with: .color(fuellung(f.gruppe)))
            g.stroke(f.pfad, with: .color(Self.tinte), style: rand)
        }
    }

    /// Own color per group. With `fokus`, every other group turns skin-gray.
    private func fuellung(_ g: MuskelGruppe) -> Color {
        let c = farben[g, default: Color.clear]
        let basis = fokus.map { $0 == g ? c : Self.fremd } ?? c
        return g == gedrueckt ? basis.opacity(0.72) : basis
    }
}

/// One side of the muscle figure, standing still. The Körper sheet can put a front and a back next to
/// each other with this (as in the draft).
struct MuskelSeite: View {
    let person: Person
    let hinten: Bool
    let farbe: (MuskelGruppe) -> Color
    var fokus: MuskelGruppe?
    var gedrueckt: MuskelGruppe?

    var body: some View {
        let ansicht = MuskelAnsicht(
            person: person, hinten: hinten,
            farben: Dictionary(uniqueKeysWithValues: MuskelGruppe.allCases.map { ($0, farbe($0)) }),
            fokus: fokus, gedrueckt: gedrueckt
        )
        Canvas { g, size in ansicht.zeichne(g, size) }
            .aspectRatio(MuskelPfade.figur(person).seitenverhaeltnis, contentMode: .fit)
    }
}

/// The turnable muscle figure (Erholung, Körper tab). Drag turns 1:1 (1.1 deg per pt) and
/// swings on with a spring, a tap turns by 180 deg. A tap on a muscle group reports that `MuskelGruppe`
/// and does not turn; a tap beside the body, on skin without a group there, turns it instead. With
/// `fokus` (the sheet of one muscle group) the figure does not turn: it shows the side that holds the
/// group, that group in its own color, everything else skin-gray.
struct MuskelFigur: View {
    let person: Person
    let farbe: (MuskelGruppe) -> Color
    let fokus: MuskelGruppe?
    let onTipp: ((MuskelGruppe) -> Void)?
    let animiert: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lauf: Lauf
    @State private var laeuft = false
    @State private var zug: Zug? = nil
    @State private var gedrueckt: MuskelGruppe? = nil

    /// The turn as a damped spring in closed form (period 0.42 s, damping 0.8, as in the draft).
    /// The angle is a pure function of time: a touch in mid-flight picks the figure up where it is,
    /// and the side that shows always matches the drawn angle.
    private struct Lauf {
        static let dauer = 1.2
        var von: Double
        var tempo = 0.0
        var ziel: Double
        var seit = Date.distantPast

        static func ruhig(_ w: Double) -> Lauf { Lauf(von: w, ziel: w) }

        func winkel(_ jetzt: Date) -> Double {
            let t = jetzt.timeIntervalSince(seit)
            if t <= 0 { return von }
            if t >= Self.dauer { return ziel }
            let w0 = 2 * Double.pi / 0.42, z = 0.8
            let wd = w0 * (1 - z * z).squareRoot()
            let a = von - ziel
            return ziel + exp(-z * w0 * t) * (a * cos(wd * t) + (tempo + z * w0 * a) / wd * sin(wd * t))
        }
    }

    /// One touch from finger down to finger up.
    private struct Zug {
        enum Art { case tippen, drehen, scrollen }
        var art = Art.tippen
        let ort: CGPoint
        let von: Double
        var zeit: Date
        var x: CGFloat = 0
        var tempo = 0.0
    }

    /// `animiert` turns the figure in once from -34 deg to the front, as in the draft.
    init(
        person: Person, farbe: @escaping (MuskelGruppe) -> Color,
        fokus: MuskelGruppe? = nil, onTipp: ((MuskelGruppe) -> Void)? = nil, animiert: Bool = true
    ) {
        self.person = person
        self.farbe = farbe
        self.fokus = fokus
        self.onTipp = onTipp
        self.animiert = animiert
        _lauf = State(initialValue: .ruhig(animiert && fokus == nil ? -34 : 0))
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: !laeuft)) { kontext in
                let w = winkel(kontext.date)
                figur(geo.size, w)
                    .overlay(alignment: .bottomTrailing) { knopf(w) }
            }
        }
        .aspectRatio(MuskelPfade.figur(person).seitenverhaeltnis, contentMode: .fit)
        .onAppear { einblenden() }
        // Pauses the timeline once the spring has settled; a new spring restarts this task.
        .task(id: lauf.seit) {
            let warte = lauf.seit.timeIntervalSinceNow + Lauf.dauer
            if warte > 0 {
                do { try await Task.sleep(for: .seconds(warte)) } catch { return }
            }
            laeuft = false
        }
    }

    private static func zeigtVorne(_ w: Double) -> Bool { cos(w * .pi / 180) >= 0 }

    /// The angle at `jetzt`. With `fokus` the figure stands still on the side that shows the group.
    private func winkel(_ jetzt: Date) -> Double {
        guard let fokus else { return lauf.winkel(jetzt) }
        return MuskelPfade.figur(person).hinten(fuer: fokus) ? 180 : 0
    }

    private func figur(_ groesse: CGSize, _ w: Double) -> some View {
        let vorne = Self.zeigtVorne(w)
        return ZStack {
            seite(hinten: false).opacity(vorne ? 1 : 0)
            seite(hinten: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(vorne ? 0 : 1)
        }
        .rotation3DEffect(.degrees(w), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        // The gesture sits outside the turning view, so its coordinates do not turn with it.
        .contentShape(Rectangle())
        // ponytail: simultaneous, so a vertical drag on the figure still scrolls the page.
        .tabWischSperre()
        .simultaneousGesture(geste(groesse))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), Muskeln von \(vorne ? "vorne" : "hinten")")
    }

    private func seite(hinten: Bool) -> MuskelSeite {
        MuskelSeite(person: person, hinten: hinten, farbe: farbe, fokus: fokus, gedrueckt: gedrueckt)
    }

    @ViewBuilder private func knopf(_ w: Double) -> some View {
        if fokus == nil {
            VStack(spacing: 2) {
                Button {
                    Haptik.leicht()
                    drehen()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Figur drehen")
                Text(Self.zeigtVorne(w) ? "Vorne" : "Hinten")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Turning

    private func geste(_ groesse: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in beruehren(wert, groesse) }
            .onEnded { wert in loslassen(wert, groesse) }
    }

    private func beruehren(_ wert: DragGesture.Value, _ groesse: CGSize) {
        // A touch the scroll view took never ends here: a new start point means a new touch.
        if zug?.ort != wert.startLocation { zug = nil }
        var z = zug ?? anfassen(wert, groesse)
        let dx = wert.translation.width, dy = wert.translation.height
        if z.art == .tippen, max(abs(dx), abs(dy)) > 8 {
            z.art = abs(dx) > abs(dy) && fokus == nil ? .drehen : .scrollen
            gedrueckt = nil
        }
        if z.art == .drehen {
            let dt = wert.time.timeIntervalSince(z.zeit)
            // ponytail: smoothed speed instead of the draft's window of six samples.
            if dt > 0 { z.tempo = z.tempo * 0.6 + Double(dx - z.x) / dt * 1.1 * 0.4 }
            z.zeit = wert.time
            z.x = dx
            lauf = .ruhig(z.von + Double(dx) * 1.1)
        }
        zug = z
    }

    /// Finger down: stops a turn in flight and notes the group under the finger.
    private func anfassen(_ wert: DragGesture.Value, _ groesse: CGSize) -> Zug {
        let w = winkel(wert.time)
        if fokus == nil { lauf = .ruhig(w) }
        gedrueckt = onTipp == nil ? nil : gruppe(bei: wert.startLocation, groesse, w)
        return Zug(ort: wert.startLocation, von: w, zeit: wert.time)
    }

    private func loslassen(_ wert: DragGesture.Value, _ groesse: CGSize) {
        guard let z = zug else { return }
        zug = nil
        gedrueckt = nil
        let w = winkel(wert.time)
        switch z.art {
        case .drehen:
            let tempo = wert.time.timeIntervalSince(z.zeit) < 0.08 ? z.tempo : 0
            springe(zu: ((w + tempo * 0.099) / 180).rounded() * 180, tempo: tempo)
        case .tippen:
            if let onTipp, let gruppe = gruppe(bei: wert.location, groesse, w) {
                Haptik.auswahl()
                onTipp(gruppe)
            } else if fokus == nil {
                Haptik.leicht()
                drehen()
            }
        case .scrollen:
            break
        }
    }

    /// Exact while the figure stands still, a good guess in flight. `nil` beside the body or on skin
    /// that belongs to no group (head, hands, neck, gaps): that is what turns the figure instead.
    private func gruppe(bei ort: CGPoint, _ groesse: CGSize, _ w: Double) -> MuskelGruppe? {
        let figur = MuskelPfade.figur(person)
        let hinten = !Self.zeigtVorne(w)
        return figur.gruppe(bei: figur.bild(hinten: hinten).kartenpunkt(ort, in: groesse), hinten: hinten)
    }

    /// Starts the spring from wherever the figure is now. Reduce Motion: it just jumps.
    private func springe(zu ziel: Double, tempo: Double = 0, verzoegert: TimeInterval = 0) {
        if reduceMotion {
            lauf = .ruhig(ziel)
        } else {
            lauf = Lauf(von: lauf.winkel(Date()), tempo: tempo, ziel: ziel, seit: Date().addingTimeInterval(verzoegert))
            laeuft = true
        }
    }

    private func drehen() { springe(zu: (lauf.winkel(Date()) / 180).rounded() * 180 + 180) }

    private func einblenden() {
        if animiert, fokus == nil { springe(zu: 0, verzoegert: 0.16) }
    }
}
