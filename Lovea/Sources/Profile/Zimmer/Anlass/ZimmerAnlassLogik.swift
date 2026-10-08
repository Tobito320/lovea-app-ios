import Foundation

/// 11: Jahreszeit nach Datum. Die Deko selbst kommt aus `ZimmerDeko`, das hier ist nur die reine Einteilung.
enum ZimmerJahreszeitLogik {
    enum Zeit: Equatable, Sendable { case fruehling, sommer, herbst, winter }

    static func zeit(am tag: Date) -> Zeit {
        switch Calendar.berlin.component(.month, from: tag) {
        case 3...5: .fruehling
        case 6...8: .sommer
        case 9...11: .herbst
        default: .winter
        }
    }

    static func name(_ z: Zeit) -> String {
        switch z {
        case .fruehling: "Frühling"
        case .sommer: "Sommer"
        case .herbst: "Herbst"
        case .winter: "Winter"
        }
    }
}

/// 12: Geburtstagszimmer. Am Geburtstag selbst: Torte, Katze mit Partyhut, Wünsche als Karten.
enum ZimmerGeburtstagLogik {
    /// Wer heute Geburtstag hat (am Tag selbst, nicht am Vortag).
    static func geburtstagskind(am tag: Date) -> Person? {
        let c = Calendar.berlin.dateComponents([.month, .day], from: tag)
        return Person.allCases.first { p in
            let g = BesondereTage.geburtstag(p)
            return g.monat == c.month && g.tag == c.day
        }
    }

    /// Drei kurze Wünsche für `kind`, von der anderen Person.
    static func wuensche(fuer kind: Person) -> [String] {
        let n = kind.name
        return [
            "Alles Gute, \(n). Schön, dass es dich gibt.",
            "Ich wünsche dir einen Tag nur für dich.",
            "Auf ein neues Jahr mit dir.",
        ]
    }
}

/// 13: Traumblase über der schlafenden Figur.
enum ZimmerTraumLogik {
    static func schluessel(_ p: Person) -> String { "zimmer.wunsch.\(p.rawValue)" }

    /// Kurzer Text für die Blase: zuletzt gewählte Stimmung, sonst der Wunsch, sonst nichts.
    static func text(stimmung: Gefuehl?, wunsch: String?) -> String? {
        if let stimmung { return stimmung.name }
        let w = (wunsch ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return w.isEmpty ? nil : String(w.prefix(40))
    }
}

/// 15: Partnerlook. Gleiche Hauptfarbe am Oberteil.
enum ZimmerOutfitLogik {
    static func farbe(_ a: FigurAussehen) -> String {
        if let hex = a.oberteilfarbeHex, !hex.isEmpty { return hex.uppercased() }
        return "i\(a.oberteilfarbe)"
    }

    static func gleich(_ a: FigurAussehen, _ b: FigurAussehen) -> Bool { farbe(a) == farbe(b) }

    static func tagesSchluessel(_ tag: String) -> String { "lovea.zimmer.outfit.\(tag)" }
}

/// 17: Radio mit "unser Song".
enum ZimmerRadioLogik {
    static let schluessel = "zimmer.unsersong"

    /// Aus einer Eingabe einen sauberen Spotify-Track-Link machen, sonst nil.
    static func link(aus eingabe: String) -> String? {
        let t = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if let id = AlltagLogik.spotifyId(in: t) { return AlltagLogik.spotifyLink(id) }
        return nil
    }
}

/// 20: Regentag am Ort der anderen Person.
enum ZimmerRegenLogik {
    static func regnet(code: Int?) -> Bool { ProfilSzene.wetter(code: code) == .regen }
}
