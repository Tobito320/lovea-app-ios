import Foundation

/// Ein Katalogeintrag, einmal normalisiert und in Wörter zerlegt.
private struct SuchFeld {
    let name: String
    let en: String
    let alias: String
    let muskel: String
    let geraet: String
    let koerper: String
    let nameWoerter: [String]
    let alleWoerter: Set<String>
}

/// Ein getipptes Wort (oder eine Wortgruppe aus der Synonym-Tabelle) mit allem, was es bedeuten darf.
private struct Suchwort {
    let alternativen: [String]
    let muskeln: Set<String>
    let nur: Set<String>

    init(_ b: SuchBegriff) {
        alternativen = b.woerter
        muskeln = b.muskeln
        nur = b.nur
    }

    init(roh: String) {
        alternativen = [roh]
        muskeln = []
        nur = []
    }
}

/// Die Suche: Synonyme (`UebungenSynonyme`), Muskel-Zuordnung, Relevanz-Sortierung, einfache Tippfehler.
extension UebungsKatalog {
    private static let felder: [String: SuchFeld] = Dictionary(alle.map { ($0.id, feld($0)) }, uniquingKeysWith: { erste, _ in erste })

    /// Jedes Wort muss passen (Name, englischer Name, Zusatzbegriffe, Zielmuskel, Gerät, Körperteil, Synonyme).
    /// Beste Treffer zuerst: Wortanfang im Namen, dann Teil des Namens, Zusatzbegriff, Muskel, englischer Name,
    /// Gerät. Gängige Übungen und kurze Namen gewinnen bei Gleichstand. Leerer Text: alles nach Namen.
    /// Gibt es nichts, wird einmal mit Tippfehler-Toleranz gesucht ("bizepz", "kniebeugn").
    static func suchen(_ text: String, in liste: [Uebung] = alle) -> [Uebung] {
        guard !woerter(normal(text)).isEmpty else { return liste.sorted { $0.name < $1.name } }
        var treffer = bewerten(zerlegen(text, tolerant: false), in: liste, tolerant: false)
        if treffer.isEmpty { treffer = bewerten(zerlegen(text, tolerant: true), in: liste, tolerant: true) }
        return treffer.sorted { a, b in
            if a.punkte != b.punkte { return a.punkte > b.punkte }
            if a.uebung.name.count != b.uebung.name.count { return a.uebung.name.count < b.uebung.name.count }
            return a.uebung.name < b.uebung.name
        }.map(\.uebung)
    }

    private static func bewerten(_ suchwoerter: [Suchwort], in liste: [Uebung], tolerant: Bool) -> [(uebung: Uebung, punkte: Int)] {
        liste.compactMap { u in
            let f = felder[u.id] ?? feld(u)
            var summe = 0
            for s in suchwoerter {
                let p = punkte(s, f, tolerant: tolerant)
                if p == 0 { return nil }
                summe += p
            }
            if let erstes = suchwoerter.first, erstes.alternativen.contains(where: { f.name.hasPrefix($0) }) { summe += 30 }
            if beliebtRang[u.id] != nil { summe += 15 }
            return (u, summe)
        }
    }

    private static func punkte(_ s: Suchwort, _ f: SuchFeld, tolerant: Bool) -> Int {
        let muskelTreffer = s.muskeln.contains(f.muskel)
        guard s.nur.isEmpty || s.nur.contains(f.muskel) || s.nur.contains(f.koerper) else { return muskelTreffer ? 80 : 0 }
        let wort = s.alternativen.map { wortPunkte($0, f, tolerant: tolerant) }.max() ?? 0
        // Stimmen Zielmuskel und Wort, steht die Übung vor reinen Wort-Treffern anderer Muskeln.
        return muskelTreffer ? max(80, wort > 0 ? wort + 10 : 0) : wort
    }

    private static func wortPunkte(_ alt: String, _ f: SuchFeld, tolerant: Bool) -> Int {
        if f.nameWoerter.contains(where: { $0.hasPrefix(alt) }) { return 100 }
        if f.alias.contains(alt) { return 90 }
        // Ein, zwei Buchstaben ("po", "kh") nur am Wortanfang, sonst trifft "po" in "Kopf".
        if alt.count <= 2 { return f.alleWoerter.contains { $0.hasPrefix(alt) } ? 40 : 0 }
        if f.name.contains(alt) { return 85 }
        if f.muskel.contains(alt) { return 70 }
        if f.en.contains(alt) { return 60 }
        if f.geraet.contains(alt) { return 55 }
        if f.koerper.contains(alt) { return 40 }
        if tolerant, alt.count >= 4, f.alleWoerter.contains(where: { aehnlich(alt, $0) }) { return 45 }
        return 0
    }

    /// Längste Wortgruppe aus der Synonym-Tabelle zuerst ("upper chest" vor "upper"); sonst das Wort selbst.
    /// Tolerant: ein unbekanntes Wort wird zum ähnlichsten Tabellenwort mit gleichem Anfangsbuchstaben.
    private static func zerlegen(_ text: String, tolerant: Bool) -> [Suchwort] {
        let w = woerter(normal(text))
        var ergebnis: [Suchwort] = []
        var i = 0
        while i < w.count {
            let laenge = (1...min(UebungenSynonyme.laengsterSchluessel, w.count - i)).reversed().first {
                UebungenSynonyme.begriffe[w[i..<i + $0].joined(separator: " ")] != nil
            }
            if let laenge, let b = UebungenSynonyme.begriffe[w[i..<i + laenge].joined(separator: " ")] {
                ergebnis.append(Suchwort(b))
                i += laenge
            } else if tolerant, let b = aehnlichster(w[i]) {
                ergebnis.append(Suchwort(b))
                i += 1
            } else {
                ergebnis.append(Suchwort(roh: w[i]))
                i += 1
            }
        }
        return ergebnis
    }

    private static func aehnlichster(_ wort: String) -> SuchBegriff? {
        guard wort.count >= 4 else { return nil }
        let kandidaten = UebungenSynonyme.begriffe.keys.filter { $0.first == wort.first && !$0.contains(" ") && $0.count >= 4 && aehnlich(wort, $0) }
        return kandidaten.min().flatMap { UebungenSynonyme.begriffe[$0] }
    }

    private static func feld(_ u: Uebung) -> SuchFeld {
        let name = normal(u.name), en = normal(u.en), alias = UebungenSynonyme.alias[u.id] ?? ""
        let muskel = normal(u.muskel), geraet = normal(u.geraet), koerper = normal(u.koerper)
        return SuchFeld(name: name, en: en, alias: alias, muskel: muskel, geraet: geraet, koerper: koerper,
                        nameWoerter: woerter(name),
                        alleWoerter: Set(woerter("\(name) \(en) \(alias) \(muskel) \(geraet) \(koerper)")))
    }

    private static func woerter(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Höchstens ein Fehler (ab 8 Buchstaben zwei) zum Wort oder zum gleich langen Wortanfang.
    private static func aehnlich(_ wort: String, _ token: String) -> Bool {
        let grenze = wort.count <= 3 ? 0 : wort.count <= 7 ? 1 : 2
        let a = Array(wort), b = Array(token)
        if abs(a.count - b.count) <= grenze, abstand(a, b) <= grenze { return true }
        return b.count > a.count && abstand(a, Array(b.prefix(a.count))) <= grenze
    }

    /// Editierabstand mit vertauschten Nachbarbuchstaben als ein Fehler ("kniebeguen" statt "kniebeugen").
    private static func abstand(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] { d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1) }
            }
        }
        return d[a.count][b.count]
    }
}
