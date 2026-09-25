import Foundation

/// Z-41: pure map logic - what the figure wears and does, the label texts and the night look.
/// Everything here is tested in `KarteLogikTests`.
enum KarteLogik {
    // MARK: - Figure

    private static let regen: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
    private static let schnee: Set<Int> = [71, 73, 75, 77, 85, 86]

    /// WMO weather code (Open-Meteo), temperature, daylight and charging -> the figure's extras.
    /// Rain, drizzle, showers and thunder -> umbrella; clear or mainly clear by day -> sunglasses;
    /// below 5 °C -> hat and scarf; snow -> snowflakes; charging -> phone with the white cable.
    static func extras(wetterCode: Int?, temperatur: Double?, tag: Bool, laedt: Bool) -> Set<FigurExtra> {
        var extras: Set<FigurExtra> = []
        if let code = wetterCode {
            if regen.contains(code) { extras.insert(.schirm) }
            if schnee.contains(code) { extras.insert(.schneeflocken) }
            if tag, code == 0 || code == 1 { extras.insert(.sonnenbrille) }
        }
        if let temperatur, temperatur < 5 { extras.insert(.muetzeSchal) }
        if laedt { extras.insert(.handyKabel) }
        return extras
    }

    private static let gesten: Set<FigurZustand> = [.anstupsen, .kuss, .herz, .lacht, .anstossen, .pokal]
    private static let bewegungen: Set<FigurZustand> = [.laeuft, .rennt, .rad, .faehrt, .scooter, .zug]
    private static let ortZustaende: Set<FigurZustand> = [.zuhause, .gym, .schule, .arbeit, .fahrschule, .supermarkt]

    /// The figure on the map. A live gesture always wins. A fresh movement from the location fix
    /// comes next (Spec 7 "läuft, wenn der Partner unterwegs ist" - the partner's app is usually
    /// closed, so `anzeige` alone would almost always say `.offline`). An offline partner then
    /// stands at the saved place they are at (`Ort.kategorie` uses `FigurZustand` raw values), else relaxed.
    static func kartenZustand(anzeige: FigurZustand, bewegung: String?, ortKategorie: String?, sekundenAlt: TimeInterval) -> FigurZustand {
        if gesten.contains(anzeige) { return anzeige }
        if sekundenAlt < 300, let b = bewegung.flatMap(FigurZustand.init(rawValue:)), bewegungen.contains(b) { return b }
        guard anzeige == .offline else { return anzeige }
        if let ort = ortKategorie.flatMap(FigurZustand.init(rawValue:)), ortZustaende.contains(ort) { return ort }
        return .ruhig
    }

    // MARK: - Texts

    /// "vor 5 min" for the label under the figure. `nil` while the fix is live (under a minute),
    /// from the future (clock skew) or unknown.
    static func alterText(sekunden: TimeInterval) -> String? {
        guard sekunden.isFinite, sekunden >= 60 else { return nil }
        let minuten = Int(sekunden / 60)
        if minuten < 60 { return "vor \(minuten) min" }
        let stunden = minuten / 60
        if stunden < 24 { return "vor \(stunden) h" }
        let tage = stunden / 24
        return tage == 1 ? "vor 1 Tag" : "vor \(tage) Tagen"
    }

    static func akkuText(_ akku: Double) -> String { "\(Int((akku * 100).rounded())) %" }

    static func akkuSymbol(_ akku: Double, laedt: Bool) -> String {
        if laedt { return "battery.100.bolt" }
        switch akku {
        case ..<0.13: return "battery.0"
        case ..<0.38: return "battery.25"
        case ..<0.63: return "battery.50"
        case ..<0.88: return "battery.75"
        default: return "battery.100"
        }
    }

    /// "3,2 km entfernt" (info card line 3, profile preview). German decimal comma.
    static func entfernungText(_ meter: Double) -> String {
        if meter < 50 { return "bei dir" }
        if meter < 995 { return "\(Int((meter / 10).rounded()) * 10) m entfernt" }
        let km = meter / 1000
        if km < 9.95 { return String(format: "%.1f km entfernt", km).replacingOccurrences(of: ".", with: ",") }
        return "\(Int(km.rounded())) km entfernt"
    }

    // MARK: - Night look

    /// Z-41.2: 20:00 to 07:00 Berlin the map goes dark, whatever the system appearance.
    static func istNacht(_ datum: Date) -> Bool {
        let stunde = Calendar.berlin.component(.hour, from: datum)
        return stunde >= 20 || stunde < 7
    }
}
