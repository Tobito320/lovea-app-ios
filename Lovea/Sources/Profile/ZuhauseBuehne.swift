import SwiftUI

/// What the stage asks of whoever draws a figure: who, which state, how tall in points (already
/// scaled to the screen), moving or still, whole body or head and chest (sitting on the sofa).
struct ZuhauseFigur {
    let person: Person
    let zustand: FigurZustand
    let groesse: CGFloat
    let animiert: Bool
    let ganzkoerper: Bool
    /// p65: how the whole body is posed (sitting on the sofa); `nil` leaves it to the state.
    var pose: FigurPose? = nil
    /// p70: frames per second of the figure's loop; standing about is slower than walking.
    var bildrate: Double = ZuhauseSzeneLogik.bewegtRate
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
    /// p65: lying down on a tap on the bed, also by day: they lie with closed eyes, not sit up.
    var hingelegt = false

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
    /// p68: Ahmeds Bord (panorama only), empty = not drawn.
    private let ahmedStraeusse: ZuhauseStraeusse
    private let paarDa: Bool
    private let wandDinge: (Tageszeit) -> AnyView
    private let extras: ZimmerExtrasStand?
    private let nacht: Bool
    private let fest: Bool
    private let wahl: ZimmerWahl
    private let katze: ZuhauseKatze?
    private let outfit: (() -> Void)?
    /// p65: `.panorama` is the wide scene (975 units) with the sofa widened and the objects in their slots.
    private let welt: ProfilWelt
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
    /// `nacht`: both said good night (p60), the sky is night and the lamp is out, whatever the clock says.
    /// `fest`: a fixed scene without any driver (render board, previews).
    /// p61: `wahl` the room's pieces, `katze` the cat at home (none: no cat), `outfit` opens the outfit
    /// change from the clothes rail and the shoe shelf (none: both just hang there).
    /// `extras` (p63): occasion decoration, sign, shelf and dice, hung in under the figures.
    /// `welt` (p65): the panorama takes its height from the space it gets, draws no wall (its own slower
    /// layer) and lets a tap on the bed or the sofa send both there.
    init(dehnung: CGFloat = 0, straeusse: ZuhauseStraeusse = ZuhauseStraeusse(), ahmedStraeusse: ZuhauseStraeusse = ZuhauseStraeusse(), paarDa: Bool = false,
         extras: ZimmerExtrasStand? = nil, nacht: Bool = false,
         fest: ZuhauseSzenenstand? = nil, wahl: ZimmerWahl = .standard, katze: ZuhauseKatze? = nil, outfit: (() -> Void)? = nil,
         welt: ProfilWelt = .einzel,
         wandDinge: @escaping (Tageszeit) -> AnyView = { _ in AnyView(EmptyView()) },
         @ViewBuilder figur: @escaping (ZuhauseFigur) -> Figur, @ViewBuilder paar: @escaping () -> Paar) {
        self.welt = welt
        self.dehnung = dehnung
        self.straeusse = straeusse
        self.ahmedStraeusse = ahmedStraeusse
        self.paarDa = paarDa
        self.wandDinge = wandDinge
        self.wahl = wahl
        self.katze = katze
        self.outfit = outfit
        self.extras = extras
        self.nacht = nacht
        self.fest = fest != nil
        self.figur = figur
        self.paar = paar
        let jetzt = Tageszeit.um(Date())
        _stand = State(initialValue: fest ?? ZuhauseSzenenstand(zeit: jetzt, ZuhauseAblauf.ruhestand(jetzt)))
    }

    /// Zusammen für echt, oder beide haben das Profil gerade offen (Umarmung, `ZimmerUmarmung`).
    private var paarGemeinsam: Bool { paarDa || (!fest && ZimmerUmarmung.shared.umarmt) }

    private var aktiv: Bool { ZuhauseBelebung.laeuft(an: ZuhauseBelebung.an, aktiv: !fest && sichtbar && scenePhase == .active && !sparmodus && !reduceMotion) }

    /// p70: the partner who is not there sleeps in the bed, whoever is there stands in the room. Not in
    /// the fixed boards and not while they are together for real.
    /// Gym split or both away (panorama only, never in the fixed boards): who is not in the room.
    private var kontext: ZuhauseKontext {
        guard !fest, welt == .panorama else { return .daheim }
        return ZuhauseKontext.bestimme(ahmed: FigurenModell.shared.zustand[.ahmed]?.haupt, annika: FigurenModell.shared.zustand[.annika]?.haupt)
    }

    private var offlineSchlaefer: Person? {
        guard !fest, !paarGemeinsam else { return nil }
        let ich = Raum.shared.ich, verbunden = Raum.shared.verbunden, da = Raum.shared.partnerDa
        return Person.allCases.first { !kontext.abwesende.contains($0) && ZuhauseSzeneLogik.schlaeftOffline($0, ich: ich, verbunden: verbunden, partnerDa: da) }
    }

    /// p70 (40): the lamp glows warmer for every goal of the day that is done; never in the fixed boards.
    private var lampenStaerke: Double {
        guard !fest, let ich = Raum.shared.ich else { return 1 }
        return ZimmerLebenModell.tagesZiele(ich: ich, heute: Datum.text(Date())).lampenFaktor
    }

    /// Das Zimmer pflegt sich selbst (nur im Panorama, nie in den festen Brettern): die Person, deren Tag zählt,
    /// ist die, die die App hält. Ohne Gesundheitsdaten bleibt alles wie gehabt (Bett gemacht, Schuhe da).
    private var zustandPerson: Person? { fest || welt != .panorama ? nil : Raum.shared.ich }

    /// Die Sneaker stehen im Regal, sobald das Schrittziel von heute erreicht ist.
    private var schuheDa: Bool {
        guard let p = zustandPerson else { return true }
        return ZimmerZustandLogik.schuheDa(schritte: HealthModell.shared.heuteSchritte(p), ziel: HealthModell.shared.zielSchritte(p))
    }

    /// Das Bett ist gemacht, solange die Nacht mindestens 75 % des Schlafziels hatte (oder nichts bekannt ist).
    private var bettGemacht: Bool {
        guard let p = zustandPerson else { return true }
        return ZimmerZustandLogik.bettGemacht(schlafMinuten: HealthModell.shared.schlafMinuten(p, Datum.text(Date())), ziel: HealthModell.shared.schlafZielMinuten(p))
    }

    /// The time of day the room is drawn in: the clock's, or night once both said good night.
    private var sicht: Tageszeit { nacht ? .nacht : stand.zeit }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / welt.breite
            let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
            ZStack(alignment: .topLeading) {
                ZuhauseRaumBild(zeit: sicht, wahl: wahl, welt: welt, schuhe: schuheDa)
                wandDinge(sicht)
                if welt == .einzel { schatten }
                if let outfit, welt == .einzel {
                    let schrank = welt.versatz(.kleiderschrank)
                    tippflaeche(ZimmerMoebel.stange.offsetBy(dx: schrank.width, dy: schrank.height), "Kleiderstange, Outfit wechseln", outfit, s, oben)
                    tippflaeche(ZimmerMoebel.regal.offsetBy(dx: schrank.width, dy: schrank.height), "Schuhregal, Outfit wechseln", outfit, s, oben)
                }
                ZStack(alignment: .topLeading) {
                    if let extras { ZimmerExtras(stand: extras, s: s, oben: oben, welt: welt) }
                    bett(s, oben)
                    straeusseSicht(s, oben)
                    if welt == .panorama, !ahmedStraeusse.leer { bordSicht(s, oben) }
                    if let katze {
                        katzeSicht(katze, s, oben)
                    }
                    personen(sitzend: true, s, oben)
                    ZuhauseSofaVorn(welt: welt)
                    if paarGemeinsam {
                        paarSicht(s, oben)
                    } else {
                        personen(sitzend: false, s, oben)
                    }
                }
                .colorMultiply(abdunklung)
                if stand.zeit.dunkel && !nacht {
                    ZuhauseLicht(zeit: stand.zeit, welt: welt, staerke: lampenStaerke)
                }
                if case .beideWeg(let notiz) = kontext { leereStube(notiz, s, oben) }
                if welt == .panorama { moebelTippen(s, oben) }
                if welt == .panorama, !fest { eigeneFigurLenken(s, oben) }
            }
            .coordinateSpace(name: "zuhauseWelt")
        }
        .frame(height: welt == .einzel ? ZuhauseZeichnung.hoehe + dehnung : nil)
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
        switch sicht {
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
        let liegt = stand.liegt && !paarGemeinsam
        let schlaeft = stand.zeit == .nacht || stand.hingelegt
        // p70: the offline partner lies here asleep, also by day and when the other one is up.
        let schlaefer = offlineSchlaefer
        let liegende = ZuhauseSzeneLogik.liegende(beide: liegt, schlaefer: schlaefer).filter { !kontext.abwesende.contains($0) }
        let schlafen: (Person) -> Bool = { schlaeft || $0 == schlaefer }
        // Empty pillows: both while the bed is empty and behind those sitting up; sleepers bring their own.
        let kissen = ZuhauseSzeneLogik.leereKissen(schlafende: Set(liegende.filter(schlafen)))
        let stil = ZuhauseZeichnung.bettStil
        return ZStack {
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: k, y: k)
                SzenenZeichnung.bettHinten(b, stil, kissen: kissen, bild: nil)
            }
            ForEach(liegende, id: \.self) { p in
                figur(ZuhauseFigur(person: p, zustand: schlafen(p) ? .schlaeft : .sitztImBett, groesse: 140 * k, animiert: false, ganzkoerper: false))
                    .position(x: ZuhauseSzeneLogik.kissenX(p) * k, y: (schlafen(p) ? 123.1 : 89.1) * k)
            }
            Canvas { g, _ in
                var b = g
                b.scaleBy(x: k, y: k)
                ZimmerMoebel.bettVorn(b, stil, wahl, herz: liegt, gemacht: bettGemacht)
            }
        }
        .frame(width: 300 * k, height: 220 * k)
        .position(x: ZuhauseZeichnung.bettOrt.x * s + 150 * k, y: oben + ZuhauseZeichnung.bettOrt.y * s + 110 * k)
    }

    /// Up to 3 bouquets on the dresser and one in the vase, each in its own 24 x 40 frame.
    private func straeusseSicht(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let imSchrank = straeusse.imSchrank
        let plaetze = ZuhauseZeichnung.schrankPlaetze.map { welt.ort($0, .kommode) }
        let vasenPlatz = welt.ort(ZuhauseZeichnung.vasenPlatz, .kommode)
        return ZStack(alignment: .topLeading) {
            ForEach(imSchrank.indices, id: \.self) { n in
                strauss(imSchrank[n], plaetze[n], straeusse.frische[imSchrank[n]] ?? .frisch, s, oben)
            }
            if let vase = straeusse.vase {
                strauss(vase, vasenPlatz, straeusse.frische[vase] ?? .frisch, s, oben)
            }
        }
    }

    /// p68: Ahmeds board on the wall right of the bed: up to 3 bouquets and the small vase's one.
    private func bordSicht(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let imBord = ahmedStraeusse.imSchrank
        let plaetze = ZuhauseZeichnung.bordPlaetze
        let vase = ahmedStraeusse.vase
        return ZStack(alignment: .topLeading) {
            Canvas { g, _ in
                var h = g
                h.translateBy(x: 0, y: oben)
                h.scaleBy(x: s, y: s)
                ZuhauseZeichnung.bordZeichnen(h, vase: vase != nil)
            }
            .allowsHitTesting(false)
            ForEach(imBord.indices, id: \.self) { n in
                strauss(imBord[n], plaetze[n], ahmedStraeusse.frische[imBord[n]] ?? .frisch, s, oben)
            }
            if let vase {
                strauss(vase, ZuhauseZeichnung.bordVasenPlatz, ahmedStraeusse.frische[vase] ?? .frisch, s, oben)
            }
        }
    }

    private func strauss(_ id: String, _ fuss: CGPoint, _ frische: StraussFrische, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let mass = ZuhauseZeichnung.strauss
        return StraussView(id: id)
            .frame(width: mass.width * s, height: mass.height * s)
            .modifier(StraussWelke(frische: frische))
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
        // p70: Annika asleep in bed (offline) is at the bed for the cat, too.
        let annikaImBett = offlineSchlaefer == .annika
        let szene = ZimmerKatze.szene(zeit: stand.zeit, annika: annikaImBett ? .bett : stand.annika, welt: welt,
                                       ahmedsSeite: ZimmerNaeheLogik.katzeBeiAhmed(ich: Raum.shared.ich ?? .ahmed, partnerDa: Raum.shared.partnerDa,
                                                                          partnerZuletzt: FigurenModell.shared.partnerZuletztGesehen[(Raum.shared.ich ?? .ahmed).partner], jetzt: Date()))
        let wuenscht = ZimmerKatze.wuenscht(szene.zustand, gestreichelt: k.gestreichelt)
        // p70 (44): feeding and mood come from the points model; the fixed boards show a content cat as before.
        let punkte = PunkteModell.shared
        let pflege = !fest
        let satt = !pflege || punkte.katzeGefuettert()
        let stimmung = pflege ? punkte.katzeStimmung() : nil
        return ZimmerKatzeSicht(id: k.id, szene: szene, wuenscht: wuenscht,
                                geht: stand.gehende.contains(.annika) && !annikaImBett, streichelt: streichelt, s: s, oben: oben,
                                hunger: KatzePflege.hungert(szene.zustand, gefuettert: satt, wuenscht: wuenscht),
                                schnurrt: stimmung.map { KatzePflege.schnurrt(szene.zustand, $0) } ?? false, stimmung: stimmung) {
            streichelt = KatzePflege.fuettertBeimTippen(gestreichelt: k.gestreichelt, gefuettert: satt) ? punkte.katzeFuettern() : k.streicheln()
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
        let schlaefer = offlineSchlaefer
        let weg = kontext.abwesende
        let wer: [Person] = stand.liegt || paarGemeinsam ? [] : [Person.annika, .ahmed].filter { sitzt($0) == sitzend && $0 != schlaefer && !weg.contains($0) }
        return ForEach(wer, id: \.self) { p in person(p, s, oben) }
    }

    /// One figure, always the same view, so a step is a plain move of its position. Sitting: head and
    /// chest only (the half figure) with its lower edge behind the cushion. Standing: the whole body,
    /// feet at 98 % of its height on the floor line.
    /// Panorama: every figure is whole. Whoever sits on the sofa gets the pose `.sitzenSofa`; the soles
    /// are as high over the floor line as the seat plane of the widened sofa (a middle-sized body; the
    /// profile moves other sizes by `sitzKorrektur`).
    private func person(_ p: Person, _ s: CGFloat, _ oben: CGFloat) -> some View {
        let sitzend = sitzt(p)
        let ganz = welt == .panorama || !sitzend
        let hoehe = ganz ? ZuhauseOrte.figurHoehe : ZuhauseOrte.sitzHoehe
        let sohle = ZuhauseOrte.fussY - (sitzend && welt == .panorama ? ZuhauseOrte.sitzSohleHoeher : 0)
        let unten = ganz ? sohle + 0.02 * hoehe : ZuhauseOrte.sitzKante
        let x = ZuhauseOrte.fuss(stand.platz(p), p, welt: welt).x
        let geht = stand.gehende.contains(p)
        let gestik = p == .annika ? stand.geste : nil
        let zustand: FigurZustand = geht ? .laeuft : (gestik?.zustand ?? .ruhig)
        let pose: FigurPose? = sitzend && welt == .panorama ? .sitzenSofa : nil
        // p70: standing about blinks and breathes at a low rate, only while the scene is active.
        let bewegung = ZuhauseSzeneLogik.bewegung(geht: geht, geste: gestik != nil, aktiv: aktiv)
        return figur(ZuhauseFigur(person: p, zustand: zustand, groesse: hoehe * s, animiert: bewegung.animiert, ganzkoerper: ganz, pose: pose, bildrate: bewegung.bildrate))
            .position(x: x * s, y: oben + (unten - hoehe / 2) * s)
    }

    /// The pair for real (hug, kiss), the size of the walkers, in the middle of the room.
    private func paarSicht(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let m = ZuhauseOrte.figurHoehe / 340 * s
        return paar()
            .frame(width: 276, height: 340)
            .scaleEffect(m, anchor: .bottom)
            .position(x: ZuhauseOrte.paarMitte(welt: welt) * s, y: oben + ZuhauseOrte.fussY * s + 0.02 * 340 * m - 170)
    }

    /// Both away: the room stands empty, a small note in the living area says where they are.
    private func leereStube(_ notiz: String, _ s: CGFloat, _ oben: CGFloat) -> some View {
        Text(notiz)
            .font(.footnote.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .position(x: (ProfilSlots.anker(.wohn) + 195) * s, y: oben + 120 * s)
            .allowsHitTesting(false)
            .accessibilityLabel(notiz)
    }

    // MARK: Taps on the furniture (panorama)

    /// Bed and sofa as buttons: a tap sends both there, to lie down or to sit. The tap areas are at least
    /// 44 pt (`ProfilSlots.tippFlaeche`) and lie on top of the figures, which only look.
    private func moebelTippen(_ s: CGFloat, _ oben: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            moebelFlaeche(.bett, "Bett, beide legen sich hin", s, oben) { antippen(.bett) }
            moebelFlaeche(.sofa, "Sofa, beide setzen sich", s, oben) { antippen(.sofa) }
            moebelFlaeche(.kommode, "Kommode, beide gehen zu den Blumen", s, oben) { antippen(.blumen) }
        }
    }

    private func moebelFlaeche(_ d: ProfilDing, _ name: String, _ s: CGFloat, _ oben: CGFloat, tun: @escaping () -> Void) -> some View {
        let r = ProfilSlots.tippFlaeche(d, massstab: s)
        return Color.clear
            .frame(width: r.width * s, height: r.height * s)
            .contentShape(Rectangle())
            .onTapGesture(perform: tun)
            .position(x: r.midX * s, y: oben + r.midY * s)
            .accessibilityLabel(name)
            .accessibilityAddTraits(.isButton)
    }

    /// One's own figure: a tap sends it to the next place, a drag to the place nearest the drop. The
    /// partner stays where it is. Sits over the figure only (the panorama's scroll keeps the rest).
    private func eigeneFigurLenken(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let ich = Raum.shared.ich ?? .ahmed
        let x = ZuhauseOrte.fuss(stand.platz(ich), ich, welt: welt).x
        return Color.clear
            .frame(width: 60 * s, height: 150 * s)
            .contentShape(Rectangle())
            .onTapGesture { lenken(ich, ZuhauseBelebung.weiter(von: stand.platz(ich))) }
            .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .named("zuhauseWelt")).onEnded { w in
                lenken(ich, ZuhauseBelebung.naechsterPlatz(x: w.location.x / s, person: ich, welt: welt))
            })
            .position(x: x * s, y: oben + (ZuhauseOrte.fussY - 75) * s)
            .accessibilityLabel("Deine Figur, Ziel wechseln")
            .accessibilityAddTraits(.isButton)
    }

    /// Only `person` walks to `ziel`; the other one keeps their place.
    private func lenken(_ person: Person, _ ziel: Platz) {
        guard !fest, !paarGemeinsam, stand.gehende.isEmpty, ZuhauseBelebung.an, stand.platz(person) != ziel else { return }
        var neu = Aufstellung(annika: stand.annika, ahmed: stand.ahmed, geste: nil)
        if person == .annika { neu.annika = ziel } else { neu.ahmed = ziel }
        if reduceMotion || sparmodus {
            stand.annika = neu.annika
            stand.ahmed = neu.ahmed
            stand.geste = nil
            stand.liegt = false
            return
        }
        Task { await gehen(zu: neu) }
    }

    /// Both walk to the piece of furniture and stay: at the bed they lie, at the sofa they sit. Ignored
    /// while someone walks, for the pair's real hug and in the fixed boards.
    private func antippen(_ ziel: Platz) {
        guard !fest, !paarGemeinsam, stand.gehende.isEmpty else { return }
        if reduceMotion || sparmodus {
            // No walk: they are simply there.
            stand.annika = ziel
            stand.ahmed = ziel
            stand.geste = nil
            stand.liegt = ziel == .bett
            stand.hingelegt = ziel == .bett
            return
        }
        let neu = Aufstellung(annika: ziel, ahmed: ziel, geste: nil)
        Task { await gehen(zu: neu, hinlegen: ziel == .bett) }
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
    /// `hinlegen` (a tap on the bed): they lie down there, also by day, with closed eyes.
    private func gehen(zu neu: Aufstellung, hinlegen: Bool = false) async {
        guard stand.gehende.isEmpty else { return }
        var gehende = Set<Person>()
        var dauer: TimeInterval = 0
        for p in [Person.annika, .ahmed] where stand.platz(p) != neu.platz(p) {
            gehende.insert(p)
            dauer = max(dauer, ZuhauseOrte.gehdauer(von: stand.platz(p), nach: neu.platz(p), p, welt: welt))
        }
        guard dauer > 0 else {
            // Already there: a tap on the bed lies them down, nothing else changes.
            if hinlegen, !stand.liegt {
                stand.liegt = true
                stand.hingelegt = true
            }
            return
        }
        stand.geste = nil
        stand.liegt = false
        stand.hingelegt = false
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
        stand.liegt = (stand.zeit.dunkel || hinlegen) && neu.annika == .bett && neu.ahmed == .bett
        stand.hingelegt = hinlegen && stand.liegt
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
    var welt: ProfilWelt = .einzel
    var schuhe = true

    var body: some View {
        let zeit = zeit
        let wahl = wahl
        let welt = welt
        let schuhe = schuhe
        Canvas { g, groesse in
            ZuhauseZeichnung.raum(SzenenZeichnung.raum(g, groesse, welt: welt), zeit: zeit, wahl: wahl, welt: welt, schuhe: schuhe)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The sofa's seat cushion in front of whoever sits.
private struct ZuhauseSofaVorn: View {
    var welt: ProfilWelt = .einzel

    var body: some View {
        let welt = welt
        Canvas { g, groesse in
            ZuhauseZeichnung.sofaVorn(SzenenZeichnung.raum(g, groesse, welt: welt), welt: welt)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ZuhauseLicht: View {
    let zeit: Tageszeit
    var welt: ProfilWelt = .einzel
    var staerke: Double = 1

    var body: some View {
        let zeit = zeit
        let welt = welt
        let staerke = staerke
        Canvas { g, groesse in
            ZuhauseZeichnung.licht(SzenenZeichnung.raum(g, groesse, welt: welt), zeit: zeit, welt: welt, staerke: staerke)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
