import Foundation

/// Reine Funktionen für Orte: sauberer Name, kurze Adresse, Karten-Links. Kein UI, kein MapKit.
enum OrtName {
    static let maxZeichen = 60

    /// Name aus der Suche: getrimmt, höchstens 60 Zeichen. Steht eine URL darin (`://`, `maps.`),
    /// gilt er als leer und die Straße springt ein. Beides unbrauchbar: leerer Text.
    static func sauber(_ name: String?, strasse: String? = nil) -> String {
        let n = rein(name)
        return n.isEmpty ? rein(strasse) : n
    }

    /// Getrimmt, gekürzt, leer bei URL-artigem Text.
    static func rein(_ text: String?, max: Int = maxZeichen) -> String {
        let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("://") || t.lowercased().contains("maps.") { return "" }
        return String(t.prefix(max)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OrtKurz {
    /// "Straße Nr, Ort". Ohne Straße nur der Ort, ohne Ort die Postleitzahl, sonst nil. Nie eine URL.
    static func adresse(strasse: String?, nr: String?, plz: String?, ort: String?) -> String? {
        let s = OrtName.rein(strasse)
        let n = OrtName.rein(nr)
        let o = OrtName.rein(ort)
        let p = OrtName.rein(plz)
        let strassenteil = s.isEmpty ? "" : (n.isEmpty ? s : "\(s) \(n)")
        let ortsteil = o.isEmpty ? p : o
        let teile = [strassenteil, ortsteil].filter { !$0.isEmpty }
        return teile.isEmpty ? nil : teile.joined(separator: ", ")
    }
}

enum OrtLinks {
    private static let unreserviert = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func appleMapsURL(_ ort: PunktOrt) -> URL {
        let text = "https://maps.apple.com/?ll=\(koordinate(ort))&q=\(kodiert(ort.name))"
        return URL(string: text) ?? URL(string: "https://maps.apple.com/")!
    }

    static func googleMapsURL(_ ort: PunktOrt) -> URL {
        let text = "comgooglemaps://?q=\(kodiert(ort.name))&center=\(koordinate(ort))"
        return URL(string: text) ?? URL(string: "comgooglemaps://")!
    }

    /// Ein Schlüssel je Ort (rund 1 m genau) für den Schnappschuss-Cache.
    static func cacheSchluessel(_ ort: PunktOrt) -> String { koordinate(ort) }

    private static func koordinate(_ ort: PunktOrt) -> String {
        String(format: "%.5f,%.5f", ort.lat, ort.lon)
    }

    private static func kodiert(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserviert) ?? ""
    }
}
