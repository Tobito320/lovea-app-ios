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
        default: return .draussen(wetter: wetter(code: wetterCode), nacht: tag.map { !$0 } ?? (stunde >= 20 || stunde < 6))
        }
    }

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

    /// Only a real activity shows over the scene's own state (gym curls, standing in the room).
    static func eigenerZustand(_ z: FigurZustand) -> Bool {
        z == .kuss || z == .herz || z == .anstupsen || z == .lacht || z == .anstossen || z == .pokal || FigurZustand.mimik.contains(z)
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
