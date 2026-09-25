import Foundation

/// One line of "Das fällt mir auf". `fortschritt` is only set on `.gesperrt`: days collected / days needed.
struct Hinweis: Identifiable, Equatable, Sendable {
    enum Art: Sendable { case stillstand, schlaf, wasser, vergessen, gesperrt }
    var id: String
    var art: Art
    var titel: String
    var zahl: String
    var text: String
    var tipp: String
    var basis: String
    var fortschritt: Double?
}

/// Everything the rules read. Days are `yyyy-MM-dd`. `schlafMinuten` is keyed by the day the sleep ended
/// (the morning before the session), `wasser` counts glasses per day.
struct HinweisEingabe: Sendable {
    var sessions: [GymSession]
    var schlafMinuten: [String: Int]
    var wasser: [String: Int]
    var gymTage: Set<String>
    var stimmungTage: Int
    var koffeinTage: Int
    var prio: [MuskelGruppe]
    var heute: String
}

enum HinweisLogik {
    private static let sperreTage = 14

    /// Order: Stillstand, Vergessen, Schlaf, Wasser, then the locked ones. Empty input gives only the locked ones.
    static func alle(_ e: HinweisEingabe, katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [Hinweis] {
        let sessions = e.sessions.sorted { $0.start < $1.start }
        let e1rm = sessions.map { (session: $0, werte: bestwerte($0)) }
        let nachSchlaf = schlaf(e1rm, e)
        return stillstaende(e1rm, katalog) + vergessen(sessions, e, katalog) + nachSchlaf.filter { $0.art != .gesperrt }
            + wasser(e) + nachSchlaf.filter { $0.art == .gesperrt } + gesperrt(e)
    }

    // MARK: - Epley

    /// Best estimated one-rep max per exercise in one session. Own exercises and sets without kg are left out.
    private static func bestwerte(_ s: GymSession) -> [String: Double] {
        var werte: [String: Double] = [:]
        for lauf in s.laeufe where lauf.fertig && lauf.uebung != PlanUebung.eigen {
            for satz in lauf.saetze ?? [] {
                guard let kg = satz.kg, kg > 0 else { continue }
                werte[lauf.uebung] = max(werte[lauf.uebung] ?? 0, kg * (1 + Double(satz.wdh) / 30))
            }
        }
        return werte
    }

    private static func kommaZahl(_ x: Double) -> String {
        String(format: "%.1f", x).replacingOccurrences(of: ".", with: ",")
    }

    // MARK: - Regeln

    private static func stillstaende(_ e1rm: [(session: GymSession, werte: [String: Double])],
                                     _ katalog: (String) -> Uebung?) -> [Hinweis] {
        let ids = Set(e1rm.flatMap { $0.werte.keys })
        return ids.sorted().compactMap { id -> Hinweis? in
            let verlauf = e1rm.compactMap { $0.werte[id] }
            guard verlauf.count >= 4, let jung = verlauf.suffix(3).max(), let alt = verlauf.dropLast(3).max(),
                  jung <= alt else { return nil }
            let name = katalog(id)?.name ?? id
            return Hinweis(
                id: "stillstand.\(id)", art: .stillstand, titel: "\(name) steht still",
                zahl: "\(kommaZahl(alt)) kg",
                text: "Seit 3 Einheiten kein Plus bei geschätzten \(kommaZahl(alt)) kg.",
                tipp: "3 Wochen lang 3 × 6 mit +2,5 kg, oder eine leichte Woche.",
                basis: "Geschätztes Maximum nach Epley (kg × (1 + Wdh ÷ 30)), bestes Set je Einheit, \(verlauf.count) Einheiten.",
                fortschritt: nil)
        }
    }

    // ponytail: a group that was never trained gives no hint, only one that was and then dropped out.
    private static func vergessen(_ sessions: [GymSession], _ e: HinweisEingabe,
                                  _ katalog: (String) -> Uebung?) -> [Hinweis] {
        let tage = sessions.map { s in
            (tag: Datum.text(s.start),
             gruppen: Set(MuskelLogik.wochenSaetze([s], woche: Datum.text(s.start), katalog: katalog).keys.map(\.gruppe)))
        }
        return e.prio.compactMap { g -> Hinweis? in
            guard let letzter = tage.last(where: { $0.gruppen.contains(g) })?.tag else { return nil }
            let her = Datum.tageZwischen(letzter, e.heute)
            guard her >= 8 else { return nil }
            return Hinweis(
                id: "vergessen.\(g.rawValue)", art: .vergessen, titel: "\(g.name) vergessen?",
                zahl: "\(her) Tage", text: "\(g.name) hatte seit \(her) Tagen keinen Satz.",
                tipp: "Nimm eine \(g.name)-Übung in die nächste Einheit.",
                basis: "Prio-Gruppe ohne Satz seit mindestens 8 Tagen.", fortschritt: nil)
        }
    }

    private static let schlafBasis = "Einheiten nach Nächten unter 6 h gegen Einheiten nach mindestens 7 h, je mindestens 4."

    /// Performance of a session: mean of e1RM / best e1RM of that exercise.
    private static func schlaf(_ e1rm: [(session: GymSession, werte: [String: Double])], _ e: HinweisEingabe) -> [Hinweis] {
        var bestwert: [String: Double] = [:]
        for eintrag in e1rm { bestwert.merge(eintrag.werte, uniquingKeysWith: max) }
        var kurz: [Double] = [], gut: [Double] = []
        for eintrag in e1rm where !eintrag.werte.isEmpty {
            guard let minuten = e.schlafMinuten[Datum.text(eintrag.session.start)] else { continue }
            let leistung = eintrag.werte.map { $0.value / bestwert[$0.key]! }.reduce(0, +) / Double(eintrag.werte.count)
            if minuten < 360 { kurz.append(leistung) } else if minuten >= 420 { gut.append(leistung) }
        }
        guard kurz.count >= 4, gut.count >= 4 else {
            guard !e1rm.isEmpty else { return [] }
            let da = min(kurz.count, 4) + min(gut.count, 4)
            return [Hinweis(
                id: "gesperrt.schlaf", art: .gesperrt, titel: "Schlaf gegen Leistung",
                zahl: "\(da)/8", text: "Noch \(8 - da) Einheiten mit Schlafdaten, dann sehe ich, ob Schlaf deine Kraft bremst.",
                tipp: "Trag deinen Schlaf ein oder verbinde Apple Health.", basis: schlafBasis,
                fortschritt: Double(da) / 8)]
        }
        let unterschied = Int(((mittel(gut) - mittel(kurz)) * 100).rounded())
        guard unterschied >= 3 else { return [] }
        return [Hinweis(
            id: "schlaf", art: .schlaf, titel: "Schlaf bremst dich",
            zahl: "\(unterschied) %", text: "Nach kurzen Nächten trainierst du im Schnitt \(unterschied) % schwächer.",
            tipp: "Vor einer kurzen Nacht die Last etwas senken oder einen Satz weglassen.",
            basis: schlafBasis, fortschritt: nil)]
    }

    private static func mittel(_ x: [Double]) -> Double { x.reduce(0, +) / Double(x.count) }

    private static func wasser(_ e: HinweisEingabe) -> [Hinweis] {
        let gym = e.wasser.filter { e.gymTage.contains($0.key) }.map { Double($0.value) }
        let ruhe = e.wasser.filter { !e.gymTage.contains($0.key) }.map { Double($0.value) }
        guard gym.count >= 5, ruhe.count >= 5 else { return [] }
        let diff = mittel(gym) - mittel(ruhe)
        guard abs(diff) >= 1 else { return [] }
        let weniger = diff < 0
        let glaeser = kommaZahl(abs(diff))
        return [Hinweis(
            id: "wasser", art: .wasser, titel: weniger ? "Wenig Wasser beim Training" : "Mehr Wasser an Gym-Tagen",
            zahl: "\(weniger ? "−" : "+")\(glaeser) Gläser",
            text: weniger ? "An Gym-Tagen trinkst du \(glaeser) Gläser weniger als an Ruhetagen."
                : "An Gym-Tagen trinkst du \(glaeser) Gläser mehr als an Ruhetagen.",
            tipp: weniger ? "Eine Flasche mit ins Gym nehmen und zwischen den Sätzen trinken." : "Weiter so, das hält dich leistungsfähig.",
            basis: "Mittelwert der Gläser an Gym-Tagen gegen Ruhetage, je mindestens 5 Tage.", fortschritt: nil)]
    }

    /// "Stimmung gegen Schlaf" and "Koffein gegen Schlaf" until 14 days are collected.
    private static func gesperrt(_ e: HinweisEingabe) -> [Hinweis] {
        let kandidaten = [("stimmung", "Stimmung", e.stimmungTage, "Trag deine Stimmung im Kalender ein."),
                          ("koffein", "Koffein", e.koffeinTage, "Zähl deinen Kaffee unter Heute mit.")]
        return kandidaten.compactMap { (schluessel, name, tage, tipp) -> Hinweis? in
            guard tage < sperreTage else { return nil }
            return Hinweis(
                id: "gesperrt.\(schluessel)", art: .gesperrt, titel: "\(name) gegen Schlaf",
                zahl: "\(tage)/\(sperreTage)", text: "Noch \(sperreTage - tage) Tage, dann vergleiche ich \(name) mit deinem Schlaf.",
                tipp: tipp, basis: "Braucht \(sperreTage) Tage mit beiden Werten.",
                fortschritt: Double(max(0, tage)) / Double(sperreTage))
        }
    }
}
