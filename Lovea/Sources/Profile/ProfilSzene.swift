import SwiftUI

/// Brief G: the scene behind the figure in the profile header, following real life. Asleep at
/// home -> in bed (both asleep -> one bed together), at the saved place `gym` -> gym with dumbbells,
/// at `zuhause` -> the own room (`Zimmer`), anywhere else -> outside with weather and time of day.
enum ProfilSzene: Equatable, Sendable {
    case zimmer
    case schlafen(zusammen: Bool)
    case gym
    case draussen(wetter: Wetter, nacht: Bool)

    enum Wetter: Equatable, Sendable { case sonne, wolken, regen, schnee }

    /// Pure core, tested in `ProfilSzeneTests`. Priority: sleep > gym > home > outside.
    /// `tag` is Open-Meteo's `is_day` (real sunrise/sunset); unknown -> night is 20-6 Uhr.
    static func fuer(schlaeft: Bool, partnerSchlaeft: Bool, ort: String?, wetterCode: Int?, tag: Bool?, stunde: Int) -> ProfilSzene {
        if schlaeft { return .schlafen(zusammen: partnerSchlaeft) }
        switch ort {
        case "gym": return .gym
        case "zuhause": return .zimmer
        default: return .draussen(wetter: wetter(code: wetterCode), nacht: istNacht(tag: tag, stunde: stunde))
        }
    }

    static func istNacht(tag: Bool?, stunde: Int) -> Bool { tag.map { !$0 } ?? (stunde >= 20 || stunde < 6) }

    /// The sky, read off the map figure's weather extras (`KarteLogik.extras`) so both agree:
    /// umbrella -> rain, snowflakes -> snow, sunglasses (clear, asked as if by day) -> sun.
    static func wetter(code: Int?) -> Wetter {
        let extras = KarteLogik.extras(wetterCode: code, temperatur: nil, tag: true, laedt: false)
        if extras.contains(.schirm) { return .regen }
        if extras.contains(.schneeflocken) { return .schnee }
        if extras.contains(.sonnenbrille) { return .sonne }
        return .wolken
    }

    /// Live "schläft", or - the partner's app is mostly closed at night, so `anzeige` says offline -
    /// the last state they sent, but only in the night hours so a stale one never shows by day.
    static func schlaeft(anzeige: FigurZustand, zuletzt: FigurZustand?, stunde: Int) -> Bool {
        anzeige == .schlaeft || (anzeige == .offline && zuletzt == .schlaeft && AnwesenheitEingabe.istNachtstunde(stunde))
    }

    /// What the profile person's figure does here. In the gym only a live gesture or expression
    /// interrupts the curls; in the room "zu Hause" stands instead of sitting on its own sofa.
    func figur(_ z: FigurZustand) -> FigurZustand {
        switch self {
        case .gym:
            let geste = z == .kuss || z == .herz || z == .anstupsen || z == .lacht || z == .anstossen || z == .pokal
            return geste || FigurZustand.mimik.contains(z) ? z : .gym
        case .zimmer: return z == .zuhause ? .ruhig : z
        case .schlafen: return .schlaeft
        case .draussen: return z
        }
    }

    /// What the figure carries: dumbbells in the gym, the map's weather extras outside.
    func extras(wetterCode: Int?, temperatur: Double?, laedt: Bool) -> Set<FigurExtra> {
        switch self {
        case .gym: return [.hanteln]
        case .draussen(_, let nacht): return KarteLogik.extras(wetterCode: wetterCode, temperatur: temperatur, tag: !nacht, laedt: laedt)
        case .zimmer, .schlafen: return []
        }
    }
}

@MainActor
extension ProfilSzene {
    static func fuer(person: Person, jetzt: Date = Date()) -> ProfilSzene {
        let stunde = Calendar.berlin.component(.hour, from: jetzt)
        let wetter = WetterModell.shared.staende[person]
        return fuer(
            schlaeft: schlaeftGerade(person, stunde: stunde), partnerSchlaeft: schlaeftGerade(person.partner, stunde: stunde),
            ort: ortKategorie(person), wetterCode: wetter?.code, tag: wetter?.tag, stunde: stunde
        )
    }

    /// Night for the room's window and lamp (and the sky outside): real daylight where known.
    static func nacht(person: Person, jetzt: Date = Date()) -> Bool {
        istNacht(tag: WetterModell.shared.staende[person]?.tag, stunde: Calendar.berlin.component(.hour, from: jetzt))
    }

    private static func schlaeftGerade(_ p: Person, stunde: Int) -> Bool {
        let modell = FigurenModell.shared
        return schlaeft(anzeige: modell.anzeige(p).haupt, zuletzt: modell.zustand[p]?.haupt, stunde: stunde)
    }

    /// Saved place at the last position (like `KartenFigur`), else the place state they sent.
    private static func ortKategorie(_ p: Person) -> String? {
        if let pos = Standort.shared.positionen[p], let ort = OrteModell.shared.ortBei(lat: pos.lat, lon: pos.lon) { return ort.kategorie }
        let z = FigurenModell.shared.anzeige(p).haupt
        return z == .zuhause || z == .gym ? z.rawValue : nil
    }
}

// MARK: - Views

/// The drawn scene behind the header figures, from plain inputs so the render board can show every
/// case. Asset hooks: an image set `szene-zimmer-hintergrund`, `szene-gym`, `szene-draussen-tag` or
/// `szene-draussen-nacht` in the catalog replaces the drawing, `szene-bett-<n>` the headboard.
/// Moves only where something lives (rain, snow, clouds, stars, fairy lights), at 15 fps; still
/// under Reduce Motion.
struct ProfilSzeneHintergrund: View {
    let szene: ProfilSzene
    let zimmer: Zimmer
    let nacht: Bool
    var animiert = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .overlay {
                if let bild = asset {
                    Image(uiImage: bild).resizable().scaledToFill()
                } else if animiert && bewegt && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 15, paused: scenePhase != .active)) { k in
                        leinwand(k.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    leinwand(0.4)
                }
            }
            .overlay {
                if imZimmer { FotoRahmen(zimmer: zimmer, nacht: nacht || szene != .zimmer) }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var imZimmer: Bool {
        switch szene {
        case .zimmer, .schlafen: true
        case .gym, .draussen: false
        }
    }

    private var asset: UIImage? {
        switch szene {
        case .zimmer, .schlafen: UIImage(named: "szene-zimmer-hintergrund")
        case .gym: UIImage(named: "szene-gym")
        case .draussen(_, let n): UIImage(named: n ? "szene-draussen-nacht" : "szene-draussen-tag")
        }
    }

    private var bewegt: Bool {
        switch szene {
        case .zimmer: zimmer.hat("lichterkette") || (nacht && zimmer.hat("fenster"))
        case .schlafen: zimmer.hat("lichterkette") || zimmer.hat("fenster")
        case .gym: false
        case .draussen: true
        }
    }

    private func leinwand(_ t: Double) -> some View {
        let szene = szene
        let zimmer = zimmer
        let nacht = nacht
        let bett = UIImage(named: "szene-bett-\(zimmer.bett)")
        return Canvas { g, size in
            let r = SzenenZeichnung.raum(g, size)
            switch szene {
            case .zimmer: SzenenZeichnung.zimmer(r, zimmer, nacht: nacht, mitBett: true, bett: bett, t: t)
            case .schlafen: SzenenZeichnung.zimmer(r, zimmer, nacht: true, mitBett: false, bett: nil, t: t)
            case .gym: SzenenZeichnung.gym(r)
            case .draussen(let wetter, let n): SzenenZeichnung.draussen(r, wetter: wetter, nacht: n, t: t)
            }
        }
    }
}

/// The real photos in the drawn frames, placed in the same design space as `SzenenZeichnung.raum`.
/// Until a photo loads (and on the render board) the drawn stand-in shows through.
private struct FotoRahmen: View {
    let zimmer: Zimmer
    let nacht: Bool

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / SzenenZeichnung.breite
            let oben = geo.size.height - SzenenZeichnung.hoehe * s
            ForEach(zimmer.rahmen, id: \.slot) { r in
                if let rect = SzenenZeichnung.fotoRect(r.slot) {
                    ProfilFoto(medienId: r.medienId)
                        .overlay(Color(red: 0.1, green: 0.12, blue: 0.23).opacity(nacht ? 0.3 : 0))
                        .frame(width: rect.width * s, height: rect.height * s)
                        .position(x: rect.midX * s, y: oben + rect.midY * s)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Brief G: asleep in the own bed, the head on the pillow and the blanket up to the chin. Both
/// asleep: both heads side by side under one blanket, a small heart between them. The half figure
/// in "schläft" already brings closed eyes, its pillow and the Zzz. Bed space 300 x 220 at 1.1x.
struct SchlafendeFiguren: View {
    let zimmer: Zimmer
    /// One or two sleepers, left to right.
    let schlaefer: [FigurAussehen]
    var animiert = true

    private static let k: CGFloat = 1.1

    var body: some View {
        let zusammen = schlaefer.count > 1
        let bett = zimmer.bett
        let bild = UIImage(named: "szene-bett-\(bett)")
        ZStack {
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: Self.k, y: Self.k)
                SzenenZeichnung.bettHinten(b, bett, kissen: zusammen ? [] : [212], bild: bild)
            }
            ForEach(schlaefer.indices, id: \.self) { i in
                // Pillow at bed (x, 104): the figure's own pillow sits 37 % down its frame.
                let x: CGFloat = zusammen ? (i == 0 ? 112 : 188) : 92
                FigurView(schlaefer[i], zustand: .schlaeft, groesse: 154, animiert: animiert, bildrate: 15)
                    .position(x: x * Self.k, y: 104 * Self.k - 56 + 77)
            }
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: Self.k, y: Self.k)
                SzenenZeichnung.bettVorn(b, bett, herz: zusammen)
            }
        }
        .frame(width: 300 * Self.k, height: 220 * Self.k)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zusammen ? "Ihr schlaft zusammen" : "Schläft")
    }
}
