import Foundation

/// p61: what the shared home looks like beyond the base room: wall colour, rug, bedding, lamp. Each
/// kind has a free standard (the room as p58 drew it) and a few pieces from the shop's "Zimmer" tab.
/// The room is shared, so ownership counts for both and the choice is one shared setting (whoever
/// sets it last wins, like the wallpaper). This file is data and rules only; the drawing is `ZimmerMoebel`.
enum ZimmerArt: String, CaseIterable, Sendable {
    case wand, teppich, bettwaesche, lampe
}

/// How a piece looks: the first three are patterns for walls and bedding, then rug shapes, then lamp shapes.
enum ZimmerMuster: Sendable {
    case glatt, herzen, punkte, streifen
    case rund, wolke, herz
    case schirm, rattan, laterne
}

struct ZimmerTeil: Sendable, Equatable {
    let id: String
    let art: ZimmerArt
    let muster: ZimmerMuster
    /// Main colour and the pattern's colour (hex).
    let farbe: UInt32
    let zweit: UInt32
}

enum ZimmerTeile {
    /// The room as it always was: the standard of each kind. The bedding standard is the bed's own blanket.
    static let standard: [ZimmerArt: ZimmerTeil] = [
        .wand: ZimmerTeil(id: "standard.wand", art: .wand, muster: .herzen, farbe: 0xFBEFE0, zweit: 0xFF3B5C),
        .teppich: ZimmerTeil(id: "standard.teppich", art: .teppich, muster: .rund, farbe: 0xF4C9D4, zweit: 0xFFFFFF),
        .bettwaesche: ZimmerTeil(id: "standard.bettwaesche", art: .bettwaesche, muster: .glatt, farbe: 0xFFD1DC, zweit: 0xFFFFFF),
        .lampe: ZimmerTeil(id: "standard.lampe", art: .lampe, muster: .schirm, farbe: 0xFFD34E, zweit: 0xFFF8DC),
    ]

    /// Every shop piece, by its catalog id (`katalog.json`, category "zimmer").
    static let alle: [String: ZimmerTeil] = Dictionary(uniqueKeysWithValues: [
        ZimmerTeil(id: "zimmer.wand-rose", art: .wand, muster: .herzen, farbe: 0xF8DCE3, zweit: 0xFF3B5C),
        ZimmerTeil(id: "zimmer.wand-salbei", art: .wand, muster: .punkte, farbe: 0xDDEBD9, zweit: 0x5DBB7A),
        ZimmerTeil(id: "zimmer.wand-himmel", art: .wand, muster: .streifen, farbe: 0xDCEAF7, zweit: 0x7FB6E8),
        ZimmerTeil(id: "zimmer.teppich-wolke", art: .teppich, muster: .wolke, farbe: 0xFFF6EC, zweit: 0xE9DCCB),
        ZimmerTeil(id: "zimmer.teppich-herz", art: .teppich, muster: .herz, farbe: 0xE8788C, zweit: 0xFFFFFF),
        ZimmerTeil(id: "zimmer.bett-salbei", art: .bettwaesche, muster: .punkte, farbe: 0xA9CDB0, zweit: 0xFFFFFF),
        ZimmerTeil(id: "zimmer.bett-streifen", art: .bettwaesche, muster: .streifen, farbe: 0xE6F0FA, zweit: 0x7FB6E8),
        ZimmerTeil(id: "zimmer.bett-herzen", art: .bettwaesche, muster: .herzen, farbe: 0xFFF1E6, zweit: 0xE8788C),
        ZimmerTeil(id: "zimmer.lampe-rattan", art: .lampe, muster: .rattan, farbe: 0xC9A56A, zweit: 0x9C7B45),
        ZimmerTeil(id: "zimmer.lampe-laterne", art: .lampe, muster: .laterne, farbe: 0xFFFFFF, zweit: 0xF4B6C6),
    ].map { ($0.id, $0) })
}

/// The chosen piece per kind; missing means the standard.
struct ZimmerWahl: Equatable, Sendable {
    private(set) var gewaehlt: [ZimmerArt: String] = [:]

    static let standard = ZimmerWahl()

    /// The piece in use for `art`: the chosen one, else the standard.
    func teil(_ art: ZimmerArt) -> ZimmerTeil {
        gewaehlt[art].flatMap { ZimmerTeile.alle[$0] } ?? ZimmerTeile.standard[art]!
    }

    /// Only the shop's own piece, `nil` for the standard (the bedding keeps the bed's blanket then).
    func eigenes(_ art: ZimmerArt) -> ZimmerTeil? { gewaehlt[art].flatMap { ZimmerTeile.alle[$0] } }

    func traegt(_ id: String) -> Bool { gewaehlt.values.contains(id) }

    /// A wahl showing only this piece, for the shop's tiles.
    static func nur(_ id: String) -> ZimmerWahl { ZimmerWahl().einrichten(id) }

    /// Sets the piece in the place of its kind; unknown ids change nothing.
    func einrichten(_ id: String) -> ZimmerWahl {
        guard let t = ZimmerTeile.alle[id] else { return self }
        var neu = self
        neu.gewaehlt[t.art] = id
        return neu
    }

    /// Back to the standard of the piece's kind, if exactly this piece is in use.
    func wegraeumen(_ id: String) -> ZimmerWahl {
        guard let t = ZimmerTeile.alle[id], gewaehlt[t.art] == id else { return self }
        var neu = self
        neu.gewaehlt[t.art] = nil
        return neu
    }

    // MARK: Saving

    static let schluessel = "zuhause.zimmer"

    var json: JSONValue {
        var o: [String: JSONValue] = [:]
        for (art, id) in gewaehlt { o[art.rawValue] = .string(id) }
        return .object(o)
    }

    /// Unknown kinds and ids are dropped, so an old or damaged value reads as the standard.
    init(json: JSONValue?) {
        guard case .object(let o)? = json else { return }
        for (schluessel, wert) in o {
            guard let art = ZimmerArt(rawValue: schluessel), case .string(let id) = wert, ZimmerTeile.alle[id]?.art == art else { continue }
            gewaehlt[art] = id
        }
    }

    init() {}

    /// Both of them own the room: a piece bought by either is free for both.
    static func gehoert(_ id: String, besitz: BesitzLogik.Ergebnis) -> Bool {
        Person.allCases.contains { besitz.besitzt(id, $0) }
    }
}

@MainActor
extension ZimmerWahl {
    static var aktuell: ZimmerWahl { ZimmerWahl(json: EinstellungenModell.shared.geteilt(schluessel)) }

    func sichern() { EinstellungenModell.shared.setzen(Self.schluessel, json) }
}
