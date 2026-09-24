import SwiftUI

/// Brief G: the places a person can furnish, each with its own saved `Zimmer`. `gym` (Brief S) added
/// at the end so old `profil.raeume` JSON keeps decoding.
enum RaumOrt: String, CaseIterable, Sendable {
    case zuhause, arbeit, schule, gym

    var titel: String {
        switch self {
        case .zuhause: "Zimmer gestalten"
        case .arbeit: "Büro gestalten"
        case .schule: "Klassenzimmer gestalten"
        case .gym: "Gym gestalten"
        }
    }

    /// Brief S: the Einstellungen row per place.
    var symbol: String {
        switch self {
        case .zuhause: "house.fill"
        case .arbeit: "briefcase.fill"
        case .schule: "graduationcap.fill"
        case .gym: "dumbbell.fill"
        }
    }
}

/// Brief S: lets Einstellungen present the editor with `.sheet(item:)`, like `OrteListeView`.
extension RaumOrt: Identifiable {
    var id: Self { self }
}

/// Brief G: one furnished place, `{bett, wand, boden, deko: [String], rahmen: [{slot, medienId}],
/// poster, posterLinks, posterBett, tisch}`. A fixed, designed room: one variant per slot, deco
/// toggled on or off, up to 3 wall posters (right wall everywhere; at home also the left wall and
/// above the bed, where the window would be), up to 3 photo frames. `bett` only matters at home,
/// `tisch` (the desk) at work and school. Reading is tolerant: anything unknown, missing or out of
/// range falls back to the defaults.
struct Zimmer: Equatable, Sendable {
    struct Rahmen: Equatable, Sendable {
        var slot: Int
        var medienId: String
    }

    var bett = 0
    var wand = 0
    var boden = 0
    var deko = Zimmer.standardDeko
    var rahmen: [Rahmen] = []
    var poster = 0
    var tisch = 0
    var posterLinks = 0
    var posterBett = 0

    init(bett: Int = 0, wand: Int = 0, boden: Int = 0, deko: [String] = Zimmer.standardDeko, rahmen: [Rahmen] = [],
         poster: Int = 0, tisch: Int = 0, posterLinks: Int = 0, posterBett: Int = 0) {
        self.bett = bett
        self.wand = wand
        self.boden = boden
        self.deko = deko
        self.rahmen = rahmen
        self.poster = poster
        self.tisch = tisch
        self.posterLinks = posterLinks
        self.posterBett = posterBett
    }

    /// A fresh place with its own default look. Ahmed's home is dark and streetwear (no pink, no
    /// hearts); Annika's stays the soft default.
    init(ort: RaumOrt, person: Person? = nil) {
        switch ort {
        case .zuhause where person == .ahmed:
            self.init(bett: 5, wand: 6, boden: 5,
                      deko: ["ledWeiss", "sneakerRegal", "gaming", "lautsprecher", "teppichSchwarz", "bargeld", "jordanBox"],
                      poster: 13, posterLinks: 11, posterBett: 12)
        case .zuhause: self.init()
        case .arbeit: self.init(wand: 2, boden: 1, deko: ["regal", "pflanze", "kaffeemaschine", "wanduhr"], tisch: 2)
        case .schule: self.init(wand: 0, boden: 0, deko: ["globus", "pinnwand", "wanduhr"], tisch: 0)
        // Brief S: no bed or desk, just the fixed gym backdrop plus a couple of its own pieces. No
        // poster preset (index 5, "Gym Shark", is a drawn one the picker doesn't offer, see
        // `posterAuswahl`) so the default stays pickable from the Poster tab.
        case .gym: self.init(deko: ["lautsprecher"])
        }
    }

    static let betten = ["Holz hell", "Holz dunkel", "Samt rosa", "Metall weiß", "Boxspring grau", "Schwarz"]
    static let tische = ["Holz hell", "Weiß", "Eiche dunkel", "Schwarz"]
    static let waende = ["Creme", "Rosa Streifen", "Salbei", "Himmelblau", "Lavendel", "Nachtblau", "Anthrazit", "Marine"]
    static let boeden = ["Holz hell", "Holz dunkel", "Teppich creme", "Fliesen", "Teppich rosa", "Beton"]
    /// `wo`: the places a piece is offered in (z home, a office, s classroom). The window and the
    /// bedside lamp belong to the bedroom; office and classroom bring their own window.
    static let dekoArten: [(id: String, name: String, wo: String)] = [
        ("fenster", "Fenster", "z"), ("lampe", "Nachttisch-Lampe", "z"),
        ("teppich", "Teppich", "zas"), ("teppichRund", "Runder Teppich", "zas"), ("teppichSchwarz", "Schwarzer Teppich", "zas"),
        ("pflanze", "Pflanze", "zasg"), ("monstera", "Monstera", "zas"), ("kaktus", "Kaktus", "zas"), ("blumen", "Blumenvase", "zas"),
        ("regal", "Regal", "zas"), ("buecherregal", "Bücherregal", "zas"), ("lichterkette", "Lichterkette", "zas"),
        ("lichtervorhang", "Lichtervorhang", "za"), ("ledStreifen", "LED rosa", "zas"), ("ledWeiss", "LED kaltweiß", "zas"),
        ("ledRot", "LED rot", "zas"), ("neonHerz", "Neon-Herz", "za"), ("spiegel", "Spiegel", "za"),
        ("kleiderstange", "Kleiderstange", "z"), ("sneakerRegal", "Sneaker-Regal", "za"), ("jordanBox", "Sneaker-Kartons", "za"),
        ("gaming", "Gaming-Ecke", "za"), ("lautsprecher", "Lautsprecher", "zag"), ("plattenspieler", "Plattenspieler", "za"),
        ("kerze", "Kerzen", "za"), ("sitzsack", "Sitzsack", "za"), ("hanteln", "Hanteln", "za"), ("yogamatte", "Yogamatte", "za"),
        ("pinnwand", "Pinnwand mit Polaroids", "zas"), ("globus", "Globus", "as"), ("stehlampe", "Stehlampe", "zas"),
        ("kopfhoerer", "Kopfhörer", "za"), ("kaffeemaschine", "Kaffeemaschine", "a"), ("wanduhr", "Wanduhr", "zas"),
        ("bargeld", "Bargeld-Stapel", "za"), ("tresor", "Tresor", "za"), ("goldkette", "Goldkette am Ständer", "za"),
    ]
    /// Pieces that share a spot: switching one on switches the others off, so nothing collides.
    static let ausschliessend: [[String]] = [
        ["teppich", "teppichRund", "teppichSchwarz"], ["ledStreifen", "ledWeiss", "ledRot"],
        ["pflanze", "monstera", "stehlampe", "kleiderstange"], ["buecherregal", "gaming"], ["buecherregal", "spiegel"],
        ["buecherregal", "kopfhoerer"], ["wanduhr", "lichterkette"], ["wanduhr", "lichtervorhang"],
    ]
    /// Stored by index, so the list only grows. Most show a real picture from the asset catalog
    /// (`poster-…`); the few drawn ones without a picture are hidden from the picker (`posterAuswahl`)
    /// but still render for anyone who picked them before.
    static let posterArten = ["Kein Poster", "Amore", "Nike", "Jordan", "adidas", "Gym Shark", "Supreme", "Script",
                              "Porsche 911", "BMW M4", "Real Madrid", "ICEMAN", "Meet the Woo 2", "Lamborghini SVJ", "Jordan (gezeichnet)", "23", "Air", "Money",
                              "Take Care", "Scorpion"]
    /// What the poster tab offers, in this order.
    static let posterAuswahl = [0, 11, 12, 18, 19, 13, 8, 9, 17, 2, 3, 6, 4, 10, 1]
    static let standardDeko = ["fenster", "teppich", "lampe", "pflanze"]
    static let rahmenPlaetze = 3

    static func dekoArten(fuer ort: RaumOrt) -> [(id: String, name: String, wo: String)] {
        let buchstabe = String(ort.rawValue.prefix(1))
        return dekoArten.filter { $0.wo.contains(buchstabe) }
    }

    /// Switches `id` on and every piece that shares its spot off.
    mutating func dekoAn(_ id: String) {
        let weg = Set(Self.ausschliessend.filter { $0.contains(id) }.flatMap { $0 })
        deko.removeAll { weg.contains($0) }
        deko.append(id)
        if Self.posterRechtsNachbarn.contains(id) { poster = 0 }
        if Self.posterLinksNachbarn.contains(id) {
            posterLinks = 0
            posterBett = 0
        }
    }

    /// Deco on the big posters' wall spots: the right poster hangs where shelf, neon heart, mirror
    /// and chain would be; the two left ones where the window, the sill and the pinboard are.
    static let posterRechtsNachbarn = ["regal", "neonHerz", "spiegel", "goldkette"]
    static let posterLinksNachbarn = ["fenster", "kaktus", "kerze", "blumen", "pinnwand", "lichtervorhang"]

    /// Hangs poster `i` in a spot and takes down the deco that shares it.
    mutating func posterSetzen(_ pfad: WritableKeyPath<Zimmer, Int>, _ i: Int) {
        self[keyPath: pfad] = i
        guard i > 0 else { return }
        let nachbarn = pfad == \Zimmer.poster ? Self.posterRechtsNachbarn : Self.posterLinksNachbarn
        deko.removeAll { nachbarn.contains($0) }
    }

    /// Pieces switched on together although they share a spot (should never happen).
    var konflikte: [[String]] {
        var liste = Self.ausschliessend.filter { gruppe in gruppe.filter { deko.contains($0) }.count > 1 }
        if poster > 0 { liste += Self.posterRechtsNachbarn.filter { deko.contains($0) }.map { ["poster", $0] } }
        if posterLinks > 0 || posterBett > 0 { liste += Self.posterLinksNachbarn.filter { deko.contains($0) }.map { ["posterLinks", $0] } }
        return liste
    }
    func hat(_ id: String) -> Bool { deko.contains(id) }

    func medien(_ slot: Int) -> String? { rahmen.first { $0.slot == slot }?.medienId }

    static func lesen(_ wert: JSONValue?, ort: RaumOrt = .zuhause, person: Person? = nil) -> Zimmer {
        var z = Zimmer(ort: ort, person: person)
        guard case .object(let o)? = wert else { return z }
        func index(_ schluessel: String, _ anzahl: Int) -> Int? {
            guard case .number(let d)? = o[schluessel], d >= 0, d < Double(anzahl) else { return nil }
            return Int(d)
        }
        z.bett = index("bett", betten.count) ?? z.bett
        z.wand = index("wand", waende.count) ?? z.wand
        z.boden = index("boden", boeden.count) ?? z.boden
        z.tisch = index("tisch", tische.count) ?? z.tisch
        z.poster = index("poster", posterArten.count) ?? z.poster
        z.posterLinks = index("posterLinks", posterArten.count) ?? z.posterLinks
        z.posterBett = index("posterBett", posterArten.count) ?? z.posterBett
        if case .array(let liste)? = o["deko"] {
            let bekannt = Set(dekoArten(fuer: ort).map { $0.id })
            var gesehen = Set<String>()
            var altesPoster = false
            z.deko = liste.compactMap { eintrag -> String? in
                guard case .string(let id) = eintrag else { return nil }
                if id == "poster" { altesPoster = true }
                guard bekannt.contains(id), gesehen.insert(id).inserted else { return nil }
                return id
            }
            // Before the poster tab the "amore" poster was a deco toggle.
            if altesPoster && z.poster == 0 { z.poster = 1 }
        }
        if case .array(let liste)? = o["rahmen"] {
            var belegt = Set<Int>()
            z.rahmen = liste.compactMap { eintrag -> Rahmen? in
                guard case .object(let r) = eintrag, case .number(let d)? = r["slot"], d >= 0, d < Double(rahmenPlaetze),
                      case .string(let id)? = r["medienId"], !id.isEmpty, belegt.insert(Int(d)).inserted else { return nil }
                return Rahmen(slot: Int(d), medienId: id)
            }
        }
        return z
    }

    var json: JSONValue {
        .object([
            "bett": .number(Double(bett)), "wand": .number(Double(wand)), "boden": .number(Double(boden)),
            "deko": .array(deko.map { .string($0) }),
            "rahmen": .array(rahmen.map { .object(["slot": .number(Double($0.slot)), "medienId": .string($0.medienId)]) }),
            "poster": .number(Double(poster)), "tisch": .number(Double(tisch)),
            "posterLinks": .number(Double(posterLinks)), "posterBett": .number(Double(posterBett)),
        ])
    }

    /// `profil.raeume` `{zuhause, arbeit, schule}`; a place missing there falls back to the old
    /// `profil.zimmer` (home only), else to its defaults.
    static func lesen(raeume: JSONValue?, altesZimmer: JSONValue?, ort: RaumOrt, person: Person? = nil) -> Zimmer {
        if case .object(let o)? = raeume, let wert = o[ort.rawValue] { return lesen(wert, ort: ort, person: person) }
        return ort == .zuhause && altesZimmer != nil ? lesen(altesZimmer, ort: .zuhause, person: person) : Zimmer(ort: ort, person: person)
    }
}

@MainActor
extension Zimmer {
    // ponytail: per person via `werte[person]` (like `profil.hintergrund`), not `geteilt` - that one
    // is last-wins across both, so one person's room would overwrite the other's.
    static func von(_ person: Person, ort: RaumOrt = .zuhause) -> Zimmer {
        let werte = EinstellungenModell.shared.werte[person]
        return lesen(raeume: werte?["profil.raeume"], altesZimmer: werte?["profil.zimmer"], ort: ort, person: person)
    }

    /// Writes the whole map (own person), with this place replaced.
    func sichern(ort: RaumOrt) {
        guard let ich = Raum.shared.ich else { return }
        var karte: [String: JSONValue] = [:]
        for o in RaumOrt.allCases { karte[o.rawValue] = (o == ort ? self : Zimmer.von(ich, ort: o)).json }
        EinstellungenModell.shared.setzen("profil.raeume", .object(karte))
    }
}
// MARK: - Drawing

/// The scene split back to front so the view redraws only what moves: `mitte` and `oben` hold the
/// bits that change with `t` (stars, sun, clouds, fairy lights, rain, snow, streaks), `hinten` and
/// `vorn` are still. Drawn one after another they give exactly the one-piece picture.
enum SzenenEbene: CaseIterable, Sendable {
    case hinten, mitte, vorn, oben

    var bewegt: Bool { self == .mitte || self == .oben }
}

extension RaumOrt {
    /// The scene this furnishable place draws.
    var szene: ProfilSzene {
        switch self {
        case .zuhause: .zimmer
        case .arbeit: .arbeit
        case .schule: .schule
        case .gym: .gym
        }
    }
}

/// Brief G: the scenes, drawn in code in the figures' sticker style (soft fills with the thick soft
/// outline of `teil`), so nothing needs an asset. Design space 390 x 430, scaled to the full width and
/// anchored at the bottom: a taller canvas (the stretchy header) only shows more wall or sky above.
/// `t` drives the few moving bits; still callers pass a constant.
enum SzenenZeichnung {
    static let breite: CGFloat = 390
    static let hoehe: CGFloat = 430

    /// The three photo frames on the wall, above the figures' heads.
    static let rahmenRects: [CGRect] = [
        CGRect(x: 156, y: 70, width: 58, height: 72),
        CGRect(x: 226, y: 58, width: 84, height: 64),
        CGRect(x: 322, y: 70, width: 52, height: 66),
    ]

    /// Where the real photo sits inside a frame, `nil` for an unknown slot.
    static func fotoRect(_ slot: Int) -> CGRect? {
        rahmenRects.indices.contains(slot) ? rahmenRects[slot].insetBy(dx: 7, dy: 7) : nil
    }

    static func raum(_ g: GraphicsContext, _ size: CGSize) -> GraphicsContext {
        var r = g
        let s = size.width / breite
        r.translateBy(x: 0, y: size.height - hoehe * s)
        r.scaleBy(x: s, y: s)
        return r
    }

    /// Reaches far above the design space, so a stretched header never shows a gap.
    private static var alles: Path { box(0, -2000, breite, 2800) }

    // MARK: Room

    private static let wandFarben: [UInt32] = [0xF6EBDD, 0xF9DCE3, 0xCFDCC8, 0xD6E8F5, 0xE3D9F2, 0x2E3A5C, 0x2B2D31, 0x1E2A44]
    private static let bodenFarben: [UInt32] = [0xE2C29A, 0x8A5E3F, 0xEFE6DA, 0xE9ECEF, 0xF4C9D4, 0x8C8F95]

    /// Draws `ebenen` of `szene` in order; all four (the default) are the whole picture, which is
    /// what still callers want. `bett`: the optional `szene-bett-<n>` picture for the headboard.
    static func szene(_ g: GraphicsContext, _ szene: ProfilSzene, _ z: Zimmer, nacht: Bool, mitBett: Bool = true, bett: UIImage? = nil,
                      ebenen: [SzenenEbene] = SzenenEbene.allCases, t: Double) {
        for e in ebenen {
            switch szene {
            case .zimmer: zimmer(g, z, nacht: nacht, mitBett: mitBett, bett: bett, e, t: t)
            case .schlafen: zimmer(g, z, nacht: true, mitBett: false, bett: nil, e, t: t)
            case .gym: if e == .hinten { gym(g, z) }
            case .schule: klassenzimmer(g, z, e, t: t)
            case .arbeit: buero(g, z, e, t: t)
            case .draussen(let wetter, let n): draussen(g, wetter: wetter, nacht: n, e, t: t)
            case .unterwegs(let wetter, let n):
                draussen(g, wetter: wetter, nacht: n, e, t: t)
                if e == .oben { fahrtStreifen(g, t: t) }
            }
        }
    }

    private static func zimmer(_ g: GraphicsContext, _ z: Zimmer, nacht: Bool, mitBett: Bool, bett: UIImage?, _ e: SzenenEbene, t: Double) {
        switch e {
        case .hinten:
            wand(g, z.wand)
            boden(g, z.boden)
            if z.hat("fenster") { fensterHinten(g, nacht: nacht) }
        case .mitte:
            if z.hat("fenster") && nacht { fensterSterne(g, t: t) }
        case .vorn:
            if z.hat("fenster") { fensterVorn(g, nacht: nacht) }
            einrichtung(g, z)
            if mitBett {
                var b = g
                b.translateBy(x: 2, y: 222)
                b.scaleBy(x: 0.49, y: 0.49)
                bettHinten(b, z.bett, kissen: [88, 212], bild: bett)
                bettVorn(b, z.bett, herz: false)
            }
            if nacht {
                // The room goes dark except the window glass, so the moon stays bright; the lamp is
                // drawn after the dimming, lit, in a warm pool of light.
                var d = g
                if z.hat("fenster") { d.clip(to: Path(fensterGlas), options: .inverse) }
                d.fill(alles, with: .color(farbe(0x141833).opacity(0.45)))
                if z.hat("lampe") {
                    let c = P(172, 252)
                    g.fill(kreis(c, 130), with: .radialGradient(Gradient(colors: [farbe(0xFFC96B).opacity(0.5), farbe(0xFFB347).opacity(0.15), .clear]), center: c, startRadius: 6, endRadius: 130))
                }
            }
            if z.hat("lampe") { lampe(g) }
            leuchten(g, z, nacht: nacht)
        case .oben:
            lichter(g, z, t: t)
        }
    }

    private static func wand(_ g: GraphicsContext, _ i: Int) {
        let f = FigurFarbe(wandFarben[min(max(i, 0), wandFarben.count - 1)])
        g.fill(alles, with: .color(f.farbe))
        switch i {
        case 1:
            for x in stride(from: CGFloat(0), to: breite, by: 36) { g.fill(box(x, -400, 18, 700), with: .color(f.mal(0.95).farbe)) }
        case 2:
            g.fill(box(0, 214, breite, 86), with: .color(f.mal(0.92).farbe))
            linie(g, strich(P(0, 214), P(breite, 214)), Pal.weiss.farbe, 5)
        case 3:
            for (n, y) in stride(from: CGFloat(-380), to: 300, by: 34).enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 12 : 29), to: breite, by: 34) { g.fill(kreis(P(x, y), 3), with: .color(.white.opacity(0.7))) }
            }
        case 4:
            for (n, y) in stride(from: CGFloat(-380), to: 290, by: 44).enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 20 : 42), to: breite, by: 44) { g.fill(herzPfad(P(x, y), 4), with: .color(f.mal(0.9).farbe)) }
            }
        case 5:
            for k in 0..<40 {
                let p = P(zufall(k * 2) * breite, -380 + zufall(k * 2 + 1) * 660)
                g.fill(stern(p, 2.5 + zufall(k) * 2), with: .color(farbe(0xF5C542).opacity(0.55)))
            }
        case 6:
            // Charcoal with dark acoustic slats.
            for x in stride(from: CGFloat(4), to: breite, by: 14) { g.fill(box(x, -400, 8, 690), with: .color(f.mal(1.18).farbe.opacity(0.5))) }
        default:
            break
        }
        // Soft shade toward the floor.
        g.fill(box(0, 150, breite, 150), with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.08)]), startPoint: P(0, 150), endPoint: P(0, 300)))
    }

    private static func boden(_ g: GraphicsContext, _ i: Int) {
        let f = FigurFarbe(bodenFarben[min(max(i, 0), bodenFarben.count - 1)])
        g.fill(box(0, 300, breite, 500), with: .linearGradient(Gradient(colors: [f.mal(0.88).farbe, f.farbe]), startPoint: P(0, 300), endPoint: P(0, 430)))
        let fuge = f.mal(0.82).farbe
        if i == 0 || i == 1 || i == 3 {
            // Rows get taller toward the viewer: a little perspective without a full grid.
            var y: CGFloat = 300
            var h: CGFloat = 9
            var reihe = 0
            while y < 430 {
                linie(g, strich(P(0, y), P(breite, y)), fuge, 1.5)
                if i != 3 {
                    for x in stride(from: CGFloat(reihe % 3) * 47, to: breite, by: 140) { linie(g, strich(P(x, y), P(x, y + h)), fuge, 1.5) }
                }
                y += h
                h *= 1.28
                reihe += 1
            }
        }
        if i == 3 {
            // Tile seams run toward a point above the middle of the room.
            for k in -9...9 {
                let x = CGFloat(k) * 52
                linie(g, strich(P(195 + x * 150 / 280, 300), P(195 + x, 430)), fuge, 1.5)
            }
        }
        if i == 5 {
            // Concrete: a few large slabs and a faint mottle.
            for y in [CGFloat(330), 380] { linie(g, strich(P(0, y), P(breite, y)), fuge, 1.2) }
            for x in [CGFloat(130), 260] { linie(g, strich(P(x, 300), P(x + (x - 195) * 0.4, 430)), fuge, 1.2) }
            for k in 0..<30 { g.fill(kreis(P(zufall(k + 40) * breite, 304 + zufall(k + 80) * 120), 2.5), with: .color(.white.opacity(0.06))) }
        }
        teil(g, box(-4, 292, breite + 8, 10, 2), i == 5 || i == 1 ? Pal.dunkel : Pal.weiss, 2)
    }

    private static let fensterRahmen = CGRect(x: 22, y: 72, width: 112, height: 124)
    private static var fensterGlas: CGRect { fensterRahmen.insetBy(dx: 7, dy: 7) }

    /// The window in three steps: frame and sky, the twinkling stars (night), then moon or clouds,
    /// bars, sill and curtains in front of them.
    private static func fensterHinten(_ g: GraphicsContext, nacht: Bool) {
        let glas = fensterGlas
        teil(g, Path(roundedRect: fensterRahmen, cornerRadius: 6), Pal.weiss, 3)
        let himmel = nacht ? [farbe(0x1E2A55), farbe(0x3A3F78)] : [farbe(0x8CCBF2), farbe(0xDDF1FB)]
        g.fill(Path(glas), with: .linearGradient(Gradient(colors: himmel), startPoint: P(glas.midX, glas.minY), endPoint: P(glas.midX, glas.maxY)))
    }

    private static func fensterSterne(_ g: GraphicsContext, t: Double) {
        var innen = g
        innen.clip(to: Path(fensterGlas))
        sterne(innen, in: fensterGlas, anzahl: 7, t: t)
    }

    private static func fensterVorn(_ g: GraphicsContext, nacht: Bool) {
        let rahmen = fensterRahmen
        let glas = fensterGlas
        var innen = g
        innen.clip(to: Path(glas))
        if nacht {
            mond(innen, P(104, 104), 11)
        } else {
            wolke(innen, P(62, 156), 0.45, Pal.weiss)
            wolke(innen, P(112, 118), 0.3, Pal.weiss)
        }
        linie(g, strich(P(rahmen.midX, glas.minY), P(rahmen.midX, glas.maxY)), Pal.weiss.farbe, 5)
        linie(g, strich(P(glas.minX, rahmen.midY), P(glas.maxX, rahmen.midY)), Pal.weiss.farbe, 5)
        teil(g, box(14, 192, 128, 9, 3), Pal.weiss, 2)
        // Curtains on a wooden rod.
        let stoff = FigurFarbe(0xF7B6C6)
        let links = Path { p in
            p.move(to: P(10, 64))
            p.addLine(to: P(42, 64))
            p.addQuadCurve(to: P(30, 206), control: P(18, 140))
            p.addLine(to: P(8, 208))
            p.closeSubpath()
        }
        teil(g, links, stoff, 2.5)
        teil(g, links.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 156, ty: 0)), stoff, 2.5)
        linie(g, strich(P(4, 64), P(152, 64)), Pal.holz.kontur, 6)
        linie(g, strich(P(4, 64), P(152, 64)), Pal.holz.farbe, 3.5)
    }

    // MARK: Furnishing (shared by home, office and classroom)

    /// Everything toggled in the deco tab, the poster and the photo frames, back to front. Lights
    /// come later in `leuchten`, after the night dimming.
    private static func einrichtung(_ g: GraphicsContext, _ z: Zimmer) {
        // On the wall. Every piece has its own spot; pieces that would share one exclude each other
        // (`Zimmer.ausschliessend`).
        if z.hat("pinnwand") { pinnwand(g) }
        if z.hat("wanduhr") { uhr(g, P(205, 40)) }
        if z.hat("spiegel") { spiegel(g) }
        if z.hat("kopfhoerer") { kopfhoerer(g) }
        if z.hat("buecherregal") { buecherregal(g) }
        if z.hat("regal") { regal(g, mitTopf: !z.hat("goldkette")) }
        if z.hat("goldkette") { goldkette(g, aufRegal: z.hat("regal")) }
        // Up to three posters: the right wall everywhere, left wall and above the bed only where no
        // window hangs (home without the window).
        posterAufhaengen(g, z.poster, P(320, 150))
        if !z.hat("fenster") { linkePoster(g, links: z.posterLinks, bett: z.posterBett) }
        for r in z.rahmen where rahmenRects.indices.contains(r.slot) { rahmen(g, rahmenRects[r.slot]) }
        // On the window sill; without a window a small wall shelf takes its place.
        if !z.hat("fenster") && (z.hat("kaktus") || z.hat("kerze") || z.hat("blumen")) { teil(g, box(14, 192, 128, 9, 3), Pal.holz, 2) }
        if z.hat("kaktus") { kaktus(g) }
        if z.hat("kerze") { kerzen(g) }
        if z.hat("blumen") { blumen(g) }
        // Along the back wall, left to right
        if z.hat("kaffeemaschine") { kaffeemaschine(g) }
        if z.hat("globus") { globus(g) }
        if z.hat("bargeld") { bargeld(g, nachttisch: !z.hat("lampe")) }
        if z.hat("lautsprecher") { lautsprecher(g) }
        if z.hat("gaming") { gaming(g) }
        if z.hat("sneakerRegal") { sneakerRegal(g) }
        // The right corner: one of plant, monstera, floor lamp, clothes rack
        if z.hat("stehlampe") { stehlampe(g) }
        if z.hat("kleiderstange") { kleiderstange(g) }
        if z.hat("monstera") { monstera(g) }
        if z.hat("pflanze") { pflanze(g) }
        // On the floor, front
        if z.hat("teppich") { teppich(g) }
        if z.hat("teppichRund") { teppichRund(g) }
        if z.hat("teppichSchwarz") { teppichSchwarz(g) }
        if z.hat("plattenspieler") { plattenspieler(g) }
        if z.hat("jordanBox") { jordanBox(g) }
        if z.hat("tresor") { tresor(g) }
        if z.hat("sitzsack") { sitzsack(g) }
        if z.hat("yogamatte") { yogamatte(g) }
        if z.hat("hanteln") { hantelnAmBoden(g) }
    }

    /// Hangs poster `i` centred on `c`: a slight tilt (between -2° and 2°, fixed per poster and
    /// spot), a soft drop shadow and a strip of tape.
    /// The two left posters side by side between the wall's edge and x 200, above the headboard
    /// (top 222); two wide ones shrink together to fit, a single one sits over the bed.
    private static func linkePoster(_ g: GraphicsContext, links: Int, bett: Int) {
        let wl = links > 0 ? posterGroesse(links).width : 0
        let wb = bett > 0 ? posterGroesse(bett).width : 0
        let k = min(1, 182 / max(wl + wb, 1))
        let y: CGFloat = 128
        if links > 0 { posterAufhaengen(g, links, P(8 + wl * k / 2, y), skala: k) }
        if bett > 0 {
            let x = links > 0 ? 18 + wl * k + wb * k / 2 : max(75, 8 + wb * k / 2)
            posterAufhaengen(g, bett, P(x, y), skala: k)
        }
    }

    private static func posterAufhaengen(_ g: GraphicsContext, _ i: Int, _ c: CGPoint, skala: CGFloat = 1) {
        guard i > 0 else { return }
        let s = posterGroesse(i)
        var h = g
        h.translateBy(x: c.x, y: c.y)
        h.scaleBy(x: skala, y: skala)
        h.rotate(by: .degrees(Double((i * 7 + Int(c.x)) % 5) - 2))
        h.fill(box(-s.width / 2 + 2, -s.height / 2 + 3, s.width, s.height, 2), with: .color(.black.opacity(0.22)))
        posterZeichnen(h, i)
        h.fill(box(-8, -s.height / 2 - 4, 16, 7, 1), with: .color(.white.opacity(0.75)))
    }

    /// Everything that glows, drawn after the night dimming so it stays bright. The twinkling
    /// strings come last (`lichter`, layer `oben`); no glow here overlaps them, so the order of
    /// the two never shows.
    private static func leuchten(_ g: GraphicsContext, _ z: Zimmer, nacht: Bool) {
        for (id, hex) in [("ledStreifen", UInt32(0xFF4FA3)), ("ledWeiss", 0xCFE8FF), ("ledRot", 0xFF2A2A)] where z.hat(id) {
            g.fill(box(0, 0, breite, 26), with: .linearGradient(Gradient(colors: [farbe(hex).opacity(nacht ? 0.55 : 0.3), .clear]), startPoint: P(0, 6), endPoint: P(0, 26)))
            g.fill(box(0, 4, breite, 5, 2), with: .color(farbe(hex).opacity(0.95)))
        }
        if z.hat("neonHerz") {
            let c = P(348, 104)
            g.fill(kreis(c, 30), with: .radialGradient(Gradient(colors: [farbe(0xFF3B8A).opacity(nacht ? 0.5 : 0.25), .clear]), center: c, startRadius: 4, endRadius: 30))
            linie(g, herzPfad(c, 15), farbe(0xFF5FA2), 3.5)
            linie(g, herzPfad(c, 15), .white.opacity(0.8), 1.2)
        }
        if nacht && z.hat("kerze") {
            g.fill(kreis(P(75, 178), 26), with: .radialGradient(Gradient(colors: [farbe(0xFFC96B).opacity(0.45), .clear]), center: P(75, 178), startRadius: 2, endRadius: 26))
        }
        if nacht && z.hat("stehlampe") {
            g.fill(kreis(P(372, 158), 70), with: .radialGradient(Gradient(colors: [farbe(0xFFD27A).opacity(0.45), .clear]), center: P(372, 158), startRadius: 4, endRadius: 70))
        }
        if z.hat("gaming") {
            g.fill(box(232, 226, 52, 32, 3), with: .linearGradient(Gradient(colors: [farbe(0x7C4DFF), farbe(0x00C2FF)]), startPoint: P(232, 226), endPoint: P(284, 258)))
        }
    }

    private static func lichter(_ g: GraphicsContext, _ z: Zimmer, t: Double) {
        if z.hat("lichterkette") { lichterkette(g, t: t) }
        if z.hat("lichtervorhang") { lichtervorhang(g, t: t) }
    }
    private static func pinnwand(_ g: GraphicsContext) {
        teil(g, box(148, 150, 64, 52, 4), FigurFarbe(0xC8A27A), 2.5)
        for (i, x) in [CGFloat(154), 174, 194].enumerated() {
            var h = g
            h.translateBy(x: x + 8, y: 174)
            h.rotate(by: .degrees(Double(i - 1) * 6))
            h.fill(box(-8, -12, 16, 20, 1), with: .color(.white))
            h.fill(box(-6, -10, 12, 12), with: .color(farbe([0xF6A9BD, 0x8CCBF2, 0xF2C46D][i])))
            h.fill(kreis(P(0, -12), 1.8), with: .color(Pal.rose.farbe))
        }
    }

    private static func spiegel(_ g: GraphicsContext) {
        teil(g, oval(P(262, 190), 16, 24), Pal.gold, 3)
        g.fill(oval(P(262, 190), 12, 20), with: .linearGradient(Gradient(colors: [farbe(0xE4EEF6), farbe(0xB8C8D6)]), startPoint: P(252, 170), endPoint: P(272, 210)))
        linie(g, strich(P(256, 182), P(264, 174)), .white.opacity(0.8), 2)
    }

    private static func kopfhoerer(_ g: GraphicsContext) {
        g.fill(kreis(P(230, 166), 2), with: .color(Pal.dunkel.farbe))
        linie(g, bogen(P(220, 186), P(240, 186), P(230, 160)), Pal.dunkel.farbe, 3.5)
        teil(g, box(216, 182, 8, 13, 3), Pal.dunkel, 2)
        teil(g, box(236, 182, 8, 13, 3), Pal.dunkel, 2)
    }

    private static func buecherregal(_ g: GraphicsContext) {
        teil(g, box(236, 150, 56, 150, 3), Pal.holz.mal(0.9), 2.5)
        let farben: [UInt32] = [0xE56B6F, 0x6C91C2, 0xF2C46D, 0x8FB8A8, 0xB9A7E0, 0x3B3A44]
        for (reihe, y) in [CGFloat(182), 218, 254, 290].enumerated() {
            g.fill(box(240, y - 1, 48, 4), with: .color(Pal.holz.kontur))
            for k in 0..<5 {
                let h: CGFloat = 20 + CGFloat((k + reihe) % 3) * 5
                g.fill(box(242 + CGFloat(k) * 9, y - h - 1, 8, h, 1), with: .color(farbe(farben[(k + reihe) % farben.count])))
            }
        }
    }

    private static func kaktus(_ g: GraphicsContext) {
        teil(g, box(22, 176, 18, 16, 3), FigurFarbe(0xD9825B), 2)
        teil(g, box(26, 150, 10, 28, 5), Pal.gruen, 2)
        teil(g, box(18, 158, 7, 12, 3.5), Pal.gruen, 1.8)
        teil(g, box(37, 154, 7, 12, 3.5), Pal.gruen, 1.8)
    }

    private static func kerzen(_ g: GraphicsContext) {
        for (x, h) in [(CGFloat(66), CGFloat(18)), (76, 26), (86, 14)] {
            teil(g, box(x - 4, 192 - h, 8, h, 2), Pal.weiss, 1.8)
            teil(g, oval(P(x, 192 - h - 5), 2.6, 4.5), Pal.gelb, 1.2)
        }
    }

    private static func blumen(_ g: GraphicsContext) {
        teil(g, box(106, 172, 16, 20, 5), FigurFarbe(0x9CC7E8), 2)
        let bluete: [UInt32] = [0xFF8FA3, 0xFFD34E, 0xFFFFFF]
        for (i, dx) in [CGFloat(-8), 0, 8].enumerated() {
            linie(g, strich(P(114, 174), P(114 + dx, 156 - CGFloat(i % 2) * 4)), Pal.gruen.farbe, 2)
            teil(g, kreis(P(114 + dx, 154 - CGFloat(i % 2) * 4), 5), FigurFarbe(bluete[i]), 1.8)
        }
    }

    /// A narrow rack in the right corner.
    private static func kleiderstange(_ g: GraphicsContext) {
        linie(g, strich(P(344, 214), P(390, 214)), Pal.silber.kontur, 4)
        for x in [CGFloat(346), 388] { linie(g, strich(P(x, 214), P(x, 300)), Pal.silber.kontur, 4) }
        let farben: [UInt32] = [0x3B3A44, 0xF6EBDD]
        for (i, x) in [CGFloat(360), 376].enumerated() {
            linie(g, bogen(P(x - 7, 222), P(x + 7, 222), P(x, 212)), Pal.silber.kontur, 1.5)
            teil(g, box(x - 9, 222, 18, 46 + CGFloat(i) * 8, 4), FigurFarbe(farben[i]), 2)
        }
    }

    private static func kaffeemaschine(_ g: GraphicsContext) {
        teil(g, box(20, 262, 28, 38, 4), Pal.dunkel, 2.5)
        teil(g, box(24, 284, 20, 6, 1), Pal.silber, 1.5)
        teil(g, box(28, 274, 12, 10, 2), Pal.weiss, 1.5)
        g.fill(kreis(P(40, 268), 2), with: .color(Pal.rose.farbe))
    }

    private static func globus(_ g: GraphicsContext) {
        linie(g, strich(P(76, 300), P(76, 290)), Pal.holz.kontur, 3)
        teil(g, box(66, 296, 20, 5, 2), Pal.holz, 1.8)
        teil(g, kreis(P(76, 276), 14), FigurFarbe(0x7FB6E8), 2)
        teil(g, oval(P(71, 272), 6, 4), Pal.gruen, 1)
        teil(g, oval(P(81, 282), 5, 3), Pal.gruen, 1)
        linie(g, bogen(P(60, 268), P(86, 290), P(62, 290)), Pal.gold.farbe, 1.8)
    }

    private static func lautsprecher(_ g: GraphicsContext) {
        teil(g, box(198, 246, 22, 54, 3), Pal.dunkel, 2.5)
        teil(g, kreis(P(209, 262), 6), Pal.silber, 1.5)
        teil(g, kreis(P(209, 284), 8), Pal.silber, 1.5)
    }

    /// On a low cabinet at the front left, in front of the bed's foot.
    private static func plattenspieler(_ g: GraphicsContext) {
        teil(g, box(120, 342, 50, 22, 3), Pal.holz, 2.5)
        teil(g, box(122, 334, 46, 9, 2), Pal.weiss, 1.8)
        g.fill(oval(P(140, 336), 13, 3.5), with: .color(Pal.dunkel.farbe))
        g.fill(oval(P(140, 336), 3, 1), with: .color(Pal.rose.farbe))
        linie(g, strich(P(162, 332), P(150, 337)), Pal.silber.kontur, 1.5)
    }

    private static func gaming(_ g: GraphicsContext) {
        teil(g, box(224, 262, 64, 8, 2), Pal.dunkel, 2.5)
        for x in [CGFloat(228), 284] { linie(g, strich(P(x, 270), P(x, 300)), Pal.dunkel.kontur, 3) }
        teil(g, box(228, 222, 60, 40, 4), Pal.dunkel, 2.5)
        linie(g, strich(P(258, 262), P(258, 256)), Pal.dunkel.farbe, 5)
    }

    private static func stehlampe(_ g: GraphicsContext) {
        linie(g, strich(P(372, 300), P(372, 168)), Pal.dunkel.kontur, 3.5)
        teil(g, oval(P(372, 300), 10, 3), Pal.dunkel, 1.8)
        let schirm = Path { p in
            p.move(to: P(362, 144))
            p.addLine(to: P(382, 144))
            p.addLine(to: P(388, 168))
            p.addLine(to: P(356, 168))
            p.closeSubpath()
        }
        teil(g, schirm, FigurFarbe(0xF4E4C8), 2.5)
    }

    private static func teppichRund(_ g: GraphicsContext) {
        teil(g, oval(P(250, 388), 112, 32), FigurFarbe(0xB9A7E0), 2.5)
        for r in [CGFloat(84), 56, 28] { linie(g, oval(P(250, 388), r, r * 0.29), .white.opacity(0.45), 2) }
    }

    private static func yogamatte(_ g: GraphicsContext) {
        teil(g, box(282, 400, 96, 16, 5), FigurFarbe(0x8ED8BE), 2)
        teil(g, oval(P(378, 408), 7, 8), FigurFarbe(0x6FC3A6), 2)
    }

    /// Two rows of Jordans in a white shelf against the wall, below the right poster.
    private static func sneakerRegal(_ g: GraphicsContext) {
        teil(g, box(290, 266, 44, 34, 3), Pal.weiss, 2)
        g.fill(box(292, 283, 40, 2), with: .color(Pal.silber.kontur))
        let farben: [(UInt32, UInt32)] = [(0xC8102E, 0x111111), (0xFFFFFF, 0xC8102E), (0x111111, 0xFFFFFF), (0xFFFFFF, 0x111111)]
        for (i, x) in [CGFloat(293), 312, 293, 312].enumerated() {
            let y: CGFloat = i < 2 ? 272 : 289
            teil(g, box(x, y, 18, 8, 3.5), FigurFarbe(farben[i].0), 1.5)
            g.fill(box(x + 6, y + 1, 7, 4, 1), with: .color(farbe(farben[i].1)))
            g.fill(box(x, y + 6, 18, 2), with: .color(.white))
        }
    }

    private static func hantelnAmBoden(_ g: GraphicsContext) {
        for (x, y) in [(CGFloat(236), CGFloat(398)), (262, 404)] {
            linie(g, strich(P(x - 8, y), P(x + 8, y)), Pal.silber.kontur, 3)
            teil(g, box(x - 13, y - 6, 6, 12, 2), Pal.dunkel, 1.5)
            teil(g, box(x + 7, y - 6, 6, 12, 2), Pal.dunkel, 1.5)
        }
    }

    private static func sitzsack(_ g: GraphicsContext) {
        let sack = Path { p in
            p.move(to: P(318, 380))
            p.addCurve(to: P(344, 330), control1: P(312, 352), control2: P(324, 330))
            p.addCurve(to: P(386, 380), control1: P(372, 330), control2: P(392, 356))
            p.closeSubpath()
        }
        teil(g, sack, FigurFarbe(0xF3A5B8), 3)
        linie(g, bogen(P(330, 360), P(372, 362), P(352, 350)), FigurFarbe(0xF3A5B8).mal(0.85).farbe, 2)
    }

    /// A big monstera in the right corner.
    private static func monstera(_ g: GraphicsContext) {
        for (a, l) in [(-25.0, CGFloat(52)), (-5, 64), (15, 58), (32, 44)] {
            var b = g
            b.translateBy(x: 372, y: 318)
            b.rotate(by: .degrees(a))
            teil(b, oval(P(0, -l / 2), 12, l / 2), FigurFarbe(0x3E9B5A), 2.5)
            linie(b, strich(P(-12, -l * 0.55), P(-5, -l * 0.55)), FigurFarbe(0xF6EBDD).farbe, 2.5)
            linie(b, strich(P(0, -4), P(0, -l + 8)), FigurFarbe(0x2E7A45).farbe.opacity(0.9), 1.5)
        }
        teil(g, box(356, 314, 32, 30, 5), FigurFarbe(0xF6EBDD), 2.5)
    }

    private static func teppichSchwarz(_ g: GraphicsContext) {
        teil(g, oval(P(250, 386), 128, 30), FigurFarbe(0x1C1C1F), 2.5)
        linie(g, oval(P(250, 386), 114, 24), .white.opacity(0.35), 1.5)
    }

    /// Cash stacks on the nightstand (its own dark one when the lamp's isn't there).
    private static func bargeld(_ g: GraphicsContext, nachttisch: Bool) {
        if nachttisch {
            for x in [CGFloat(158), 186] { linie(g, strich(P(x, 312), P(x, 324)), Pal.dunkel.kontur, 4) }
            teil(g, box(154, 282, 36, 32, 3), Pal.dunkel, 2.5)
            teil(g, box(150, 276, 44, 8, 3), Pal.dunkel.mal(1.2), 2.5)
        }
        for (i, y) in [CGFloat(270), 263, 256].enumerated() {
            teil(g, box(151 + CGFloat(i % 2) * 2, y, 16, 7, 1.5), FigurFarbe(0x7DBE7A), 1.5)
            g.fill(box(157 + CGFloat(i % 2) * 2, y, 4, 7), with: .color(farbe(0xF2E8C9)))
        }
    }

    /// Stacked sneaker boxes, front left of centre.
    private static func jordanBox(_ g: GraphicsContext) {
        let farben: [(UInt32, UInt32)] = [(0xC8102E, 0x111111), (0xF36F21, 0xFFFFFF), (0x111111, 0xC8102E)]
        for (i, f) in farben.enumerated() {
            let y: CGFloat = 358 - CGFloat(i) * 13
            let x: CGFloat = 178 + CGFloat(i % 2) * 3
            teil(g, box(x, y, 46, 13, 1.5), FigurFarbe(f.0), 1.5)
            g.fill(box(x, y, 46, 3), with: .color(farbe(f.1)))
        }
    }

    /// A small safe with a dial, front centre-right.
    private static func tresor(_ g: GraphicsContext) {
        teil(g, box(240, 336, 40, 36, 4), FigurFarbe(0x4A4C52), 2.5)
        teil(g, kreis(P(256, 354), 7), Pal.silber, 1.5)
        linie(g, strich(P(256, 354), P(256, 349)), Pal.dunkel.farbe, 1.5)
        linie(g, strich(P(270, 348), P(270, 360)), Pal.silber.farbe, 3)
    }

    /// A gold chain on a small bust, on the shelf's right end (or its own little shelf).
    private static func goldkette(_ g: GraphicsContext, aufRegal: Bool) {
        if !aufRegal { teil(g, box(354, 170, 34, 6, 2), Pal.holz, 2) }
        teil(g, box(366, 150, 12, 20, 3), Pal.dunkel, 2)
        teil(g, kreis(P(372, 146), 6), Pal.dunkel, 2)
        linie(g, bogen(P(363, 152), P(381, 152), P(372, 170)), Pal.gold.kontur, 3.5)
        linie(g, bogen(P(363, 152), P(381, 152), P(372, 170)), Pal.gold.farbe, 2)
    }

    private static func lichtervorhang(_ g: GraphicsContext, t: Double) {
        for k in 0..<9 {
            let x = 160 + CGFloat(k) * 20
            let unten: CGFloat = 70 + CGFloat((k * 37) % 5) * 10
            linie(g, strich(P(x, 18), P(x, unten)), Pal.dunkel.farbe.opacity(0.35), 1)
            for y in stride(from: CGFloat(28), through: unten, by: 16) {
                let an = 0.6 + 0.4 * sin(t * 1.7 + Double(k) + Double(y) * 0.1)
                g.fill(kreis(P(x, y), 5), with: .color(farbe(0xFFE3A0).opacity(0.3 * an)))
                g.fill(kreis(P(x, y), 2), with: .color(farbe(0xFFF3C4)))
            }
        }
    }

    // MARK: Posters (the real pictures from the asset catalog; drawn only as a fallback)

    private enum PosterArt: Sendable { case foto, logoWeiss, logo }

    /// Poster index -> image set and how it hangs: `foto` fills a white-bordered print (album
    /// covers, cars, money); `logoWeiss` is a dark logo tinted white on black paper; `logo` keeps
    /// its colours on `papier`.
    private static let posterBilder: [Int: (name: String, art: PosterArt, papier: UInt32)] = [
        2: ("poster-nike", .logoWeiss, 0x111111), 3: ("poster-jordan", .logoWeiss, 0x111111), 4: ("poster-adidas", .logo, 0xFFFFFF),
        6: ("poster-supreme", .logo, 0x111111), 8: ("poster-porsche", .foto, 0xFFFFFF), 9: ("poster-bmw", .foto, 0xFFFFFF),
        10: ("poster-madrid", .logo, 0xFFFFFF), 11: ("poster-iceman", .foto, 0xFFFFFF), 12: ("poster-meet-the-woo-2", .foto, 0xFFFFFF),
        13: ("poster-svj", .foto, 0xFFFFFF), 14: ("poster-jordan", .logoWeiss, 0x111111), 17: ("poster-money", .foto, 0xFFFFFF),
        18: ("poster-take-care", .foto, 0xFFFFFF), 19: ("poster-scorpion", .foto, 0xFFFFFF),
    ]

    /// The print's size, following the picture: square for album covers, landscape for cars and
    /// money, portrait paper for logos and the drawn ones.
    static func posterGroesse(_ i: Int) -> CGSize {
        switch i {
        case 11, 12, 18, 19: CGSize(width: 86, height: 86)
        case 8, 9, 13, 17: CGSize(width: 128, height: 88)
        default: CGSize(width: 72, height: 96)
        }
    }

    /// One wall poster centred on the origin. `i` indexes `Zimmer.posterArten` (0 = none).
    static func posterZeichnen(_ g: GraphicsContext, _ i: Int) {
        guard let eintrag = posterBilder[i], let bild = UIImage(named: eintrag.name), bild.size.width > 0, bild.size.height > 0 else {
            // The drawn poster is 52 x 70; scaled up to the paper size.
            var h = g
            h.scaleBy(x: 72 / 52, y: 96 / 70)
            posterGemalt(h, i)
            return
        }
        let s = posterGroesse(i)
        let blatt = CGRect(x: -s.width / 2, y: -s.height / 2, width: s.width, height: s.height)
        g.fill(Path(blatt), with: .color(farbe(eintrag.papier)))
        switch eintrag.art {
        case .foto:
            // Fills the print inside a thin white border, cropped to the print's shape.
            let innen = blatt.insetBy(dx: 2.5, dy: 2.5)
            let f = max(innen.width / bild.size.width, innen.height / bild.size.height)
            let ziel = CGRect(x: -bild.size.width * f / 2, y: -bild.size.height * f / 2, width: bild.size.width * f, height: bild.size.height * f)
            var h = g
            h.clip(to: Path(innen))
            h.draw(Image(uiImage: bild), in: ziel)
        case .logoWeiss, .logo:
            // Centred with generous padding, never cropped.
            let platz = blatt.insetBy(dx: s.width * 0.16, dy: s.height * 0.2)
            let f = min(platz.width / bild.size.width, platz.height / bild.size.height)
            let ziel = CGRect(x: -bild.size.width * f / 2, y: -bild.size.height * f / 2, width: bild.size.width * f, height: bild.size.height * f)
            if eintrag.art == .logoWeiss {
                var aufgeloest = g.resolve(Image(uiImage: bild).renderingMode(.template))
                aufgeloest.shading = .color(.white)
                g.draw(aufgeloest, in: ziel)
            } else {
                g.draw(Image(uiImage: bild), in: ziel)
            }
        }
        linie(g, Path(blatt), .black.opacity(0.18), 0.8)
    }

    /// The drawn poster (52 x 70), for posters without a picture or a missing asset.
    private static func posterGemalt(_ g: GraphicsContext, _ i: Int) {
        let flaeche = box(-26, -35, 52, 70, 2)
        let grund = posterGrund(i)
        teil(g, flaeche, FigurFarbe(grund), 2)
        var h = g
        h.clip(to: flaeche)
        switch i {
        case 1:
            h.fill(herzPfad(P(0, -8), 13), with: .color(.white))
            schrift(h, "amore", P(0, 20), 9, .white)
        case 2:
            let swoosh = Path { p in
                p.move(to: P(-18, -2))
                p.addQuadCurve(to: P(20, -14), control: P(-10, 16))
                p.addQuadCurve(to: P(-18, -2), control: P(-8, 6))
                p.closeSubpath()
            }
            h.fill(swoosh, with: .color(.white))
            schrift(h, "JUST DO IT.", P(0, 20), 7.5, .white)
        case 3:
            springer(h, farbe(0x111111))
            schrift(h, "23", P(0, 25), 12, .white)
        case 4:
            for k in 0..<3 {
                var s = h
                s.translateBy(x: -12 + CGFloat(k) * 11, y: 2)
                s.rotate(by: .degrees(-30))
                s.fill(box(-3.5, -8 - CGFloat(k) * 5, 7, 16 + CGFloat(k) * 10), with: .color(farbe(0x111111)))
            }
            schrift(h, "adidas", P(0, 24), 9, farbe(0x111111), gewicht: .bold)
        case 5:
            let flosse = Path { p in
                p.move(to: P(-14, 6))
                p.addQuadCurve(to: P(10, -18), control: P(-6, -14))
                p.addQuadCurve(to: P(14, 6), control: P(6, -4))
                p.closeSubpath()
            }
            h.fill(flosse, with: .color(.white))
            schrift(h, "GYMSHARK", P(0, 22), 7.5, .white)
        case 6:
            h.fill(box(-22, -9, 44, 18), with: .color(farbe(0xE0201B)))
            schrift(h, "Supreme", P(0, 0), 10, .white, gewicht: .black, kursiv: true)
        case 7:
            schrift(h, "Stüssy", P(0, -2), 13, farbe(0x111111), gewicht: .semibold, design: .serif, kursiv: true)
            linie(h, bogen(P(-16, 10), P(16, 10), P(0, 16)), farbe(0x111111), 1.5)
        case 8, 9:
            auto(h, farbe(i == 8 ? 0xC9CCD3 : 0xFFFFFF))
            schrift(h, i == 8 ? "PORSCHE" : "BMW", P(0, 22), i == 8 ? 8 : 11, .white, gewicht: .black)
        case 10:
            h.fill(box(-22, -30, 44, 60, 1), with: .color(farbe(0x1C1B1F)))
            let trikot = Path { p in
                p.move(to: P(-8, -22))
                p.addLine(to: P(-18, -16))
                p.addLine(to: P(-14, -6))
                p.addLine(to: P(-10, -8))
                p.addLine(to: P(-10, 16))
                p.addLine(to: P(10, 16))
                p.addLine(to: P(10, -8))
                p.addLine(to: P(14, -6))
                p.addLine(to: P(18, -16))
                p.addLine(to: P(8, -22))
                p.addQuadCurve(to: P(-8, -22), control: P(0, -16))
                p.closeSubpath()
            }
            teil(h, trikot, Pal.weiss, 1.5)
            schrift(h, "7", P(0, -2), 13, farbe(0xC9A227), gewicht: .black)
            schrift(h, "MADRID", P(0, 24), 7, farbe(0xC9A227))
        case 11:
            // ICEMAN: icy shards and cold type on near-black.
            for (k, x) in [CGFloat(-16), -4, 8, 18].enumerated() {
                let spitze = Path { p in
                    p.move(to: P(x - 6, -2))
                    p.addLine(to: P(x, -28 + CGFloat(k % 2) * 8))
                    p.addLine(to: P(x + 6, -2))
                    p.closeSubpath()
                }
                h.fill(spitze, with: .linearGradient(Gradient(colors: [farbe(0xE8F7FF), farbe(0x6FC8F2)]), startPoint: P(x, -28), endPoint: P(x, -2)))
            }
            schrift(h, "ICEMAN", P(0, 14), 11, farbe(0xCFEFFF), gewicht: .black)
            h.fill(stern(P(-14, 26), 3), with: .color(.white))
            h.fill(stern(P(15, 24), 2.2), with: .color(.white))
        case 12:
            // MEET THE WOO 2: a red-orange block, a simple head-and-shoulders silhouette, bold title.
            h.fill(box(-26, 6, 52, 29), with: .color(farbe(0x141414)))
            h.fill(kreis(P(0, -14), 8), with: .color(farbe(0x141414)))
            h.fill(Path(roundedRect: CGRect(x: -15, y: -6, width: 30, height: 16), cornerRadius: 7), with: .color(farbe(0x141414)))
            schrift(h, "MEET THE", P(0, 14), 6, .white, gewicht: .heavy)
            schrift(h, "WOO 2", P(0, 25), 12, .white, gewicht: .black)
        case 13:
            // SVJ: a low, angular supercar in lime.
            let wagen = Path { p in
                p.move(to: P(-23, 4))
                p.addLine(to: P(-21, -2))
                p.addLine(to: P(-6, -8))
                p.addLine(to: P(8, -8))
                p.addLine(to: P(22, -1))
                p.addLine(to: P(23, 4))
                p.closeSubpath()
            }
            h.fill(wagen, with: .color(farbe(0xB8E62E)))
            h.fill(Path { p in
                p.move(to: P(-5, -7))
                p.addLine(to: P(7, -7))
                p.addLine(to: P(12, -3))
                p.addLine(to: P(-9, -3))
                p.closeSubpath()
            }, with: .color(farbe(0x2A2B30)))
            for x in [CGFloat(-13), 13] { h.fill(kreis(P(x, 5), 4), with: .color(farbe(0x2A2B30))) }
            schrift(h, "SVJ", P(0, 22), 15, .white, gewicht: .black, kursiv: true)
        case 14:
            springer(h, farbe(0xC8102E))
            schrift(h, "JORDAN", P(0, 25), 8.5, .white, gewicht: .black)
        case 15:
            schrift(h, "23", P(0, 0), 30, farbe(0xC8102E), gewicht: .black)
        case 16:
            let swoosh = Path { p in
                p.move(to: P(-18, -6))
                p.addQuadCurve(to: P(20, -18), control: P(-10, 12))
                p.addQuadCurve(to: P(-18, -6), control: P(-8, 2))
                p.closeSubpath()
            }
            h.fill(swoosh, with: .color(farbe(0x111111)))
            schrift(h, "AIR", P(0, 18), 16, farbe(0x111111), gewicht: .black, kursiv: true)
        case 17:
            // Money: stacks of green bills and a big dollar sign.
            for (k, y) in [CGFloat(18), 10, 2].enumerated() {
                let x: CGFloat = -18 + CGFloat(k % 2) * 3
                h.fill(box(x, y, 36, 7, 1), with: .color(farbe(0x7DBE7A)))
                h.fill(box(x + 14, y, 6, 7), with: .color(farbe(0xF2E8C9)))
            }
            schrift(h, "$", P(0, -16), 24, farbe(0x7DBE7A), gewicht: .black)
        default:
            break
        }
    }

    /// A jumping basketball player silhouette (no logo).
    private static func springer(_ g: GraphicsContext, _ f: Color) {
        g.fill(kreis(P(3, -20), 4), with: .color(f))
        linie(g, strich(P(2, -15), P(-2, 2)), f, 5)
        linie(g, strich(P(1, -11), P(14, -22)), f, 3.5)
        linie(g, strich(P(0, -10), P(-12, -2)), f, 3.5)
        linie(g, strich(P(-2, 2), P(-14, 14)), f, 4)
        linie(g, strich(P(-2, 2), P(8, 12)), f, 4)
    }

    /// Background colour of each poster.
    private static func posterGrund(_ i: Int) -> UInt32 {
        let grund: [UInt32] = [0xFFFFFF, 0xFF8FA3, 0x111111, 0xC8102E, 0xF4F4F4, 0x2A2B30, 0xFFFFFF, 0xF3EBDC, 0x1C1B1F, 0x1C69D4, 0xF4F1E8,
                               0x0B1A2E, 0xE0501E, 0x111111, 0x111111, 0x111111, 0xF4F4F4, 0x111111]
        return grund[min(max(i, 0), grund.count - 1)]
    }

    /// A generic sports car side view, about 40 wide.
    private static func auto(_ g: GraphicsContext, _ f: Color) {
        let form = Path { p in
            p.move(to: P(-20, 4))
            p.addLine(to: P(-20, -1))
            p.addQuadCurve(to: P(-6, -9), control: P(-16, -8))
            p.addQuadCurve(to: P(10, -6), control: P(2, -12))
            p.addQuadCurve(to: P(20, 0), control: P(18, -4))
            p.addLine(to: P(20, 4))
            p.closeSubpath()
        }
        g.fill(form, with: .color(f))
        g.fill(box(-5, -7, 10, 4, 1.5), with: .color(farbe(0x5A6478)))
        for x in [CGFloat(-12), 12] { g.fill(kreis(P(x, 5), 4), with: .color(farbe(0x111111))) }
    }

    private static func schrift(_ g: GraphicsContext, _ s: String, _ p: CGPoint, _ groesse: CGFloat, _ f: Color,
                                gewicht: Font.Weight = .heavy, design: Font.Design = .default, kursiv: Bool = false) {
        var text = Text(s).font(.system(size: groesse, weight: gewicht, design: design))
        if kursiv { text = text.italic() }
        g.draw(text.foregroundStyle(f), at: p)
    }

    /// Wall shelf with books; the little plant pot gives way to the gold chain.
    private static func regal(_ g: GraphicsContext, mitTopf: Bool) {
        let buecher: [(x: CGFloat, h: CGFloat, f: UInt32)] = [(306, 24, 0xE56B6F), (318, 30, 0x6C91C2), (330, 26, 0xF2C46D), (342, 21, 0x8FB8A8)]
        for b in buecher { teil(g, box(b.x, 170 - b.h, 11, b.h, 2), FigurFarbe(b.f), 2) }
        if mitTopf {
            teil(g, box(364, 156, 16, 14, 3), FigurFarbe(0xE8906A), 2)
            for (dx, a) in [(CGFloat(-4), -30.0), (0, 0), (4, 30)] {
                var b = g
                b.translateBy(x: 372 + dx, y: 156)
                b.rotate(by: .degrees(a))
                teil(b, oval(P(0, -9), 4, 9), Pal.gruen, 1.8)
            }
        }
        teil(g, box(300, 170, 84, 7, 2), Pal.holz, 2.5)
        for x in [CGFloat(314), 370] { linie(g, strich(P(x, 177), P(x, 187)), Pal.holz.kontur, 3) }
    }

    /// Frame with a mat and a drawn stand-in; the real photo is laid over it (`ProfilSzeneHintergrund`).
    private static func rahmen(_ g: GraphicsContext, _ r: CGRect) {
        let nagel = P(r.midX, r.minY - 10)
        linie(g, strich(P(r.minX + 8, r.minY), nagel), Pal.dunkel.farbe.opacity(0.5), 1.2)
        linie(g, strich(P(r.maxX - 8, r.minY), nagel), Pal.dunkel.farbe.opacity(0.5), 1.2)
        g.fill(kreis(nagel, 2), with: .color(Pal.dunkel.farbe))
        g.fill(Path(roundedRect: r.offsetBy(dx: 2, dy: 3), cornerRadius: 3), with: .color(.black.opacity(0.12)))
        teil(g, Path(roundedRect: r, cornerRadius: 3), FigurFarbe(0xD9B26A), 2.5)
        g.fill(Path(r.insetBy(dx: 4, dy: 4)), with: .color(.white))
        let foto = r.insetBy(dx: 7, dy: 7)
        g.fill(Path(foto), with: .linearGradient(Gradient(colors: [farbe(0xFBD3DE), farbe(0xF6A9BD)]), startPoint: P(foto.minX, foto.minY), endPoint: P(foto.maxX, foto.maxY)))
        g.fill(herzPfad(P(foto.midX, foto.midY), min(foto.width, foto.height) * 0.18), with: .color(.white.opacity(0.8)))
    }

    private static func teppich(_ g: GraphicsContext) {
        teil(g, oval(P(250, 384), 134, 30), FigurFarbe(0xF3A5B8), 2.5)
        linie(g, oval(P(250, 384), 116, 22), .white.opacity(0.6), 2.5)
        linie(g, oval(P(250, 384), 100, 16), FigurFarbe(0xF3A5B8).mal(0.85).farbe, 2)
    }

    private static func pflanze(_ g: GraphicsContext) {
        for (a, l) in [(-40.0, CGFloat(34)), (-22, 44), (-4, 50), (24, 44), (52, 36)] {
            var b = g
            b.translateBy(x: 366, y: 288)
            b.rotate(by: .degrees(a))
            teil(b, oval(P(0, -l / 2), 9, l / 2), Pal.gruen, 2.5)
            linie(b, strich(P(0, -4), P(0, -l + 6)), Pal.gruen.mal(0.8).farbe, 1.5)
        }
        let topf = Path { p in
            p.move(to: P(346, 286))
            p.addLine(to: P(386, 286))
            p.addLine(to: P(380, 320))
            p.addLine(to: P(352, 320))
            p.closeSubpath()
        }
        teil(g, topf, FigurFarbe(0xD9825B), 2.5)
    }

    /// Bedside table right of the bed with a small lamp; its glow comes with the night.
    private static func lampe(_ g: GraphicsContext) {
        for x in [CGFloat(158), 186] { linie(g, strich(P(x, 312), P(x, 324)), Pal.holz.kontur, 4) }
        teil(g, box(154, 282, 36, 32, 3), Pal.holz.mal(0.92), 2.5)
        g.fill(kreis(P(172, 298), 2.5), with: .color(Pal.holz.kontur))
        teil(g, box(150, 276, 44, 8, 3), Pal.holz, 2.5)
        teil(g, oval(P(172, 274), 9, 3.5), Pal.gold, 2)
        linie(g, strich(P(172, 272), P(172, 258)), Pal.gold.kontur, 3)
        let schirm = Path { p in
            p.move(to: P(163, 238))
            p.addLine(to: P(181, 238))
            p.addLine(to: P(188, 259))
            p.addLine(to: P(156, 259))
            p.closeSubpath()
        }
        teil(g, schirm, FigurFarbe(0xFFE3B0), 2.5)
    }

    private static func lichterkette(_ g: GraphicsContext, t: Double) {
        let farben: [UInt32] = [0xFFD580, 0xFF9EB5, 0xFFF3C4, 0xA8E0FF]
        for n in 0..<3 {
            let a = P(CGFloat(n) * 130, 36)
            let b = P(CGFloat(n + 1) * 130, 36)
            let c = P((a.x + b.x) / 2, 64)
            linie(g, bogen(a, b, c), Pal.dunkel.farbe.opacity(0.45), 1.5)
            for k in 1..<6 {
                let s = CGFloat(k) / 6
                let u = 1 - s
                let x = u * u * a.x + 2 * u * s * c.x + s * s * b.x
                let y = u * u * a.y + 2 * u * s * c.y + s * s * b.y + 4
                let i = n * 6 + k
                let f = farbe(farben[i % farben.count])
                let an = 0.6 + 0.4 * sin(t * 2.1 + Double(i) * 1.7)
                g.fill(kreis(P(x, y), 8), with: .color(f.opacity(0.35 * an)))
                g.fill(kreis(P(x, y), 3.2), with: .color(f))
            }
        }
    }

    // MARK: Bed (own 300 x 220 space: headboard, pillows, blanket, frame)

    private static let bettStile: [(kopfteil: UInt32, decke: UInt32, gestell: UInt32)] = [
        (0xD9B48A, 0xB9A7E0, 0xC69C6D), (0x7A4E33, 0x8FB8A8, 0x6A432C), (0xE8A0B4, 0xFFD1DC, 0xD98BA0),
        (0xF4F4F4, 0x9CC7E8, 0xE6E6E6), (0x9DA3AE, 0xF1EDE6, 0x8A909B), (0x2B2B30, 0x3B3A44, 0x1F1F24),
    ]

    private static func stil(_ i: Int) -> (kopfteil: UInt32, decke: UInt32, gestell: UInt32) {
        bettStile[min(max(i, 0), bettStile.count - 1)]
    }

    /// Headboard, sheet and the empty pillows (`kissen`: their x centers). A sleeping figure brings
    /// its own pillow (FigurView's "schläft"), so its place stays free.
    static func bettHinten(_ g: GraphicsContext, _ i: Int, kissen: [CGFloat], bild: UIImage?) {
        let k = FigurFarbe(stil(i).kopfteil)
        if let bild {
            g.draw(Image(uiImage: bild), in: CGRect(x: 0, y: 0, width: 300, height: 132))
        } else {
            kopfteil(g, i, k)
        }
        teil(g, box(8, 100, 284, 52, 12), Pal.weiss, 2.5)
        for x in kissen {
            var h = g
            h.translateBy(x: x, y: 104)
            h.rotate(by: .degrees(x < 150 ? -4 : 4))
            teil(h, box(-54, -24, 108, 48, 20), Pal.kissen, 3)
        }
    }

    private static func kopfteil(_ g: GraphicsContext, _ i: Int, _ k: FigurFarbe) {
        switch i {
        case 1:
            teil(g, box(22, 14, 256, 110, 6), k)
            for x in [CGFloat(40), 160] { linie(g, box(x, 34, 100, 70, 6), k.mal(0.8).farbe, 3) }
            teil(g, box(12, 2, 276, 18, 6), k.mix(Pal.weiss, 0.15))
        case 2:
            let bogen = Path { p in
                p.move(to: P(18, 124))
                p.addLine(to: P(18, 50))
                p.addQuadCurve(to: P(150, 0), control: P(18, 0))
                p.addQuadCurve(to: P(282, 50), control: P(282, 0))
                p.addLine(to: P(282, 124))
                p.closeSubpath()
            }
            teil(g, bogen, k)
            var h = g
            h.clip(to: bogen)
            for (n, y) in [CGFloat(34), 64, 94].enumerated() {
                for x in stride(from: CGFloat(n % 2 == 0 ? 50 : 72), to: 270, by: 44) { h.fill(kreis(P(x, y), 3), with: .color(k.mal(0.8).farbe)) }
            }
        case 3:
            teil(g, box(16, 14, 268, 9, 4), k)
            for x in stride(from: CGFloat(48), to: 260, by: 26) { teil(g, box(x, 23, 5, 104, 2), k, 2) }
            for x in [CGFloat(16), 272] {
                teil(g, box(x, 0, 12, 132, 6), k)
                teil(g, kreis(P(x + 6, 0), 8), Pal.gold, 2.5)
            }
        case 4, 5:
            teil(g, box(14, 0, 272, 130, 14), k)
            for x in stride(from: CGFloat(48), to: 270, by: 34) { linie(g, strich(P(x, 10), P(x, 124)), k.mal(0.88).farbe, 2.5) }
        default:
            let platte = Path(roundedRect: CGRect(x: 18, y: 0, width: 264, height: 130), cornerRadius: 40)
            teil(g, platte, k)
            var h = g
            h.clip(to: platte)
            for x in stride(from: CGFloat(50), to: 260, by: 32) { linie(h, strich(P(x, 14), P(x, 130)), k.mal(0.86).farbe, 3) }
        }
    }

    /// Blanket up to the chin with the sheet folded over it, the bed frame in front; `herz` sits
    /// between two heads.
    static func bettVorn(_ g: GraphicsContext, _ i: Int, herz: Bool) {
        let s = stil(i)
        let d = FigurFarbe(s.decke)
        let kante = Path { p in
            p.move(to: P(4, 156))
            p.addCurve(to: P(150, 150), control1: P(40, 140), control2: P(110, 142))
            p.addCurve(to: P(296, 156), control1: P(190, 142), control2: P(260, 140))
        }
        var decke = kante
        decke.addLine(to: P(298, 204))
        decke.addLine(to: P(2, 204))
        decke.closeSubpath()
        teil(g, decke, d)
        var innen = g
        innen.clip(to: decke)
        for x in stride(from: CGFloat(-40), to: 320, by: 28) {
            linie(innen, strich(P(x, 150), P(x + 56, 206)), d.mal(0.9).farbe, 1.5)
            linie(innen, strich(P(x + 56, 150), P(x, 206)), d.mal(0.9).farbe, 1.5)
        }
        if i == 2 {
            for x in stride(from: CGFloat(16), to: 290, by: 28) { innen.fill(kreis(P(x, 180), 2.5), with: .color(.white.opacity(0.7))) }
        }
        linie(g, kante, Pal.weiss.kontur, 17)
        linie(g, kante, Pal.weiss.farbe, 13)
        let gestell = FigurFarbe(s.gestell)
        teil(g, box(0, 198, 300, 14, 5), gestell)
        for x in [CGFloat(12), 276] { teil(g, box(x, 210, 12, 10, 2), gestell.mal(0.85), 2.5) }
        if herz { teil(g, herzPfad(P(150, 60), 11), Pal.rose, 2.5) }
    }

    // MARK: Gym

    private static func gym(_ g: GraphicsContext, _ z: Zimmer) {
        g.fill(alles, with: .linearGradient(Gradient(colors: [farbe(0x3C4048), farbe(0x5A5F68)]), startPoint: P(0, -60), endPoint: P(0, 300)))
        for x in [CGFloat(70), 195, 320] {
            g.fill(kreis(P(x, 30), 60), with: .radialGradient(Gradient(colors: [.white.opacity(0.12), .clear]), center: P(x, 30), startRadius: 4, endRadius: 60))
            g.fill(oval(P(x, 22), 44, 7), with: .color(.white.opacity(0.75)))
        }
        let spiegel = box(168, 64, 206, 132, 6)
        teil(g, spiegel, FigurFarbe(0xB9C7D3), 3)
        var glas = g
        glas.clip(to: spiegel)
        for k in 0..<3 { linie(glas, strich(P(200 + CGFloat(k) * 64, 196), P(250 + CGFloat(k) * 64, 64)), .white.opacity(0.25), 10) }
        g.fill(box(0, 206, breite, 10), with: .color(Pal.rose.farbe))
        // A poster (Brief S) takes the same left-wall spot as the lettering.
        if z.poster == 0 {
            g.draw(Text("LOVEA GYM").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Color.white.opacity(0.2)), at: P(84, 110))
        }
        g.fill(box(0, 300, breite, 500), with: .color(farbe(0x2A2B30)))
        for k in 0..<70 { g.fill(kreis(P(zufall(k * 2) * breite, 304 + zufall(k * 2 + 1) * 126), 1.2), with: .color(.white.opacity(0.12))) }
        linie(g, strich(P(0, 300), P(breite, 300)), .black.opacity(0.4), 3)
        // Dumbbell rack.
        for x in [CGFloat(14), 132] { teil(g, box(x, 222, 8, 98, 3), Pal.dunkel, 2.5) }
        for y in [CGFloat(250), 290] {
            teil(g, box(8, y, 136, 7, 3), Pal.silber, 2.5)
            for k in 0..<4 {
                let c = P(30 + CGFloat(k) * 30, y - 8)
                linie(g, strich(P(c.x - 9, c.y), P(c.x + 9, c.y)), Pal.silber.farbe, 3)
                teil(g, box(c.x - 13, c.y - 7, 6, 14, 2), Pal.dunkel, 2)
                teil(g, box(c.x + 7, c.y - 7, 6, 14, 2), Pal.dunkel, 2)
            }
        }
        // Kettlebell, bottle and a plate leaning on the wall.
        linie(g, bogen(P(146, 312), P(166, 312), P(156, 290)), farbe(0x2F3136), 5)
        teil(g, kreis(P(156, 320), 14), FigurFarbe(0x2F3136), 2.5)
        teil(g, box(184, 296, 12, 28, 4), FigurFarbe(0x5CC6D0), 2)
        teil(g, box(186, 290, 8, 7, 2), Pal.weiss, 1.5)
        teil(g, kreis(P(356, 296), 30), FigurFarbe(0x1F2024), 3)
        linie(g, kreis(P(356, 296), 20), .white.opacity(0.15), 2)
        teil(g, kreis(P(356, 296), 5), Pal.silber, 1.5)
        einrichtungGym(g, z)
    }

    // ponytail: hand-picked free spots in the fixed gym backdrop (mirror x168-374/y64-196, rack
    // x8-144/y222-320, plate x326-386/y266-326), not pixel-checked in Xcode; nudge after a visual pass.
    /// Brief S: gym decor reuses two pieces from the shared deco set (`Zimmer.dekoArten`, flag "g"),
    /// shifted (`translateBy`) into the fixed scene's free floor and wall space, plus a poster on the
    /// left wall (the mirror already owns the right one) that takes the "LOVEA GYM" lettering's spot.
    private static func einrichtungGym(_ g: GraphicsContext, _ z: Zimmer) {
        posterAufhaengen(g, z.poster, P(70, 108))
        if z.hat("lautsprecher") {
            // Shifted right, off the centred figure's standing spot.
            var v = g
            v.translateBy(x: 100, y: 0)
            lautsprecher(v)
        }
        if z.hat("pflanze") {
            var v = g
            v.translateBy(x: -280, y: 76)
            pflanze(v)
        }
    }

    // MARK: School and work (the desk comes with the sitting figure, `FigurView.schreibtisch`)

    private static func klassenzimmer(_ g: GraphicsContext, _ z: Zimmer, _ e: SzenenEbene, t: Double) {
        switch e {
        case .hinten:
            wand(g, z.wand)
            boden(g, z.boden)
            fensterHinten(g, nacht: false)
        case .mitte:
            break
        case .vorn:
            fensterVorn(g, nacht: false)
            // Whiteboard kept above the pinboard's spot (y 150).
            teil(g, box(156, 62, 186, 78, 6), Pal.silber, 3)
            g.fill(box(162, 68, 174, 66), with: .color(.white))
            g.draw(Text("a² + b² = c²").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(farbe(0x3F74B5)), at: P(230, 88))
            linie(g, bogen(P(176, 122), P(250, 118), P(212, 106)), Pal.rose.farbe, 3)
            linie(g, strich(P(270, 108), P(320, 108)), farbe(0x3A2630).opacity(0.6), 2.5)
            linie(g, strich(P(270, 122), P(306, 122)), farbe(0x3A2630).opacity(0.6), 2.5)
            teil(g, box(196, 140, 110, 6, 2), Pal.silber, 2)
            einrichtung(g, z)
            leuchten(g, z, nacht: false)
        case .oben:
            lichter(g, z, t: t)
        }
    }

    private static func buero(_ g: GraphicsContext, _ z: Zimmer, _ e: SzenenEbene, t: Double) {
        switch e {
        case .hinten:
            wand(g, z.wand)
            boden(g, z.boden)
            let rahmen = CGRect(x: 22, y: 72, width: 118, height: 120)
            teil(g, Path(roundedRect: rahmen, cornerRadius: 6), Pal.weiss, 3)
            let glas = rahmen.insetBy(dx: 7, dy: 7)
            var innen = g
            innen.clip(to: Path(glas))
            innen.fill(Path(glas), with: .linearGradient(Gradient(colors: [farbe(0x8CCBF2), farbe(0xDDF1FB)]), startPoint: P(0, glas.minY), endPoint: P(0, glas.maxY)))
            for (x, h) in [(CGFloat(28), CGFloat(52)), (48, 76), (70, 40), (88, 64), (108, 88), (126, 50)] {
                innen.fill(box(x, glas.maxY - h, 18, h), with: .color(farbe(0x8E9BB0)))
            }
            linie(g, strich(P(rahmen.midX, glas.minY), P(rahmen.midX, glas.maxY)), Pal.weiss.farbe, 5)
            teil(g, box(14, 192, 128, 9, 3), Pal.weiss, 2)
            einrichtung(g, z)
            leuchten(g, z, nacht: false)
        case .mitte, .vorn:
            break
        case .oben:
            lichter(g, z, t: t)
        }
    }

    private static func uhr(_ g: GraphicsContext, _ c: CGPoint) {
        teil(g, kreis(c, 17), Pal.weiss, 3)
        linie(g, strich(c, P(c.x, c.y - 11)), farbe(0x3A2630), 2.5)
        linie(g, strich(c, P(c.x + 8, c.y + 3)), farbe(0x3A2630), 2.5)
    }

    // MARK: Outside

    private static func draussen(_ g: GraphicsContext, wetter: ProfilSzene.Wetter, nacht: Bool, _ e: SzenenEbene, t: Double) {
        switch e {
        case .hinten:
            let himmel: (oben: UInt32, unten: UInt32)
            switch (wetter, nacht) {
            case (.sonne, false): himmel = (0x5FB7EE, 0xCFEBFA)
            case (.wolken, false): himmel = (0x8FB2CE, 0xDCE7EF)
            case (.regen, false): himmel = (0x6A7888, 0xA9B4BF)
            case (.schnee, false): himmel = (0xAEBCCB, 0xEDF1F5)
            case (.sonne, true): himmel = (0x0B1230, 0x2A3468)
            case (_, true): himmel = (0x161D2E, 0x3A4458)
            }
            g.fill(alles, with: .linearGradient(Gradient(colors: [farbe(himmel.oben), farbe(himmel.unten)]), startPoint: P(0, -100), endPoint: P(0, 290)))
        case .mitte:
            // The clouds drift over the moon, so it moves with them.
            if nacht {
                if wetter == .sonne || wetter == .wolken { sterne(g, in: CGRect(x: 0, y: -80, width: breite, height: 300), anzahl: 30, t: t) }
                mond(g, P(316, 92), 24)
            } else if wetter == .sonne {
                sonne(g, P(316, 92), t: t)
            }
            wolken(g, wetter: wetter, nacht: nacht, t: t)
        case .vorn:
            landschaft(g, wetter: wetter, nacht: nacht)
            laterne(g, P(40, 334), nacht: nacht)
            if wetter == .regen { g.fill(oval(P(232, 392), 34, 6), with: .color(farbe(0xBFD9EE).opacity(0.55))) }
        case .oben:
            if wetter == .regen { regen(g, t: t) }
            if wetter == .schnee { schnee(g, t: t) }
        }
    }

    /// Clouds drift slowly to the right and wrap around.
    private static func wolken(_ g: GraphicsContext, wetter: ProfilSzene.Wetter, nacht: Bool, t: Double) {
        let zug = CGFloat((t * 4).truncatingRemainder(dividingBy: 520))
        func x(_ start: CGFloat) -> CGFloat { (start + zug).truncatingRemainder(dividingBy: 520) - 65 }
        switch wetter {
        case .sonne:
            if !nacht { wolke(g, P(x(90), 66), 0.7, Pal.weiss) }
        case .wolken:
            let f = nacht ? FigurFarbe(0x5A6478) : Pal.weiss
            wolke(g, P(x(60), 70), 0.9, f)
            wolke(g, P(x(250), 50), 0.7, f)
            wolke(g, P(x(420), 120), 0.6, f)
        case .regen, .schnee:
            let f = nacht ? FigurFarbe(0x3E4656) : FigurFarbe(0x8D97A3)
            for (n, start) in [CGFloat(40), 170, 300, 430].enumerated() { wolke(g, P(x(start), 50 + CGFloat(n % 2) * 26), 1.1, f) }
        }
    }

    private static func landschaft(_ g: GraphicsContext, wetter: ProfilSzene.Wetter, nacht: Bool) {
        let schnee = wetter == .schnee
        func ton(_ hex: UInt32) -> FigurFarbe { nacht ? FigurFarbe(hex).mix(FigurFarbe(0x1A2244), 0.55) : FigurFarbe(hex) }
        let huegel = Path { p in
            p.move(to: P(-10, 300))
            p.addQuadCurve(to: P(200, 262), control: P(80, 246))
            p.addQuadCurve(to: P(400, 288), control: P(320, 262))
            p.addLine(to: P(400, 700))
            p.addLine(to: P(-10, 700))
            p.closeSubpath()
        }
        teil(g, huegel, ton(schnee ? 0xEEF3F7 : 0x8CCB7E), 3)
        let krone = ton(schnee ? 0xDCE6EE : 0x5DAA5A)
        let stamm = ton(0x9A6B47)
        baum(g, P(78, 268), 1, krone, stamm)
        baum(g, P(128, 272), 0.72, krone, stamm)
        baum(g, P(352, 282), 0.8, krone, stamm)
        let boden = Path { p in
            p.move(to: P(-10, 318))
            p.addQuadCurve(to: P(400, 312), control: P(200, 296))
            p.addLine(to: P(400, 700))
            p.addLine(to: P(-10, 700))
            p.closeSubpath()
        }
        teil(g, boden, ton(schnee ? 0xE2E9F0 : 0x69B25D), 3)
        let weg = Path { p in
            p.move(to: P(190, 305))
            p.addLine(to: P(224, 305))
            p.addLine(to: P(320, 700))
            p.addLine(to: P(110, 700))
            p.closeSubpath()
        }
        g.fill(weg, with: .color(ton(schnee ? 0xF6F8FA : 0xE9D8B4).farbe))
        if wetter == .sonne && !nacht {
            let blueten: [UInt32] = [0xFF8FA3, 0xFFD34E, 0xFFFFFF, 0xB9A7E0]
            for k in 0..<14 {
                let bx = zufall(k * 5) * breite
                guard bx < 110 || bx > 330 else { continue }
                g.fill(kreis(P(bx, 330 + zufall(k * 5 + 1) * 90), 3), with: .color(farbe(blueten[k % blueten.count])))
            }
        }
    }

    /// Travelling: light streaks rushing past, over the outdoor scene.
    private static func fahrtStreifen(_ g: GraphicsContext, t: Double) {
        for k in 0..<14 {
            let y = 110 + zufall(k + 500) * 300
            let laenge = 40 + zufall(k + 600) * 90
            let weg = Double(breite + 260)
            let p = (t * (320 + Double(zufall(k + 700)) * 240) + Double(zufall(k + 800)) * weg).truncatingRemainder(dividingBy: weg)
            let x = breite + 130 - CGFloat(p)
            linie(g, strich(P(x, y), P(x + laenge, y)), .white.opacity(0.4 + 0.3 * Double(zufall(k + 900))), 2.5)
        }
    }

    private static func baum(_ g: GraphicsContext, _ fuss: CGPoint, _ s: CGFloat, _ krone: FigurFarbe, _ stamm: FigurFarbe) {
        teil(g, box(fuss.x - 5 * s, fuss.y - 40 * s, 10 * s, 40 * s, 3 * s), stamm, 2.5)
        verbunden(g, [
            kreis(P(fuss.x, fuss.y - 64 * s), 24 * s),
            kreis(P(fuss.x - 17 * s, fuss.y - 46 * s), 18 * s),
            kreis(P(fuss.x + 17 * s, fuss.y - 46 * s), 18 * s),
        ], krone, 3)
    }

    private static func laterne(_ g: GraphicsContext, _ fuss: CGPoint, nacht: Bool) {
        let mast = strich(fuss, P(fuss.x, fuss.y - 150))
        linie(g, mast, Pal.dunkel.kontur, 8)
        linie(g, mast, Pal.dunkel.farbe, 5)
        let kopf = P(fuss.x, fuss.y - 162)
        if nacht {
            g.fill(kreis(kopf, 70), with: .radialGradient(Gradient(colors: [farbe(0xFFD27A).opacity(0.5), .clear]), center: kopf, startRadius: 6, endRadius: 70))
        }
        teil(g, box(kopf.x - 9, kopf.y - 10, 18, 22, 4), FigurFarbe(nacht ? 0xFFE7A8 : 0xF4F1E8), 3)
        teil(g, box(kopf.x - 12, kopf.y - 17, 24, 7, 3), Pal.dunkel, 2.5)
    }

    private static func sonne(_ g: GraphicsContext, _ c: CGPoint, t: Double) {
        g.fill(kreis(c, 64), with: .radialGradient(Gradient(colors: [farbe(0xFFE58A).opacity(0.6), .clear]), center: c, startRadius: 20, endRadius: 64))
        for k in 0..<12 {
            let a = Double(k) * Double.pi / 6 + t * 0.15
            let dx = CGFloat(cos(a))
            let dy = CGFloat(sin(a))
            let laenge: CGFloat = k % 2 == 0 ? 50 : 44
            linie(g, strich(P(c.x + dx * 36, c.y + dy * 36), P(c.x + dx * laenge, c.y + dy * laenge)), Pal.gelb.farbe, 4)
        }
        teil(g, kreis(c, 28), Pal.gelb)
    }

    private static func mond(_ g: GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        g.fill(kreis(c, r * 2), with: .radialGradient(Gradient(colors: [farbe(0xFFF1B8).opacity(0.25), .clear]), center: c, startRadius: r * 0.8, endRadius: r * 2))
        var h = g
        h.clip(to: kreis(P(c.x + r * 0.55, c.y - r * 0.35), r * 0.9), options: .inverse)
        h.fill(kreis(c, r), with: .color(farbe(0xFFF1B8)))
    }

    private static func sterne(_ g: GraphicsContext, in r: CGRect, anzahl: Int, t: Double) {
        for k in 0..<anzahl {
            let p = P(r.minX + zufall(k * 3) * r.width, r.minY + zufall(k * 3 + 1) * r.height)
            let gross = zufall(k * 3 + 2) > 0.7
            var h = g
            h.opacity = 0.55 + 0.45 * sin(t * (1.2 + Double(zufall(k * 3 + 2)) * 1.5) + Double(k))
            h.fill(stern(p, gross ? 4.5 : 2.2), with: .color(farbe(0xFFF6D5)))
        }
    }

    private static func wolke(_ g: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ f: FigurFarbe) {
        verbunden(g, [
            kreis(P(c.x - 26 * s, c.y + 4 * s), 18 * s), kreis(P(c.x, c.y - 8 * s), 26 * s),
            kreis(P(c.x + 28 * s, c.y + 2 * s), 20 * s), box(c.x - 44 * s, c.y + 4 * s, 92 * s, 18 * s, 9 * s),
        ], f, 3)
    }

    private static func regen(_ g: GraphicsContext, t: Double) {
        for k in 0..<70 {
            let p = CGFloat((t * (0.9 + Double(zufall(k + 100)) * 0.4) + Double(zufall(k + 200))).truncatingRemainder(dividingBy: 1))
            let x = zufall(k) * (breite + 60) - p * 40
            let y = -40 + p * 480
            linie(g, strich(P(x, y), P(x - 4, y + 14)), .white.opacity(0.55), 1.6)
        }
    }

    private static func schnee(_ g: GraphicsContext, t: Double) {
        for k in 0..<45 {
            let p = CGFloat((t * (0.08 + Double(zufall(k + 100)) * 0.05) + Double(zufall(k + 200))).truncatingRemainder(dividingBy: 1))
            let x = zufall(k) * breite + CGFloat(sin(t * 0.8 + Double(k))) * 8
            g.fill(kreis(P(x, -40 + p * 480), 2 + zufall(k + 300) * 1.8), with: .color(.white.opacity(0.9)))
        }
    }

    // MARK: Helpers

    private static func farbe(_ hex: UInt32) -> Color { FigurFarbe(hex).farbe }

    /// Stable 0..<1 per index, so a still frame always looks the same.
    private static func zufall(_ i: Int) -> CGFloat {
        let x = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(x - x.rounded(.down))
    }

    private static func stern(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path { p in
            p.move(to: P(c.x, c.y - r))
            p.addQuadCurve(to: P(c.x + r, c.y), control: c)
            p.addQuadCurve(to: P(c.x, c.y + r), control: c)
            p.addQuadCurve(to: P(c.x - r, c.y), control: c)
            p.addQuadCurve(to: P(c.x, c.y - r), control: c)
            p.closeSubpath()
        }
    }
}
