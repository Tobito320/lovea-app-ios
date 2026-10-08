import SwiftUI

// MARK: - Drawing (half figure 200 x 240, full body 200 x 400 with the head drawn in the half space)

struct Zeichner {
    let z: FigurZustand
    let abz: Set<String>
    /// The only field that changes per frame (`FigurView.leinwand`).
    var t: Double
    let statisch: Bool
    let ganz: Bool
    let haut, haar, iris, top, jackeF, hoseF, schuhF, muetzeF: FigurFarbe
    let straehne: FigurFarbe?
    let frisur, oberteil, brille, bart, gesichtsform, augenform, brauenStil, nasenStil, mundStil: Int
    let ohrring, muetze, jacke, hose, schuhe, koerperform, groesseStufe: Int
    /// p65 D: real index (39...43) of a worn brand top, 0 otherwise. `oberteil` then holds its base shape.
    let marke: Int
    let wimpern, sommersprossen, muttermal, rouge: Bool
    // v3 (Z-24.2): worn shop parts, forwarded to the Zubehoer/ drawers as-is (nil = nothing).
    let tascheId, uhrId, tierId: String?
    /// p56: the worn shop jewelry (`juwel.*`), one per place.
    let juwelen: [String]
    /// `hosenFarbe` below hardcodes a denim wash for hose 0/1/2 unless a free color was picked.
    let hosenHexAktiv: Bool
    // v4 (Z-39.3): free everyday jewelry, 0 = none.
    let kette, ring, armband, uhrAlltag: Int
    /// v5 (fix round 3): chin hair, independent of the mustache.
    let kinnbart: Int
    /// v6 (fix round 4): moles on the cheeks, AirPods in both ears.
    let muttermale, airpods: Bool
    let extras: Set<FigurExtra>
    /// Desk variant at school and work (`Zimmer.tische`).
    let tisch: Int
    let umarmung: Umarmung?
    /// Whose figure: picks the own strokes when drawing together (Brief Z).
    let person: Person?
    /// Gym look (Brief D addendum): Ahmed trains shirtless, Annika in a sleeveless sports top.
    let oberkoerperFrei, sportTop: Bool
    /// Brief F2: set for the redesigned faces, nil draws the old face.
    let neu: NeuesGesicht?
    /// Teil 4: the running exercise, forwarded as-is (nil = pick one at random per person, see `gymGeste`).
    let gymFest: GymGeste?
    /// p65: where the body is on the stage (sits, lies); nil = the state decides.
    let figurPose: FigurPose?

    init(_ a: FigurAussehen, _ z: FigurZustand, _ abz: [String], t: Double, statisch: Bool, ganz: Bool, extras: Set<FigurExtra>, tisch: Int = 0, umarmung: Umarmung? = nil, gymGeste: GymGeste? = nil, pose: FigurPose? = nil) {
        self.figurPose = pose
        self.gymFest = gymGeste
        typealias A = FigurAussehen
        self.umarmung = ganz ? umarmung : nil
        self.z = z
        self.abz = Set(abz)
        self.t = t
        self.statisch = statisch
        self.ganz = ganz
        self.extras = extras
        self.tisch = tisch
        person = a.person
        kette = grenze(a.kette, A.ketten.count)
        ring = grenze(a.ring, A.ringe.count)
        armband = grenze(a.armband, A.armbaender.count)
        uhrAlltag = grenze(a.uhrAlltag, A.uhrenAlltag.count)
        kinnbart = grenze(a.kinnbart, A.kinnbaerte.count)
        muttermale = a.muttermale
        airpods = a.airpods
        let gym = z == .gym && a.person != nil
        let mannImGym = gym && a.person?.figurGeschlecht == .m
        // Fix round 3: "Oben ohne" (oberteil 33) is the bare torso outside the gym too.
        oberkoerperFrei = mannImGym || (z != .abend && grenze(a.oberteil, A.oberteile.count) == 33)
        sportTop = gym && !mannImGym
        haut = A.hautToene.wahl(a.haut).farbe
        let hf = A.haarfarben.wahl(a.haarfarbe)
        if let hex = a.haarfarbeHex, let frei = FigurFarbe(hex: hex) {
            haar = frei
            straehne = nil // free color replaces the swatch, including its highlight streak
        } else {
            haar = hf.farbe
            straehne = hf.straehne
        }
        iris = A.augenfarben.wahl(a.augen).farbe
        tascheId = a.tasche
        uhrId = a.uhr
        juwelen = a.schmuckListe
        tierId = a.tier
        frisur = grenze(a.frisur, A.frisuren.count)
        let eigeneBrille = grenze(a.brille, A.brillen.count)
        // Sun extra: own sunglasses stay, anything else becomes plain sunglasses.
        brille = extras.contains(.sonnenbrille) && !Self.sonnenbrillen.contains(eigeneBrille) ? 3 : eigeneBrille
        bart = grenze(a.bart, A.baerte.count)
        gesichtsform = grenze(a.gesichtsform, A.gesichtsformen.count)
        neu = gesichtsform == 7 ? .b : (gesichtsform == 8 ? .an3 : nil)
        augenform = grenze(a.augenform, A.augenformen.count)
        brauenStil = grenze(a.brauen, A.augenbrauen.count)
        nasenStil = grenze(a.nase, A.nasen.count)
        mundStil = grenze(a.mund, A.muender.count)
        ohrring = grenze(a.ohrringe, A.ohrringArten.count)
        wimpern = a.wimpern
        sommersprossen = a.sommersprossen
        muttermal = a.muttermal
        rouge = a.rouge
        let form = grenze(a.koerperform, A.koerperformen.count)
        // A trained body in the gym: below "Athletisch" the shirtless look switches to it.
        koerperform = mannImGym && A.koerper[form].muskel < 0.6 ? 3 : form
        groesseStufe = grenze(a.groesse, A.groessen.count)
        let freieSchuhe = grenze(a.schuhe, A.schuhArten.count)
        let fotoSchuh = A.fotoSchuhe[freieSchuhe]
        schuhe = fotoSchuh?.basis ?? freieSchuhe
        schuhF = fotoSchuh?.farbe ?? a.schuhfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.schuhfarbe).farbe
        jackeF = a.jackenfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.jackenfarbe).farbe
        let schlafanzug = z == .abend
        let freiesOberteil = grenze(a.oberteil, A.oberteile.count)
        let fotoOberteil = A.fotoOberteile[freiesOberteil]
        let oberteilFarbe = schlafanzug ? FigurFarbe(0xAFC8EE) : (fotoOberteil?.farbe ?? a.oberteilfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.oberteilfarbe).farbe)
        top = oberteilFarbe
        let markenBasis = A.markenBasis[freiesOberteil]
        marke = markenBasis != nil && !schlafanzug && !gym ? freiesOberteil : 0
        oberteil = schlafanzug ? 2 : (gym && !mannImGym ? 11 : (fotoOberteil?.basis ?? markenBasis ?? freiesOberteil))
        jacke = schlafanzug || gym ? 0 : grenze(a.jacke, A.jacken.count)
        let freieHose = grenze(a.hose, A.hosen.count)
        let fotoHose = A.fotoHosen[freieHose]
        hose = schlafanzug ? 3 : (gym ? (mannImGym ? 6 : 9) : (fotoHose?.basis ?? freieHose))
        let freieHosenFarbe = fotoHose?.farbe ?? a.hosenfarbeHex.flatMap { FigurFarbe(hex: $0) } ?? A.farben.wahl(a.hosenfarbe).farbe
        hoseF = schlafanzug ? oberteilFarbe : (gym ? FigurFarbe(0x2B2830) : freieHosenFarbe)
        hosenHexAktiv = !schlafanzug && !gym && (fotoHose != nil || a.hosenfarbeHex.flatMap { FigurFarbe(hex: $0) } != nil)
        let winter = extras.contains(.muetzeSchal)
        muetzeF = winter ? FigurFarbe(0xB33A4A) : A.farben.wahl(a.muetzenfarbe).farbe
        let ohneHut = schlafanzug || z == .rad || z == .schlaeft
        muetze = ohneHut ? 0 : (winter ? 3 : grenze(a.kopfbedeckung, A.kopfbedeckungen.count))
    }

    // MARK: Time

    func bei(_ t: Double) -> Zeichner {
        var z = self
        z.t = t
        return z
    }

    func w(_ tempo: Double, _ versatz: Double = 0) -> CGFloat { CGFloat(sin(t * tempo + versatz)) }

    /// Teil 4: the exercise in the gym (full body only). The running one, else a random pick per person.
    var gymGeste: GymGeste? {
        guard ganz, z == .gym, let person else { return nil }
        return gymFest ?? GymGeste.zufall(person, t: t)
    }

    func zyklus(_ periode: Double, _ versatz: Double = 0) -> CGFloat {
        CGFloat((t + versatz).truncatingRemainder(dividingBy: periode) / periode)
    }

    /// True during the first `anteil` of each period; always true when static, so short effects still show.
    func an(_ periode: Double, _ anteil: CGFloat) -> Bool { statisch || zyklus(periode) < anteil }

    // MARK: Frame

    func zeichne(_ ctx: GraphicsContext, _ size: CGSize) {
        if ganz {
            zeichneGanz(ctx, size)
            return
        }
        var g = ctx
        g.scaleBy(x: size.width / 200, y: size.height / 240)
        g.clip(to: Path(CGRect(x: 0, y: 0, width: 200, height: 240)))
        let bew = bewegung()
        let atem: CGFloat = z == .offline ? 1 : 1.01 + 0.01 * w(2 * Double.pi / 3.6)
        g.translateBy(x: 100, y: 240)
        g.rotate(by: .degrees(bew.winkel))
        g.scaleBy(x: atem, y: atem)
        g.translateBy(x: -100, y: bew.hoch - 240)

        hintergrund(g)
        if extras.contains(.schneeflocken) { schneeflocken(g, CGRect(x: 0, y: 0, width: 200, height: 240)) }
        let arme = mitExtras(pose())
        if let dach = schirmDachMitte(halb: true) { schirmDach(g, dach, radius: 42) }
        haareHinten(haarKontext(g))
        koerper(g)
        if extras.contains(.muetzeSchal) { schal(g, P(100, 160), s: 1) }
        kopfGruppe(g)
        mitte(g)
        let schulter: CGFloat = 40 * breite
        let d = km.armHalb
        // F5: the new faces drew their arms together with the torso in `koerper`.
        if neu == nil {
            if let l = arme.l { arm(g, P(100 - schulter, 184), l, d) }
            if let r = arme.r { arm(g, P(100 + schulter, 184), r, d) }
        }
        if !rechteHandBelegt { requisite(g, arme.r?.hand ?? P(142, 252)) }
        extrasInHand(g, l: arme.l?.hand, r: arme.r?.hand, dach: schirmDachMitte(halb: true), groesse: 1)
        if neu == nil {
            let hand: CGFloat = 9.5 * min(d, 1.12)
            if let l = arme.l { teil(g, kreis(l.hand, hand), haut) }
            if let r = arme.r { teil(g, kreis(r.hand, hand), haut) }
        }
        zubehoer(g, arme)
        if let id = tierId {
            // p48: the pet stands in the lower left corner, still while the figure breathes.
            var boden = ctx
            boden.scaleBy(x: size.width / 200, y: size.height / 240)
            zeichneHaustier(boden, id: id, boden: P(46, 236), groesse: 1.05, nachLinks: false)
        }
        effekte(g)
        abzeichenVorn(g)
    }

    /// Z-24.2/Z-39.3: worn shop parts and free jewelry (bag on the free hand, watch on the other
    /// wrist, necklace at the collar, rings and bracelets on the hands).
    func zubehoer(_ g: GraphicsContext, _ arme: (l: Arm?, r: Arm?)) {
        if let id = tascheId {
            // Fix round 1: bags were drawn at hand-circle size on the hand, i.e. tiny, and in the
            // half figure the resting hand sits below the frame. Now: carried in a raised hand,
            // otherwise on a shoulder strap at the hip.
            let gr = taschenGroesse(id: id, ganz: false)
            if let hand = arme.r?.hand, hand.y < 226 {
                zeichneTasche(g, id: id, an: P(hand.x + 2, hand.y + taschenGriff(id: id) * gr), groesse: gr)
            } else if taschenNeu(id: id) {
                // p48: the detailed bags hang from a strap that meets the top of the bag (no handle of their own).
                zeichneTaschenRiemen(g, id: id, von: P(128, 168), nach: P(150, 206 - 12 * gr), kontrolle: P(160, 176))
                zeichneTasche(g, id: id, an: P(150, 206), groesse: gr, henkel: false)
            } else {
                let strap = bogen(P(128, 168), P(162, 190), P(158, 170))
                linie(g, strap, Pal.dunkel.kontur, 5)
                linie(g, strap, Pal.dunkel.farbe, 3)
                zeichneTasche(g, id: id, an: P(162, 218), groesse: 1.3)
            }
        }
        uhrZeichnen(g, arme.l, groesse: km.armHalb)
        schmuckZeichnen(g, hals: P(100, 162), linkerArm: arme.l, rechterArm: arme.r, groesse: 1)
    }

    /// Wrist, not the hand itself — a hand-centered watch would just replace the hand circle.
    /// A shop watch wins over the free everyday one.
    /// The band wraps across the forearm (fix round 1); `groesse` follows the arm thickness.
    func uhrZeichnen(_ g: GraphicsContext, _ unterarm: Arm?, groesse: CGFloat) {
        guard let a = unterarm, uhrId != nil || uhrAlltag > 0 else { return }
        let handgelenk = zwischen(a.ellbogen, a.hand, 0.74)
        let winkel = atan2(Double(a.hand.y - a.ellbogen.y), Double(a.hand.x - a.ellbogen.x)) - Double.pi / 2
        if let id = uhrId {
            zeichneUhr(g, id: id, an: handgelenk, winkel: winkel, groesse: groesse)
        } else {
            let u = alltagsUhren[uhrAlltag - 1]
            zeichneUhr(g, u.stil, band: u.band, gehaeuse: u.gehaeuse, an: handgelenk, winkel: winkel, groesse: groesse)
        }
    }

    /// Necklaces at the collar; the free ring sits on the left hand, the free bracelet on the right
    /// wrist; a shop ring goes on the right hand, a shop bracelet on the left wrist above the watch.
    func schmuckZeichnen(_ g: GraphicsContext, hals: CGPoint, linkerArm: Arm?, rechterArm: Arm?, groesse: CGFloat) {
        let links = linkerArm.map { (ellbogen: $0.ellbogen, hand: $0.hand) }
        let rechts = rechterArm.map { (ellbogen: $0.ellbogen, hand: $0.hand) }
        if kette > 0 {
            let e = alltagsKetten[kette - 1]
            zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: nil, groesse: groesse)
        }
        if ring > 0 {
            let e = alltagsRinge[ring - 1]
            zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: links, groesse: groesse)
        }
        if armband > 0 {
            let e = alltagsArmbaender[armband - 1]
            zeichneSchmuck(g, e.stil, e.farbe, hals: hals, arm: rechts, groesse: groesse)
        }
        for id in juwelen {
            guard let e = schmuckKatalog[id] else { continue }
            let unterarm = e.stil.ort == .hand && e.stil != .stapelringe ? rechts : links
            zeichneSchmuck(g, id: id, hals: hals, arm: unterarm, groesse: groesse)
        }
    }

    /// Head, face, hair and everything worn on the head, in the half-figure space.
    func kopfGruppe(_ g: GraphicsContext) {
        kopf(g)
        gesicht(g)
        // Before the hair: hair that covers the ears also covers the buds.
        if airpods { airpodsZeichnen(zubehoerKontext(g)) }
        haareVorn(haarKontext(g))
        ohrringeZeichnen(zubehoerKontext(g))
        muetzeZeichnen(zubehoerKontext(g, dy: 0))
        kopfschmuck(zubehoerKontext(g, dy: 0))
        brillen(zubehoerKontext(gedreht(g)))
    }

    /// Under a covering hat the hair stops at the hat line, so tall styles never poke through.
    /// Brief F2: other hair on a new face is narrowed onto it like the accessories; the face's own
    /// hair (`eigeneFrisur`) is already drawn to fit and stays unscaled.
    func haarKontext(_ g: GraphicsContext) -> GraphicsContext {
        var h = g
        if neu != nil && !eigeneFrisur {
            h.translateBy(x: 100, y: 0)
            h.scaleBy(x: 0.81, y: 1)
            h.translateBy(x: -100, y: 0)
        }
        guard (1...4).contains(muetze) || muetze == 7 || muetze == 8 else { return h }
        h.clip(to: Path(CGRect(x: -100, y: 34, width: 400, height: 400)))
        return h
    }

    /// Z-38.2: the body type's measures (`FigurAussehen.koerper`).
    var km: FigurAussehen.Koerper { FigurAussehen.koerper[koerperform] }

    /// Brief F2: Annika's new face sits on 0.88 narrower shoulders (`AN_RUMPF` in bau.py). Half figure only.
    /// Brief F3: face B uses the absolute V path directly, so no extra body-type scaling applies.
    var breite: CGFloat { neu == .b ? 1 : km.breite * (neu == .an3 ? 0.88 : 1) }

    /// Brief F2: the new face draws its own hair only with the person's everyday style; every other
    /// style is drawn narrowed onto the new head (`haarKontext`).
    /// 25.09.: in the gym Annika's own hair is tied back to a high ponytail (`GesichtAn3.gym*`).
    var eigeneFrisur: Bool { (neu == .b && (78...82).contains(frisur)) || (neu == .an3 && (frisur == 56 || z == .gym)) }

    /// Brief F3: V5 in the gym, V4 everywhere else (Ahmed, 25.09.).
    var vForm: VForm { z == .gym ? .gym : .alltag }

    static let sonnenbrillen: Set<Int> = [3, 8, 9, 10, 11]

    func bewegung() -> (winkel: Double, hoch: CGFloat) {
        if let g = gymGeste { return g == .wadenheben ? (0, -wdh * 8) : (0, 0) }
        switch z {
        case .anstupsen: return (zyklus(1.4) < 0.5 ? Double(w(22)) * 6 : 0, 0)
        case .schlaeft: return (-5, 0)
        case .karte: return (Double(w(1.2)) * 3, 0)
        case .nichtStoeren: return (Double(w(4)) * 2.5, 0)
        case .laeuft: return (0, -abs(w(7)) * 3)
        case .rennt: return (3, -abs(w(12)) * 5)
        case .rad: return (0, -abs(w(5)) * 1.5)
        case .zuhause, .mittel, .ruhe: return (Double(w(0.9)) * 1.5, 0)
        case .lacht: return (0, w(20) * 1.5)
        case .gut, .pokal: return (0, -abs(w(3.4)) * 3)
        case .supermarkt: return (0, -abs(w(4)) * 1.5)
        case .faehrt, .fahrschule: return (Double(w(1.8)) * 1.5, 0)
        case .scooter: return (Double(w(2.2)) * 3, -abs(w(6)) * 1.5)
        // Mimik (Runde 3)
        case .zwinkert: return (4, 0)
        case .verliebt: return (Double(w(1.6)) * 4, 0)
        case .sauer: return (Double(w(18)) * 0.8, 0)
        case .schmollt: return (-4, 0)
        case .verlegen: return (Double(w(1.5)) * 3, 0)
        case .muede: return (Double(w(0.8)) * 2, 0)
        case .ueberrascht: return (0, -abs(w(3)) * 3)
        case .lachtTraenen: return (Double(w(1.2)) * 4, w(20) * 1.5)
        case .weint: return (0, w(14) * 0.8)
        case .denkt: return (-4, 0)
        case .feiert: return (0, -abs(w(6)) * 5)
        case .schockiert: return (-2, 0)
        case .daumen: return (0, -abs(w(2.5)) * 2)
        case .tanzt: return (Double(w(5)) * 6, -abs(w(10)) * 3)
        default: return (0, 0)
        }
    }

    var lenkWinkel: Double { Double(w(1.8)) * 12 }

    func amLenkrad(_ grad: Double) -> CGPoint {
        let r = (grad + lenkWinkel) * Double.pi / 180
        return P(100 + 34 * CGFloat(cos(r)), 216 + 34 * CGFloat(sin(r)))
    }

    // MARK: Body

    var aermel: Aermel {
        if oberkoerperFrei || sportTop { return .keine }
        if jacke > 0 { return .lang }
        switch oberteil {
        case 1, 2, 3, 5, 10, 13, 14, 16, 18, 19, 24, 25, 26, 31, 35: return .lang
        case 6, 36, 37: return .keine
        default: return .kurz
        }
    }

    var aermelFarbe: FigurFarbe { jacke > 0 ? jackeF : top }

    /// p56: Camisole und Off-Shoulder-Top liegen als Stoff auf nackter Haut, darunter ist der Körper Haut.
    var oberteilBasis: FigurFarbe { [36, 37].contains(oberteil) ? haut : top }

    /// Face shapes keep the cheekbone width, so hair, ears, glasses and hats fit every shape.
    static let formen: [(stirn: CGFloat, kieferX: CGFloat, kieferY: CGFloat, kinnB: CGFloat, kinnY: CGFloat)] = [
        (44, 58, 128, 34, 152),  // Oval
        (50, 58, 138, 44, 148),  // Rund
        (54, 50, 124, 18, 154),  // Herz
        (54, 58, 146, 42, 150),  // Eckig
        (40, 56, 134, 30, 158),  // Länglich
        (30, 50, 122, 22, 154),  // Diamant
        (38, 54, 140, 18, 162),  // Kantig lang (fix round 4: long, angular jaw, slightly pointed chin)
    ]

    var kopfPfad: Path {
        switch neu {
        case .b: return GesichtB.gesicht
        case .an3: return GesichtAn3.gesicht
        case nil: break
        }
        let f = Self.formen[gesichtsform]
        return Path { p in
            p.move(to: P(100, 30))
            p.addCurve(to: P(158, 94), control1: P(100 + f.stirn, 30), control2: P(158, 56))
            p.addCurve(to: P(100, f.kinnY), control1: P(100 + f.kieferX, f.kieferY), control2: P(100 + f.kinnB, f.kinnY))
            p.addCurve(to: P(42, 94), control1: P(100 - f.kinnB, f.kinnY), control2: P(100 - f.kieferX, f.kieferY))
            p.addCurve(to: P(100, 30), control1: P(42, 56), control2: P(100 - f.stirn, 30))
            p.closeSubpath()
        }
    }
}
