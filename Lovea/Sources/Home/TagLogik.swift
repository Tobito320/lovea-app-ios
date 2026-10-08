import Foundation

/// Ein schon gesyncter Rohwert aus dem Tag einer Person ("Ahmeds Tag"). Reine Werte, kein Op-Typ:
/// `TagModell` baut sie aus den Ops, `TagLogik` macht daraus die Zeitleiste.
struct TagRoh: Equatable, Sendable {
    enum Art: Equatable, Sendable {
        /// `zeit` des Rohwerts ist `bis` (Aufwachen). `minuten` ist die echte Schlafzeit.
        case schlaf(von: Date, bis: Date, minuten: Int)
        /// Schritte-Stand des Tages zum Zeitpunkt `zeit` (kumulativ, nicht die Änderung).
        case schritte(anzahl: Int)
        case gymStart(session: String)
        /// Eine abgeschlossene (oder mit abgehaktem Satz begonnene) Übung.
        case gymUebung(session: String, name: String)
        case gymEnde(session: String, minuten: Int?, saetze: Int?)
        /// Foto im Chat (nie ein Snap). `medienId` für die Vorschau.
        case foto(medienId: String?)
        /// Snap: zählt als Moment, trägt aber absichtlich keine Medien-ID (Einmal-Ansicht).
        case snap
        /// "Denk an dich" (geste herz), von dieser Person gesendet.
        case herz
    }

    let id: String
    let zeit: Date
    let art: Art
}

/// Ein Eintrag der Zeitleiste: Uhrzeit, Symbol, kurzer Text.
struct TagMoment: Equatable, Identifiable, Sendable {
    enum Sorte: String, Sendable { case schlaf, schritte, gym, foto, snap, herz }

    let id: String
    let zeit: Date
    let sorte: Sorte
    let symbol: String
    let text: String
    /// Nur bei Fotos: Medien-ID der Vorschau. Bei Snaps immer `nil`.
    var medienId: String?
}

struct TagAnsicht: Equatable, Sendable {
    var momente: [TagMoment]
    /// Alle "Denk an dich"-Tipps dieser Person an diesem Tag (jeder Tipp zählt, auch wenn die Momente
    /// zusammengefasst sind).
    var herzen: Int
}

/// Rohwerte -> sortierte, zusammengefasste Zeitleiste für einen Berliner Kalendertag.
/// Zusammenfassen: überlappende Schlaf-Einträge ein Aufwachen, viele Schritte-Stände ein Meilenstein
/// pro erreichter Marke, Fotos/Snaps/Herzen kurz hintereinander eine Zeile, Gym ein Start, eine
/// Übungszeile und ein Ende je Training.
enum TagLogik {
    static let schrittMarken = [2_000, 5_000, 8_000, 10_000, 12_000, 15_000, 20_000, 25_000, 30_000]
    static let fotoFenster: TimeInterval = 10 * 60
    static let herzFenster: TimeInterval = 30 * 60

    /// `person` ist die, deren Tag gezeigt wird, `ansicht` wer gerade schaut (nur für den Herz-Text).
    static func zeitleiste(_ roh: [TagRoh], tag: Date, ansicht: Person, person: Person, kalender: Calendar = .berlin) -> TagAnsicht {
        let start = kalender.startOfDay(for: tag)
        guard let ende = kalender.date(byAdding: .day, value: 1, to: start) else { return TagAnsicht(momente: [], herzen: 0) }

        var gesehen = Set<String>()
        let heute = roh.filter { $0.zeit >= start && $0.zeit < ende && gesehen.insert($0.id).inserted }
            .sorted { ($0.zeit, $0.id) < ($1.zeit, $1.id) }

        var momente: [TagMoment] = []
        momente += schlafMomente(heute)
        momente += schrittMomente(heute)
        momente += gymMomente(heute)
        momente += gruppiert(heute, fenster: fotoFenster, sorte: .foto, symbol: "camera.fill") { $0.art.istFoto } text: { n in
            n == 1 ? "Foto geschickt" : "\(n) Fotos geschickt"
        }
        momente += gruppiert(heute, fenster: fotoFenster, sorte: .snap, symbol: "flame.fill") { $0.art == .snap } text: { n in
            n == 1 ? "Snap geschickt" : "\(n) Snaps geschickt"
        }
        let herzen = heute.filter { $0.art == .herz }.count
        let wem = ansicht == person ? "An \(person.partner.name) gedacht" : "An dich gedacht"
        momente += gruppiert(heute, fenster: herzFenster, sorte: .herz, symbol: "heart.fill") { $0.art == .herz } text: { n in
            n == 1 ? wem : "\(wem) · \(n)×"
        }

        momente.sort { ($0.zeit, $0.id) < ($1.zeit, $1.id) }
        return TagAnsicht(momente: momente, herzen: herzen)
    }

    /// "Ahmeds Tag · 7 Momente" / "Annikas Tag · 1 Moment" / "Ahmeds Tag" ohne Momente.
    static func titel(person: Person, momente: Int) -> String {
        let name = person.name.hasSuffix("s") ? person.name + "’" : person.name + "s"
        guard momente > 0 else { return "\(name) Tag" }
        return "\(name) Tag · \(momente) \(momente == 1 ? "Moment" : "Momente")"
    }

    // MARK: - Schlaf

    private static func schlafMomente(_ roh: [TagRoh]) -> [TagMoment] {
        var schlaefe: [(von: Date, bis: Date, minuten: Int)] = []
        for r in roh {
            if case let .schlaf(von, bis, minuten) = r.art { schlaefe.append((von, bis, minuten)) }
        }
        schlaefe.sort { $0.von < $1.von }
        var gruppen: [(von: Date, bis: Date, minuten: Int)] = []
        for s in schlaefe {
            if let letzte = gruppen.last, s.von <= letzte.bis {
                // Dieselbe Nacht, später neu berechnet: der Eintrag mit dem späteren Ende gilt.
                if s.bis >= letzte.bis { gruppen[gruppen.count - 1] = (letzte.von, s.bis, s.minuten) }
            } else {
                gruppen.append(s)
            }
        }
        return gruppen.enumerated().map { index, g in
            let text = index == 0
                ? (g.minuten > 0 ? "Aufgewacht · \(dauer(g.minuten)) geschlafen" : "Aufgewacht")
                : "Wieder aufgewacht"
            return TagMoment(id: "schlaf-\(Int(g.bis.timeIntervalSince1970))", zeit: g.bis, sorte: .schlaf,
                             symbol: index == 0 ? "sunrise.fill" : "bed.double.fill", text: text, medienId: nil)
        }
    }

    static func dauer(_ minuten: Int) -> String {
        let h = minuten / 60, m = minuten % 60
        if h == 0 { return "\(m) Min." }
        if m == 0 { return "\(h) Std." }
        return "\(h) Std. \(m) Min."
    }

    // MARK: - Schritte

    private static func schrittMomente(_ roh: [TagRoh]) -> [TagMoment] {
        var erreicht = Set<Int>()
        var momente: [TagMoment] = []
        for r in roh {
            guard case let .schritte(anzahl) = r.art else { continue }
            let neu = schrittMarken.filter { anzahl >= $0 && !erreicht.contains($0) }
            erreicht.formUnion(neu)
            // Springt der Stand über mehrere Marken, zählt nur die höchste.
            if let marke = neu.max() {
                momente.append(TagMoment(id: "schritte-\(marke)", zeit: r.zeit, sorte: .schritte, symbol: "figure.walk",
                                         text: "\(tausender(marke)) Schritte geschafft", medienId: nil))
            }
        }
        return momente
    }

    static func tausender(_ zahl: Int) -> String {
        let ziffern = String(zahl)
        var ergebnis = ""
        for (i, z) in ziffern.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { ergebnis.append(".") }
            ergebnis.append(z)
        }
        return String(ergebnis.reversed())
    }

    // MARK: - Gym

    private static func gymMomente(_ roh: [TagRoh]) -> [TagMoment] {
        var starts: [String: Date] = [:]
        var uebungen: [String: [String: Date]] = [:]
        var enden: [String: (zeit: Date, minuten: Int?, saetze: Int?)] = [:]
        for r in roh {
            switch r.art {
            case let .gymStart(session):
                starts[session] = min(starts[session] ?? r.zeit, r.zeit)
            case let .gymUebung(session, name):
                var dieseSession = uebungen[session] ?? [:]
                dieseSession[name] = min(dieseSession[name] ?? r.zeit, r.zeit)
                uebungen[session] = dieseSession
            case let .gymEnde(session, minuten, saetze):
                if r.zeit >= (enden[session]?.zeit ?? .distantPast) { enden[session] = (r.zeit, minuten, saetze) }
            default:
                break
            }
        }
        var momente: [TagMoment] = []
        for (session, zeit) in starts {
            momente.append(TagMoment(id: "gym-start-\(session)", zeit: zeit, sorte: .gym, symbol: "dumbbell.fill",
                                     text: "Los geht’s im Gym", medienId: nil))
        }
        for (session, namen) in uebungen where !namen.isEmpty {
            let nachZeit = namen.sorted { ($0.value, $0.key) < ($1.value, $1.key) }
            let gezeigt = nachZeit.prefix(3).map { $0.key }.joined(separator: ", ")
            let rest = nachZeit.count - 3
            let text = rest > 0 ? "Geschafft: \(gezeigt) und \(rest) weitere" : "Geschafft: \(gezeigt)"
            momente.append(TagMoment(id: "gym-ue-\(session)", zeit: nachZeit[nachZeit.count - 1].value, sorte: .gym,
                                     symbol: "checkmark.circle.fill", text: text, medienId: nil))
        }
        for (session, e) in enden {
            var teile = ["Training beendet"]
            if let m = e.minuten, m > 0 { teile.append("\(m) Min.") }
            if let s = e.saetze, s > 0 { teile.append("\(s) \(s == 1 ? "Satz" : "Sätze")") }
            momente.append(TagMoment(id: "gym-ende-\(session)", zeit: e.zeit, sorte: .gym, symbol: "flag.checkered",
                                     text: teile.joined(separator: " · "), medienId: nil))
        }
        return momente
    }

    // MARK: - Foto, Snap, Herz

    /// Fasst gleichartige Rohwerte zusammen, solange jeder höchstens `fenster` nach dem vorigen kommt.
    private static func gruppiert(
        _ roh: [TagRoh], fenster: TimeInterval, sorte: TagMoment.Sorte, symbol: String,
        _ passt: (TagRoh) -> Bool, text: (Int) -> String
    ) -> [TagMoment] {
        var gruppen: [[TagRoh]] = []
        for r in roh where passt(r) {
            if let letzte = gruppen.last?.last, r.zeit.timeIntervalSince(letzte.zeit) <= fenster {
                gruppen[gruppen.count - 1].append(r)
            } else {
                gruppen.append([r])
            }
        }
        return gruppen.map { g in
            var vorschau: String?
            if sorte == .foto {
                vorschau = g.lazy.compactMap { r -> String? in
                    if case let .foto(id) = r.art { return id }
                    return nil
                }.first
            }
            return TagMoment(id: "\(sorte.rawValue)-\(g[0].id)", zeit: g[0].zeit, sorte: sorte, symbol: symbol,
                             text: text(g.count), medienId: vorschau)
        }
    }
}

private extension TagRoh.Art {
    var istFoto: Bool {
        if case .foto = self { return true }
        return false
    }
}
