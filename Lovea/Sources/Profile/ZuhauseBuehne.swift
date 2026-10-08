import SwiftUI

/// What the stage asks of whoever draws a figure: who, which state, how tall in points (already
/// scaled to the screen), moving or still, whole body or head and chest (sitting on the sofa).
struct ZuhauseFigur {
    let person: Person
    let zustand: FigurZustand
    let groesse: CGFloat
    let animiert: Bool
    let ganzkoerper: Bool
}

extension ZuhauseGeste {
    var zustand: FigurZustand {
        switch self {
        case .winken: .imChat
        case .herz: .herz
        case .kuss: .kuss
        }
    }
}

/// Who is where right now: the stage's only changing state.
struct ZuhauseSzenenstand: Equatable {
    var zeit: Tageszeit
    var annika: Platz
    var ahmed: Platz
    /// Standing up and walking: the legs swing until they arrive.
    var gehende: Set<Person> = []
    var geste: ZuhauseGeste?
    /// Both in the bed (sitting up in the evening, asleep at night), not standing at its edge.
    var liegt: Bool

    /// `mitGeste`: also show the step's gesture; the resting scene (low power) has none.
    init(zeit: Tageszeit, _ aufstellung: Aufstellung, mitGeste: Bool = false) {
        self.zeit = zeit
        annika = aufstellung.annika
        ahmed = aufstellung.ahmed
        liegt = zeit.dunkel && aufstellung.annika == .bett && aufstellung.ahmed == .bett
        geste = mitGeste ? aufstellung.geste : nil
    }

    func platz(_ p: Person) -> Platz { p == .annika ? annika : ahmed }
}

/// p58: the shared home in the profile header. The room is a still drawing (`ZuhauseZeichnung`);
/// the bed, the bouquets and the two figures are views on top. Annika and Ahmed always live here,
/// both, in the sets of `ZuhauseAblauf`.
///
/// Battery: nothing runs by itself. One task changes the scene every 20 to 60 s with a single SwiftUI
/// animation (a walk of 1.4 to 3.4 s), everything else stands still: figures are drawn without a
/// clock, except the walker and a short gesture. Evening and night sleep until the next time of day.
/// Pause (scene as at rest, no task) while the app is not active, the header is off screen, Low Power
/// Mode is on or Reduce Motion is on.
///
/// Interface for the bouquets (p59): `straeusse` holds up to 3 IDs for the dresser and one for the
/// vase; each is drawn by `StraussView(id:)`, so p59 only replaces that view's body.
struct ZuhauseBuehne<Figur: View, Paar: View>: View {
    private let dehnung: CGFloat
    private let straeusse: ZuhauseStraeusse
    private let paarDa: Bool
    private let wandDinge: (Tageszeit) -> AnyView
    private let extras: ZimmerExtrasStand?
    private let fest: Bool
    private let wahl: ZimmerWahl
    private let katze: ZuhauseKatze?
    private let outfit: (() -> Void)?
    private let figur: (ZuhauseFigur) -> Figur
    private let paar: () -> Paar

    @State private var stand: ZuhauseSzenenstand
    /// The points the last stroke gave, for a moment (0: stroked again today, hearts only).
    @State private var streichelt: Int?
    @State private var sichtbar = false
    @State private var sparmodus = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `dehnung`: how far the header is pulled down; the scene grows upwards, the bottom stays.
    /// `paarDa`: they are together for real, `paar` (hug, kiss) replaces the two walkers.
    /// `fest`: a fixed scene without any driver (render board, previews).
    /// p61: `wahl` the room's pieces, `katze` the cat at home (none: no cat), `outfit` opens the outfit
    /// change from the clothes rail and the shoe shelf (none: both just hang there).
    /// `extras` (p63): occasion decoration, sign, shelf and dice, hung in under the figures.
    init(dehnung: CGFloat = 0, straeusse: ZuhauseStraeusse = ZuhauseStraeusse(), paarDa: Bool = false,
         extras: ZimmerExtrasStand? = nil,
         fest: ZuhauseSzenenstand? = nil, wahl: ZimmerWahl = .standard, katze: ZuhauseKatze? = nil, outfit: (() -> Void)? = nil,
         wandDinge: @escaping (Tageszeit) -> AnyView = { _ in AnyView(EmptyView()) },
         @ViewBuilder figur: @escaping (ZuhauseFigur) -> Figur, @ViewBuilder paar: @escaping () -> Paar) {
        self.dehnung = dehnung
        self.straeusse = straeusse
        self.paarDa = paarDa
        self.wandDinge = wandDinge
        self.wahl = wahl
        self.katze = katze
        self.outfit = outfit
        self.extras = extras
        self.fest = fest != nil
        self.figur = figur
        self.paar = paar
        let jetzt = Tageszeit.um(Date())
        _stand = State(initialValue: fest ?? ZuhauseSzenenstand(zeit: jetzt, ZuhauseAblauf.ruhestand(jetzt)))
    }

    private var aktiv: Bool { !fest && sichtbar && scenePhase == .active && !sparmodus && !reduceMotion }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / ZuhauseZeichnung.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                ZuhauseRaumBild(zeit: stand.zeit, wahl: wahl)
                wandDinge(stand.zeit)
                schatten
                if let outfit {
                    tippflaeche(ZimmerMoebel.stange, "Kleiderstange, Outfit wechseln", outfit, s, oben)
                    tippflaeche(ZimmerMoebel.regal, "Schuhregal, Outfit wechseln", outfit, s, oben)
                }
                ZStack(alignment: .topLeading) {
                    if let extras { ZimmerExtras(stand: extras, s: s, oben: oben) }
                    bett(s, oben)
                    straeusseSicht(s, oben)
                    if let katze {
                        katzeSicht(katze, s, oben)
                    }
                    personen(sitzend: true, s, oben)
                    ZuhauseSofaVorn()
                    if paarDa {
                        paarSicht(s, oben)
                    } else {
                        personen(sitzend: false, s, oben)
                    }
                }
                .colorMultiply(abdunklung)
                if stand.zeit.dunkel {
                    ZuhauseLicht(zeit: stand.zeit)
                }
            }
        }
        .frame(height: ZuhauseZeichnung.hoehe + dehnung)
        .clipped()
        .onAppear { sichtbar = true }
        .onDisappear { sichtbar = false }
        // Like the figures: the profile's plain scroll view never calls onDisappear.
        .onScrollVisibilityChange(threshold: 0.05) { sichtbar = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: DispatchQueue.main)) { _ in
            sparmodus = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: aktiv) { await lauf() }
    }

    // MARK: Pieces

    /// The dark of evening and night for everything above the room drawing (which darkens itself).
    private var abdunklung: Color {
        switch stand.zeit {
        case .morgen, .tag: .white
        case .abend: Color(red: 0.84, green: 0.80, blue: 0.86)
        case .nacht: Color(red: 0.60, green: 0.62, blue: 0.74)
        }
    }

    /// Soft shade top and bottom so the status bar and the name stay readable.
    private var schatten: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom).frame(height: 130)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).frame(height: 170)
        }
        .allowsHitTesting(false)
    }

    /// The bed: headboard and pillows, the two in it (sitting in the evening, asleep at night), the
    /// blanket and frame in front. Empty by day. Bed space 300 x 220 like `SchlafendeFiguren`.
    private func bett(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let k = ZuhauseZeichnung.bettMass * s
        let liegt = stand.liegt && !paarDa
        let schlaeft = stand.zeit == .nacht
        // Empty pillows: both while the bed is empty and behind those sitting up; sleepers bring their own.
        let kissen: [CGFloat] = liegt && schlaeft ? [] : [112, 188]
        let stil = ZuhauseZeichnung.bettStil
        let liegende: [Person] = liegt ? [.annika, .ahmed] : []
        return ZStack {
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: k, y: k)
                SzenenZeichnung.bettHinten(b, stil, kissen: kissen, bild: nil)
            }
            ForEach(liegende, id: \.self) { p in
                figur(ZuhauseFigur(person: p, zustand: schlaeft ? .schlaeft : .sitztImBett, groesse: 140 * k, animiert: false, ganzkoerper: false))
                    .position(x: (p == .annika ? 112 : 188) * k, y: (schlaeft ? 123.1 : 89.1) * k)
            }
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: k, y: k)
                ZimmerMoebel.bettVorn(b, stil, wahl, herz: liegt)
            }
        }
        .frame(width: 300 * k, height: 220 * k)
        .position(x: ZuhauseZeichnung.bettOrt.x * s + 150 * k, y: oben + ZuhauseZeichnung.bettOrt.y * s + 110 * k)
    }

    /// Up to 3 bouquets on the dresser and one in the vase, each in its own 24 x 40 frame.
    private func straeusseSicht(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let imSchrank = straeusse.imSchrank
        let plaetze = ZuhauseZeichnung.schrankPlaetze
        return ZStack(alignment: .topLeading) {
            ForEach(imSchrank.indices, id: \.self) { n in
                strauss(imSchrank[n], plaetze[n], s, oben)
            }
            if let vase = straeusse.vase {
                strauss(vase, ZuhauseZeichnung.vasenPlatz, s, oben)
            }
        }
    }

    private func strauss(_ id: String, _ fuss: CGPoint, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let mass = ZuhauseZeichnung.strauss
        return StraussView(id: id)
            .frame(width: mass.width * s, height: mass.height * s)
            .position(x: fuss.x * s, y: oben + (fuss.y - mass.height / 2) * s)
    }

    /// A transparent touch area over a wall piece, at least 44 points high.
    private func tippflaeche(_ r: CGRect, _ name: String, _ tun: @escaping () -> Void, _ s: CGFloat, _ oben: CGFloat) -> some View {
        Color.clear
            .frame(width: r.width * s, height: max(r.height * s, 44))
            .contentShape(Rectangle())
            .onTapGesture(perform: tun)
            .position(x: r.midX * s, y: oben + r.midY * s)
            .accessibilityLabel(name)
            .accessibilityAddTraits(.isButton)
    }

    /// The cat follows the scene state only: where it is and what it does comes from `stand`, so it
    /// changes with p58's step and has no timer of its own.
    private func katzeSicht(_ k: ZuhauseKatze, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let szene = ZimmerKatze.szene(zeit: stand.zeit, annika: stand.annika)
        return ZimmerKatzeSicht(id: k.id, szene: szene, wuenscht: ZimmerKatze.wuenscht(szene.zustand, gestreichelt: k.gestreichelt),
                                geht: stand.gehende.contains(.annika), streichelt: streichelt, s: s, oben: oben) {
            streichelt = k.streicheln()
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                streichelt = nil
            }
        }
    }

    private func sitzt(_ p: Person) -> Bool {
        stand.platz(p) == .sofa && !stand.gehende.contains(p)
    }

    /// Sitters sit behind the sofa's front cushion, everyone else stands in front of it.
    private func personen(sitzend: Bool, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let wer: [Person] = stand.liegt || paarDa ? [] : [Person.annika, .ahmed].filter { sitzt($0) == sitzend }
        return ForEach(wer, id: \.self) { p in person(p, s, oben) }
    }

    /// One figure, always the same view, so a step is a plain move of its position. Sitting: head and
    /// chest only (the half figure) with its lower edge behind the cushion. Standing: the whole body,
    /// feet at 98 % of its height on the floor line.
    private func person(_ p: Person, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let sitzend = sitzt(p)
        let hoehe = sitzend ? ZuhauseOrte.sitzHoehe : ZuhauseOrte.figurHoehe
        let unten = sitzend ? ZuhauseOrte.sitzKante : ZuhauseOrte.fussY + 0.02 * hoehe
        let x = ZuhauseOrte.fuss(stand.platz(p), p).x
        let geht = stand.gehende.contains(p)
        let gestik = p == .annika ? stand.geste : nil
        let zustand: FigurZustand = geht ? .laeuft : (gestik?.zustand ?? .ruhig)
        return figur(ZuhauseFigur(person: p, zustand: zustand, groesse: hoehe * s, animiert: geht || gestik != nil, ganzkoerper: !sitzend))
            .position(x: x * s, y: oben + (unten - hoehe / 2) * s)
    }

    /// The pair for real (hug, kiss), the size of the walkers, in the middle of the room.
    private func paarSicht(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = ZuhauseOrte.figurHoehe / 340 * s
        return paar()
            .frame(width: 276, height: 340)
            .scaleEffect(m, anchor: .bottom)
            .position(x: ZuhauseOrte.paarX * s, y: oben + ZuhauseOrte.fussY * s + 0.02 * 340 * m - 170)
    }

    // MARK: Driver

    /// Shows the scene at rest for this time of day: no walk, no gesture.
    private func ruhen(_ zeit: Tageszeit) {
        stand = ZuhauseSzenenstand(zeit: zeit, ZuhauseAblauf.ruhestand(zeit))
    }

    private func bisWechsel() -> TimeInterval {
        let k = Calendar.berlin.dateComponents([.hour, .minute], from: Date())
        return Tageszeit.sekundenBisWechsel(stunde: k.hour ?? 0, minute: k.minute ?? 0) + 1
    }

    /// Restarts whenever `aktiv` changes (`.task(id:)` cancels the old run). Without `aktiv` it only
    /// shows the scene at rest. With it, it sleeps 20 to 60 s (evening and night: until the next time
    /// of day), then takes one step.
    private func lauf() async {
        guard !fest else { return }
        ruhen(Tageszeit.um(Date()))
        guard aktiv else { return }
        var schritt = 0
        while !Task.isCancelled {
            let warte = ZuhauseAblauf.bewegt(stand.zeit) ? ZuhauseAblauf.wartezeit(schritt: schritt) : bisWechsel()
            try? await Task.sleep(for: .seconds(warte))
            guard !Task.isCancelled else { return }
            let jetzt = Tageszeit.um(Date())
            if jetzt == stand.zeit {
                schritt += 1
                await gehen(zu: ZuhauseAblauf.aufstellung(jetzt, schritt: schritt))
            } else {
                await wechseln(zu: jetzt)
                schritt = 0
            }
        }
    }

    /// A new time of day: the sky changes at once, the two walk to its first places (to bed, or up).
    private func wechseln(zu neu: Tageszeit) async {
        stand.zeit = neu
        await gehen(zu: ZuhauseAblauf.ruhestand(neu))
    }

    /// Stand up where they are, walk in one animation, arrive, show the gesture for a moment, stand still.
    private func gehen(zu neu: Aufstellung) async {
        var gehende = Set<Person>()
        var dauer: TimeInterval = 0
        for p in [Person.annika, .ahmed] where stand.platz(p) != neu.platz(p) {
            gehende.insert(p)
            dauer = max(dauer, ZuhauseOrte.gehdauer(von: stand.platz(p), nach: neu.platz(p), p))
        }
        guard dauer > 0 else { return }
        stand.geste = nil
        stand.liegt = false
        stand.gehende = gehende
        // One beat so the standing pose is on screen before the position starts to move.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: dauer)) {
            stand.annika = neu.annika
            stand.ahmed = neu.ahmed
        }
        try? await Task.sleep(for: .seconds(dauer))
        guard !Task.isCancelled else { return }
        stand.gehende = []
        stand.liegt = stand.zeit.dunkel && neu.annika == .bett && neu.ahmed == .bett
        stand.geste = neu.geste
        guard neu.geste != nil else { return }
        try? await Task.sleep(for: .seconds(3.5))
        guard !Task.isCancelled else { return }
        stand.geste = nil
    }
}

// MARK: Still layers (own views, so a step does not redraw them)

private struct ZuhauseRaumBild: View {
    let zeit: Tageszeit
    let wahl: ZimmerWahl

    var body: some View {
        let zeit = zeit
        let wahl = wahl
        Canvas { g, groesse in
            ZuhauseZeichnung.raum(SzenenZeichnung.raum(g, groesse), zeit: zeit, wahl: wahl)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The sofa's seat cushion in front of whoever sits.
private struct ZuhauseSofaVorn: View {
    var body: some View {
        Canvas { g, groesse in
            ZuhauseZeichnung.sofaVorn(SzenenZeichnung.raum(g, groesse))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ZuhauseLicht: View {
    let zeit: Tageszeit

    var body: some View {
        let zeit = zeit
        Canvas { g, groesse in
            ZuhauseZeichnung.licht(SzenenZeichnung.raum(g, groesse), zeit: zeit)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
