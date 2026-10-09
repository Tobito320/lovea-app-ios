import Foundation

// Health-Coach, Marker: die Antwort darf am Ende bis zu vier Zeilen der Form `[[name: a | b]]` tragen (nur wenn die
// App `marker: true` mitschickt, siehe server/coach-anweisung.js). Hier werden sie vom Text getrennt und geprüft.
// Alles Unbekannte oder Kaputte verschwindet still, damit nie ein halber Marker im Chat steht. Reine Logik.

enum CoachMarker {
    struct Punkt: Equatable, Sendable {
        let label: String
        let wert: Double
    }

    enum Ziel: String, Equatable, Sendable {
        case schritte, training, gewicht, verlauf

        var standardText: String {
            switch self {
            case .schritte: "Schritte öffnen"
            case .training: "Training öffnen"
            case .gewicht: "Gewicht öffnen"
            case .verlauf: "Verlauf öffnen"
            }
        }
    }

    /// `[[essen: Name | mahlzeit | kcal | Eiweiß | Kohlenhydrate | Fett]]`, die letzten drei optional.
    struct Essen: Equatable, Sendable {
        let name: String
        let art: MahlzeitArt?
        let kcal: Int
        let protein: Double?
        let kohlenhydrate: Double?
        let fett: Double?
    }

    enum Art: Equatable, Sendable {
        case essen(Essen)
        case weiter([String])
        case chart(titel: String, punkte: [Punkt])
        case fortschritt(label: String, aktuell: Double, ziel: Double)
        case gehe(ziel: Ziel, beschriftung: String)
        case erinnerung(stunde: Int, minute: Int, text: String)
        case ziel(String)
    }

    struct Zerlegt: Equatable, Sendable {
        let text: String
        let marker: [Art]
    }

    static let maxMarker = 4

    /// Trennt die Marker vom Text. Der Text kommt ohne Marker und ohne Leerraum am Ende zurück.
    static func zerlegen(_ roh: String) -> Zerlegt {
        var text = ""
        var marker: [Art] = []
        var rest = Substring(roh)
        while let start = rest.range(of: "[[") {
            text.append(contentsOf: rest[rest.startIndex..<start.lowerBound])
            let danach = rest[start.upperBound...]
            guard let ende = danach.range(of: "]]") else {
                // Antwort mitten im Marker abgeschnitten: nur wegwerfen, wenn es nach Marker aussieht.
                if !klingtNachMarker(danach) { text.append(contentsOf: rest[start.lowerBound...]) }
                rest = rest[rest.endIndex...]
                break
            }
            let inhalt = danach[danach.startIndex..<ende.lowerBound]
            if let (name, argument) = kopf(inhalt) {
                if marker.count < maxMarker, let art = pruefen(name: name, argument: argument) { marker.append(art) }
            } else {
                text.append(contentsOf: rest[start.lowerBound..<ende.upperBound])
            }
            rest = danach[ende.upperBound...]
        }
        text.append(contentsOf: rest)
        return Zerlegt(text: text.trimmingCharacters(in: .whitespacesAndNewlines), marker: marker)
    }

    // MARK: - Einzelne Marker

    private static let schluessel: Set<String> = ["weiter", "chart", "fortschritt", "gehe", "erinnerung", "ziel", "essen"]
    private static let verbotenImZiel = ["kg", "abnehm", "kcal", "kalor", "gewicht", "defizit", "körperfett"]

    /// `name: argument` mit einem Namen aus Buchstaben. Alles andere ist kein Marker und bleibt Text.
    private static func kopf(_ inhalt: Substring) -> (name: String, argument: String)? {
        guard inhalt.count <= 800, let doppelpunkt = inhalt.firstIndex(of: ":") else { return nil }
        let name = inhalt[inhalt.startIndex..<doppelpunkt].trimmingCharacters(in: .whitespaces).lowercased()
        guard (1...12).contains(name.count), name.allSatisfy(\.isLetter) else { return nil }
        let argument = inhalt[inhalt.index(after: doppelpunkt)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (name, argument)
    }

    private static func klingtNachMarker(_ danach: Substring) -> Bool {
        let anfang = danach.prefix { $0 != ":" }.trimmingCharacters(in: .whitespaces)
        return anfang.count <= 12 && anfang.allSatisfy(\.isLetter)
    }

    private static func felder(_ argument: String) -> [String] {
        argument.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func zahl(_ text: String) -> Double? {
        guard let wert = Double(text.replacingOccurrences(of: ",", with: ".")), wert.isFinite else { return nil }
        return wert
    }

    private static func pruefen(name: String, argument: String) -> Art? {
        guard schluessel.contains(name) else { return nil }
        let teile = felder(argument)
        switch name {
        case "weiter":
            let fragen = teile.filter { !$0.isEmpty && $0.count <= 60 }.prefix(3)
            return fragen.isEmpty ? nil : .weiter(Array(fragen))
        case "chart":
            guard teile.count >= 4, !teile[0].isEmpty else { return nil }
            let punkte = teile.dropFirst().compactMap(punkt).prefix(8)
            return punkte.count >= 3 ? .chart(titel: String(teile[0].prefix(40)), punkte: Array(punkte)) : nil
        case "fortschritt":
            guard teile.count == 3, !teile[0].isEmpty, let aktuell = zahl(teile[1]), let ziel = zahl(teile[2]),
                  aktuell >= 0, ziel > 0 else { return nil }
            return .fortschritt(label: String(teile[0].prefix(40)), aktuell: aktuell, ziel: ziel)
        case "gehe":
            guard let ziel = Ziel(rawValue: teile[0].lowercased()) else { return nil }
            let beschriftung = teile.count > 1 ? String(teile[1].prefix(24)) : ""
            return .gehe(ziel: ziel, beschriftung: beschriftung.isEmpty ? ziel.standardText : beschriftung)
        case "essen":
            guard teile.count >= 3, !teile[0].isEmpty, let kcal = zahl(teile[2]), (1...5000).contains(kcal.rounded()) else { return nil }
            let werte = teile.dropFirst(3).prefix(3).map { zahl($0).map { min(max($0, 0), 1000) } }
            func wert(_ i: Int) -> Double? { i < werte.count ? werte[i] : nil }
            return .essen(Essen(name: String(teile[0].prefix(60)), art: mahlzeitArt(teile[1]), kcal: Int(kcal.rounded()),
                                protein: wert(0), kohlenhydrate: wert(1), fett: wert(2)))
        case "erinnerung":
            guard teile.count >= 2, let uhrzeit = uhrzeit(teile[0]) else { return nil }
            let text = String(teile[1...].joined(separator: " ").prefix(60))
            return text.isEmpty ? nil : .erinnerung(stunde: uhrzeit.stunde, minute: uhrzeit.minute, text: text)
        default:
            let text = String(argument.prefix(100)).trimmingCharacters(in: .whitespaces)
            let klein = text.lowercased()
            guard !text.isEmpty, !verbotenImZiel.contains(where: { klein.contains($0) }) else { return nil }
            return .ziel(text)
        }
    }

    private static func mahlzeitArt(_ text: String) -> MahlzeitArt? {
        switch text.lowercased() {
        case "fruehstueck", "frühstück": .fruehstueck
        case "mittag", "mittagessen": .mittag
        case "abend", "abendessen": .abend
        case "snack": .snack
        default: nil
        }
    }

    /// "Mo 8200" oder "12.10. 7400": das letzte Wort ist der Wert, der Rest das Label.
    private static func punkt(_ teil: String) -> Punkt? {
        guard let leer = teil.lastIndex(of: " ") else { return nil }
        let label = teil[teil.startIndex..<leer].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, let wert = zahl(String(teil[teil.index(after: leer)...])), wert >= 0 else { return nil }
        return Punkt(label: String(label.prefix(12)), wert: wert)
    }

    /// "07:30" oder "7:30": 24-Stunden-Zeit.
    static func uhrzeit(_ text: String) -> (stunde: Int, minute: Int)? {
        let teile = text.split(separator: ":", omittingEmptySubsequences: false)
        guard teile.count == 2 else { return nil }
        for teil in teile where !(1...2).contains(teil.count) || !teil.allSatisfy({ $0.isASCII && $0.isNumber }) { return nil }
        guard let stunde = Int(teile[0]), let minute = Int(teile[1]), (0...23).contains(stunde), (0...59).contains(minute)
        else { return nil }
        return (stunde, minute)
    }
}

// MARK: - Zugriff für die Ansicht

extension CoachMarker.Zerlegt {
    var essen: [CoachMarker.Essen] {
        marker.compactMap { art -> CoachMarker.Essen? in
            if case .essen(let e) = art { return e }
            return nil
        }
    }

    var folgefragen: [String] {
        for art in marker { if case .weiter(let fragen) = art { return fragen } }
        return []
    }

    var diagramm: (titel: String, punkte: [CoachMarker.Punkt])? {
        for art in marker { if case .chart(let titel, let punkte) = art { return (titel, punkte) } }
        return nil
    }

    var fortschritt: (label: String, aktuell: Double, ziel: Double)? {
        for art in marker { if case .fortschritt(let label, let aktuell, let ziel) = art { return (label, aktuell, ziel) } }
        return nil
    }

    var wege: [(ziel: CoachMarker.Ziel, beschriftung: String)] {
        marker.compactMap { art -> (ziel: CoachMarker.Ziel, beschriftung: String)? in
            if case .gehe(let ziel, let beschriftung) = art { return (ziel, beschriftung) }
            return nil
        }
    }

    var erinnerung: (stunde: Int, minute: Int, text: String)? {
        for art in marker { if case .erinnerung(let stunde, let minute, let text) = art { return (stunde, minute, text) } }
        return nil
    }

    var vorgeschlagenesZiel: String? {
        for art in marker { if case .ziel(let text) = art { return text } }
        return nil
    }
}
