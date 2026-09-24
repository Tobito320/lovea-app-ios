import SwiftUI

/// Brief G: the scene behind the figure in the profile header, following real life. Asleep at
/// home -> in bed (both asleep -> one bed together), at the saved place `gym` -> gym with dumbbells,
/// at `zuhause` -> the own room (`Zimmer`), anywhere else -> outside with weather and time of day.
enum ProfilSzene: Equatable, Sendable {
    case zimmer
    case schlafen(zusammen: Bool)
    case gym
    case draussen(wetter: Wetter, nacht: Bool)
    /// On a train, bus or in a car: outside flying past (Brief G bugfix).
    case unterwegs(wetter: Wetter, nacht: Bool)
    /// At the saved places `schule` and `arbeit`: a classroom or an office, at a desk.
    case schule, arbeit

    enum Wetter: Equatable, Sendable { case sonne, wolken, regen, schnee }

    /// Pure core, tested in `ProfilSzeneTests`. Priority: sleep > travelling > gym > home > outside.
    /// `tag` is Open-Meteo's `is_day` (real sunrise/sunset); unknown -> night is 20-6 Uhr.
    static func fuer(schlaeft: Bool, partnerSchlaeft: Bool, ort: String?, wetterCode: Int?, tag: Bool?, stunde: Int, unterwegs: Bool = false) -> ProfilSzene {
        if schlaeft { return .schlafen(zusammen: partnerSchlaeft) }
        if unterwegs { return .unterwegs(wetter: wetter(code: wetterCode), nacht: istNacht(tag: tag, stunde: stunde)) }
        switch ort {
        case "gym": return .gym
        case "zuhause": return .zimmer
        case "schule": return .schule
        case "arbeit": return .arbeit
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

    /// The sleeper's own phone decides (`SchlafLogik`) and shares it with its presence; while its
    /// app is closed (`anzeige` offline), the last shared state stays.
    static func schlaf(anzeige: FigurZustand, zuletzt: FigurZustand?) -> SchlafZustand {
        SchlafZustand(anzeige == .offline ? zuletzt : anzeige)
    }
    /// From 22:00 an awake figure is tired (`FigurExtra.schlaefrig`) until the morning.
    static func spaet(stunde: Int) -> Bool { stunde >= 22 || stunde < 6 }

    /// What the profile person's figure does here. In the gym only a live gesture or expression
    /// interrupts the curls; in the room "zu Hause" stands instead of sitting on its own sofa.
    func figur(_ z: FigurZustand) -> FigurZustand {
        switch self {
        case .gym: return Self.geste(z) ? z : .gym
        case .unterwegs: return Self.geste(z) || z == .zug ? z : .faehrt
        case .schule: return Self.geste(z) ? z : .schule
        case .arbeit: return Self.geste(z) ? z : .arbeit
        case .zimmer: return z == .zuhause ? .ruhig : z
        case .schlafen: return .schlaeft
        case .draussen: return z
        }
    }

    /// What the figure carries for the state it shows (`figur(_:)`): dumbbells while it curls in the
    /// gym (a gesture keeps its own arms), the map's weather extras outside.
    func extras(_ z: FigurZustand, wetterCode: Int?, temperatur: Double?) -> Set<FigurExtra> {
        switch self {
        case .gym: return z == .gym ? [.hanteln] : []
        case .draussen(_, let nacht): return KarteLogik.extras(wetterCode: wetterCode, temperatur: temperatur, tag: !nacht, laedt: z == .laedt)
        case .zimmer, .schlafen, .unterwegs, .schule, .arbeit: return []
        }
    }

    /// Whether the room goes dark (drawing, framed photos and figures): home, office and classroom
    /// at night, the bed always. The gym and outside bring their own light.
    func dunkel(nacht: Bool) -> Bool {
        switch self {
        case .schlafen: true
        case .zimmer, .schule, .arbeit: nacht
        case .gym, .draussen, .unterwegs: false
        }
    }

    /// The furnishable place this scene shows (its own saved `Zimmer`), `nil` outside.
    var raumOrt: RaumOrt? {
        switch self {
        case .zimmer, .schlafen: .zuhause
        case .arbeit: .arbeit
        case .schule: .schule
        case .gym: .gym
        case .draussen, .unterwegs: nil
        }
    }

    private static func geste(_ z: FigurZustand) -> Bool {
        z == .kuss || z == .herz || z == .anstupsen || z == .lacht || z == .anstossen || z == .pokal || FigurZustand.mimik.contains(z)
    }

    /// Travelling: the shared state says so, or a fresh fix (under 5 min) is in a vehicle or fast.
    static func istUnterwegs(anzeige: FigurZustand, bewegung: String?, tempo: Double?, fixAlter: TimeInterval?) -> Bool {
        if anzeige == .faehrt || anzeige == .zug { return true }
        guard (fixAlter ?? .infinity) < 300 else { return false }
        return bewegung == "faehrt" || (tempo ?? 0) > AnwesenheitEingabe.reiseTempo
    }
}

@MainActor
extension ProfilSzene {
    static func fuer(person: Person, jetzt: Date = Date()) -> ProfilSzene {
        let stunde = Calendar.berlin.component(.hour, from: jetzt)
        let wetter = WetterModell.shared.staende[person]
        return fuer(
            schlaeft: schlafGerade(person) != .wach, partnerSchlaeft: schlafGerade(person.partner) != .wach,
            ort: ortKategorie(person), wetterCode: wetter?.code, tag: wetter?.tag, stunde: stunde,
            unterwegs: unterwegsGerade(person)
        )
    }

    static func unterwegsGerade(_ p: Person) -> Bool {
        let fix = Standort.shared.positionen[p]
        return istUnterwegs(anzeige: geteilterZustand(p) ?? .ruhig, bewegung: fix?.bewegung, tempo: fix?.tempo, fixAlter: fix?.sekundenAlt)
    }

    /// The state `p`'s own phone decided and shared: live while online, else the last one (the
    /// server replays it on connect). It knows its place and trip at once; our copy of its
    /// position can be minutes old, so the scene asks this first.
    static func geteilterZustand(_ p: Person) -> FigurZustand? {
        let modell = FigurenModell.shared
        let live = modell.anzeige(p).haupt
        return live == .offline ? modell.zustand[p]?.haupt : live
    }

    private static let ortZustaende: Set<FigurZustand> = [.zuhause, .gym, .schule, .arbeit, .supermarkt, .fahrschule]

    /// Night for the room's window and lamp (and the sky outside): real daylight where known.
    static func nacht(person: Person, jetzt: Date = Date()) -> Bool {
        istNacht(tag: WetterModell.shared.staende[person]?.tag, stunde: Calendar.berlin.component(.hour, from: jetzt))
    }

    /// Whether `p` is awake, sitting up in bed or asleep; the header asks this per figure.
    static func schlafGerade(_ p: Person) -> SchlafZustand {
        let modell = FigurenModell.shared
        return schlaf(anzeige: modell.anzeige(p).haupt, zuletzt: modell.zustand[p]?.haupt)
    }
    /// The place state they shared, else the saved place at their last known position.
    private static func ortKategorie(_ p: Person) -> String? {
        if let z = geteilterZustand(p), ortZustaende.contains(z) { return z.rawValue }
        if let pos = Standort.shared.positionen[p], let ort = OrteModell.shared.ortBei(lat: pos.lat, lon: pos.lon) { return ort.kategorie }
        return nil
    }
}

// MARK: - Views

/// The drawn scene behind the header figures, from plain inputs so the render board can show every
/// case. Asset hooks: an image set `szene-zimmer-hintergrund`, `szene-gym`, `szene-draussen-tag` or
/// `szene-draussen-nacht` in the catalog replaces the drawing, `szene-bett-<n>` the headboard.
/// Moves only where something lives (rain, snow, clouds, stars, fairy lights); still under Reduce
/// Motion. While it moves, the scene is four stacked canvases (`SzenenEbene`): the two still ones
/// sit outside the clock and are drawn only when the inputs or the size change, the clock
/// redraws just the thin moving layers. A still scene is one canvas with all four.
struct ProfilSzeneHintergrund: View {
    let szene: ProfilSzene
    let zimmer: Zimmer
    let nacht: Bool
    var animiert = true
    /// `false` while someone lies in the big bed in front (`SchlafendeFiguren`).
    var mitBett = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sichtbar = false

    var body: some View {
        let bett = UIImage(named: "szene-bett-\(zimmer.bett)")
        Color.clear
            .overlay {
                if let bild = asset {
                    Image(uiImage: bild).resizable().scaledToFill()
                } else if animiert && bewegt && !reduceMotion {
                    ebenen(bett: bett)
                } else {
                    leinwand(SzenenEbene.allCases, 0.4, bett: bett)
                }
            }
            .overlay {
                if imZimmer { FotoRahmen(zimmer: zimmer, nacht: szene.dunkel(nacht: nacht)) }
            }
            .clipped()
            .onAppear { sichtbar = true }
            .onDisappear { sichtbar = false }
            // Same as FigurView: the profile's plain scroll view never calls onDisappear.
            .onScrollVisibilityChange(threshold: 0.05) { sichtbar = $0 }
            .accessibilityHidden(true)
    }

    private var imZimmer: Bool {
        switch szene {
        case .zimmer, .schlafen, .schule, .arbeit: true
        case .gym, .draussen, .unterwegs: false
        }
    }

    private var asset: UIImage? {
        switch szene {
        case .zimmer, .schlafen: UIImage(named: "szene-zimmer-hintergrund")
        case .gym: UIImage(named: "szene-gym")
        case .draussen(_, let n): UIImage(named: n ? "szene-draussen-nacht" : "szene-draussen-tag")
        case .unterwegs: UIImage(named: "szene-unterwegs")
        case .schule: UIImage(named: "szene-schule")
        case .arbeit: UIImage(named: "szene-arbeit")
        }
    }

    private var bewegt: Bool {
        switch szene {
        case .zimmer: zimmer.hat("lichterkette") || zimmer.hat("lichtervorhang") || (nacht && zimmer.hat("fenster"))
        case .schlafen: zimmer.hat("lichterkette") || zimmer.hat("fenster")
        case .schule: zimmer.hat("lichterkette") || zimmer.hat("lichtervorhang") || nacht
        case .arbeit: zimmer.hat("lichterkette") || zimmer.hat("lichtervorhang")
        case .gym: false
        case .draussen, .unterwegs: true
        }
    }

    /// What the moving layer needs: rain, snow and travel streaks cover several points a frame and
    /// keep 15 fps; twinkling lights and stars, drifting clouds and the slow sun get by with 10.
    private var bildrate: Double {
        switch szene {
        case .draussen(.regen, _), .draussen(.schnee, _), .unterwegs: 15
        default: 10
        }
    }

    /// The four stacked canvases; only the moving ones hang on the clock.
    private func ebenen(bett: UIImage?) -> some View {
        ZStack {
            ForEach(SzenenEbene.allCases, id: \.self) { e in
                if e.bewegt {
                    TimelineView(.animation(minimumInterval: 1 / bildrate, paused: !sichtbar || scenePhase != .active)) { k in
                        leinwand([e], k.date.timeIntervalSinceReferenceDate, bett: nil)
                    }
                } else {
                    leinwand([e], 0.4, bett: bett)
                }
            }
        }
    }

    private func leinwand(_ ebenen: [SzenenEbene], _ t: Double, bett: UIImage?) -> some View {
        let szene = szene
        let zimmer = zimmer
        let nacht = nacht
        let mitBett = mitBett
        return Canvas { g, size in
            SzenenZeichnung.szene(SzenenZeichnung.raum(g, size), szene, zimmer, nacht: nacht, mitBett: mitBett, bett: bett, ebenen: ebenen, t: t)
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
                        .overlay(Color(red: 0.1, green: 0.12, blue: 0.23).opacity(nacht ? 0.45 : 0))
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
    /// Smaller next to a standing, awake partner.
    var skala: CGFloat = 1
    /// Indices of sleepers still sitting up (Brief G fix 2): upright, blanket at the waist, yawning.
    var sitzend: Set<Int> = []

    private static func x(_ i: Int, zusammen: Bool) -> CGFloat { zusammen ? (i == 0 ? 112 : 188) : 92 }

    var body: some View {
        let k = 1.1 * skala
        let zusammen = schlaefer.count > 1
        let bett = zimmer.bett
        let bild = UIImage(named: "szene-bett-\(bett)")
        // Empty pillows: the free side of a single bed, and behind everyone sitting up.
        let kissen = (zusammen ? [] : [CGFloat(212)]) + sitzend.sorted().map { Self.x($0, zusammen: zusammen) }
        ZStack {
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: k, y: k)
                SzenenZeichnung.bettHinten(b, bett, kissen: kissen, bild: bild)
            }
            ForEach(schlaefer.indices, id: \.self) { i in
                // Lying: the figure's own pillow (37 % down its frame) at bed (x, 104). Sitting: the
                // waist (94 % down) at the blanket's edge, bed y 150.
                let sitzt = sitzend.contains(i)
                FigurView(schlaefer[i], zustand: sitzt ? .sitztImBett : .schlaeft, groesse: 154 * skala, animiert: animiert, bildrate: 15)
                    .position(x: Self.x(i, zusammen: zusammen) * k, y: (sitzt ? 150 * 1.1 - 67 : 104 * 1.1 + 21) * skala)
            }
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: k, y: k)
                SzenenZeichnung.bettVorn(b, bett, herz: zusammen)
            }
        }
        .frame(width: 300 * k, height: 220 * k)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zusammen ? "Ihr schlaft zusammen" : "Schläft")
    }
}
