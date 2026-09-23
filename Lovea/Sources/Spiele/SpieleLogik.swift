import Foundation

// Pure game logic (Z-14.2 to Z-14.5). No UI, no Raum: both devices run exactly these functions
// on the same inputs (a seed derived from the game id plus each player's moves), so they agree
// without a referee.

enum SpielArt: String, Codable, CaseIterable, Identifiable, Sendable {
    case duell, xo, ssp, kennen, reaktion, memory

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .duell: "Kritzel-Duell"
        case .xo: "XO"
        case .ssp: "Schere-Stein-Papier"
        case .kennen: "Wie gut kennst du mich?"
        case .reaktion: "Reaktions-Duell"
        case .memory: "Memory"
        }
    }

    var symbol: String {
        switch self {
        case .duell: "paintbrush.pointed.fill"
        case .xo: "square.grid.3x3.fill"
        case .ssp: "scissors"
        case .kennen: "heart.text.square.fill"
        case .reaktion: "bolt.fill"
        case .memory: "square.grid.2x2.fill"
        }
    }
}

/// Wins or points per person. Also the wire shape of `spiel.ergebnis.punkte`.
struct SpielPunkte: Codable, Sendable, Equatable {
    var ahmed = 0
    var annika = 0

    subscript(_ p: Person) -> Int {
        get { p == .ahmed ? ahmed : annika }
        set { if p == .ahmed { ahmed = newValue } else { annika = newValue } }
    }

    static func + (a: SpielPunkte, b: SpielPunkte) -> SpielPunkte { SpielPunkte(ahmed: a.ahmed + b.ahmed, annika: a.annika + b.annika) }

    /// Leader first, like "Annika 2 : Ahmed 1".
    var text: String {
        let erster: Person = annika > ahmed ? .annika : .ahmed
        return "\(erster.name) \(self[erster]) : \(erster.partner.name) \(self[erster.partner])"
    }

    var fuehrend: Person? { ahmed == annika ? nil : (ahmed > annika ? .ahmed : .annika) }
}

/// How one round (partie) ended. `punkte` is added to the game's running tally.
struct PartieEnde: Equatable, Sendable {
    var punkte: SpielPunkte
    var sieger: Person?
    var text: String
    var titel: String?
}

/// SplitMix64. Deterministic on every device, unlike `SystemRandomNumberGenerator` or `hashValue`.
struct Zufall: RandomNumberGenerator, Sendable {
    private var zustand: UInt64

    init(_ seed: UInt64) { zustand = seed }

    init(_ text: String) { self.init(Zufall.seed(text)) }

    mutating func next() -> UInt64 {
        zustand &+= 0x9E37_79B9_7F4A_7C15
        var z = zustand
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ..< n
    mutating func zahl(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }

    /// Own Fisher-Yates so the order never depends on stdlib internals.
    mutating func gemischt<T>(_ werte: [T]) -> [T] {
        var a = werte
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, zahl(i + 1))
        }
        return a
    }

    /// FNV-1a over UTF-8, stable across launches and devices.
    static func seed(_ text: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in text.utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01B3
        }
        return h
    }
}

// MARK: - XO

enum XO {
    static let linien = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]

    static func sieger(feld: [Person?]) -> Person? {
        gewinnLinie(feld: feld).flatMap { feld[$0[0]] }
    }

    static func gewinnLinie(feld: [Person?]) -> [Int]? {
        guard feld.count == 9 else { return nil }
        return linien.first { l in feld[l[0]] != nil && feld[l[0]] == feld[l[1]] && feld[l[1]] == feld[l[2]] }
    }

    struct Stand: Equatable { var feld: [Person?]; var amZug: Person?; var sieger: Person? }

    /// Replays both move lists alternately, starter first. `amZug` is nil once the game is over.
    /// An invalid move (taken cell) stops the replay there instead of crashing.
    static func stand(starter: Person, zuege: [Person: [Int]]) -> Stand {
        var feld = [Person?](repeating: nil, count: 9)
        var index: [Person: Int] = [:]
        var dran = starter
        while sieger(feld: feld) == nil, feld.contains(where: { $0 == nil }) {
            let liste = zuege[dran] ?? []
            let i = index[dran, default: 0]
            guard i < liste.count, (0..<9).contains(liste[i]), feld[liste[i]] == nil else {
                return Stand(feld: feld, amZug: dran, sieger: nil)
            }
            feld[liste[i]] = dran
            index[dran] = i + 1
            dran = dran.partner
        }
        return Stand(feld: feld, amZug: nil, sieger: sieger(feld: feld))
    }
}

// MARK: - Schere-Stein-Papier

enum SSP: Int, CaseIterable, Sendable {
    case schere, stein, papier

    var emoji: String {
        switch self {
        case .schere: "✌️"
        case .stein: "✊"
        case .papier: "✋"
        }
    }

    var titel: String {
        switch self {
        case .schere: "Schere"
        case .stein: "Stein"
        case .papier: "Papier"
        }
    }

    /// The winning hand, nil on a tie.
    static func sieger(a: SSP, b: SSP) -> SSP? {
        if a == b { return nil }
        return (a.rawValue + 2) % 3 == b.rawValue ? a : b
    }

    struct Stand: Equatable { var siege: SpielPunkte; var runden: Int; var sieger: Person? }

    /// Best of 3: first to 2 round wins. Ties replay the round.
    static func stand(_ zuege: [Person: [Int]]) -> Stand {
        let a = zuege[.ahmed] ?? [], b = zuege[.annika] ?? []
        var siege = SpielPunkte()
        var runden = 0
        for (x, y) in zip(a, b) {
            runden += 1
            guard let hx = SSP(rawValue: x), let hy = SSP(rawValue: y), let w = sieger(a: hx, b: hy) else { continue }
            siege[w == hx ? .ahmed : .annika] += 1
            if siege.ahmed == 2 || siege.annika == 2 { return Stand(siege: siege, runden: runden, sieger: siege.fuehrend) }
        }
        return Stand(siege: siege, runden: runden, sieger: nil)
    }
}

// MARK: - Kritzel-Duell

enum Duell {
    /// Same pick → that word. Different picks → the seed decides between the two. Symmetric in
    /// A and B, so both devices agree whichever player they pass first.
    static func wort(wahlA: Int, wahlB: Int, vorschlaege: [String], seed: UInt64) -> String {
        guard !vorschlaege.isEmpty else { return "" }
        let a = min(max(wahlA, 0), vorschlaege.count - 1)
        let b = min(max(wahlB, 0), vorschlaege.count - 1)
        let paar = [min(a, b), max(a, b)]
        return vorschlaege[paar[Int(seed % 2)]]
    }

    /// Three distinct words from the pool.
    static func vorschlaege(pool: [String], seed: UInt64, anzahl: Int = 3) -> [String] {
        var gesehen = Set<String>()
        let eindeutig = pool.filter { gesehen.insert($0).inserted }
        var z = Zufall(seed)
        return Array(z.gemischt(eindeutig).prefix(anzahl))
    }

    static func seed(spiel: String, runde: Int) -> UInt64 { Zufall.seed("\(spiel)#duell#\(runde)") }
}

/// `duell-woerter.json`: vibe key → words.
enum Wortliste {
    static let vibes = ["leicht", "mittel", "schwer", "suess", "lustig", "tiere", "essen", "orte"]
    static let gemischt = "gemischt"
    static let eigene = "eigene"

    static func titel(_ vibe: String) -> String {
        switch vibe {
        case "leicht": "Leicht"
        case "mittel": "Mittel"
        case "schwer": "Schwer"
        case "suess": "Süß"
        case "lustig": "Lustig"
        case "tiere": "Tiere"
        case "essen": "Essen"
        case "orte": "Orte"
        case eigene: "Eure Insider"
        default: "Zufällig"
        }
    }

    static let woerter: [String: [String]] = laden()

    static func dekodieren(_ daten: Data) -> [String: [String]]? {
        try? JSONDecoder().decode([String: [String]].self, from: daten)
    }

    static func laden() -> [String: [String]] {
        let url = Bundle.main.url(forResource: "duell-woerter", withExtension: "json")
            ?? Bundle.main.url(forResource: "duell-woerter", withExtension: "json", subdirectory: "Spiele")
        return url.flatMap { try? Data(contentsOf: $0) }.flatMap(dekodieren) ?? [:]
    }

    /// Pool for one round. Unknown vibe or empty own list falls back to everything.
    static func pool(vibe: String, woerter: [String: [String]], eigene: [String]) -> [String] {
        let alle = vibes.flatMap { woerter[$0] ?? [] }
        switch vibe {
        case Self.eigene: return eigene.isEmpty ? alle : eigene
        case gemischt: return alle + eigene
        default: return woerter[vibe].flatMap { $0.isEmpty ? nil : $0 } ?? alle
        }
    }
}

// MARK: - Reaktions-Duell

enum ReaktionsDuell {
    static let ziel = 3
    static let zuFrueh = -1

    /// 2 to 6 seconds, the same on both devices for a given round.
    static func verzoegerung(spiel: String, partie: Int, runde: Int) -> Double {
        var z = Zufall("\(spiel)#\(partie)#reaktion#\(runde)")
        return 2 + Double(z.zahl(4001)) / 1000
    }

    /// Too early loses; both too early or equal: nobody.
    static func rundenSieger(ahmed: Int, annika: Int) -> Person? {
        switch (ahmed < 0, annika < 0) {
        case (true, true): return nil
        case (true, false): return .annika
        case (false, true): return .ahmed
        default: return ahmed == annika ? nil : (ahmed < annika ? .ahmed : .annika)
        }
    }

    struct Stand: Equatable { var siege: SpielPunkte; var runden: Int; var sieger: Person? }

    /// First to 3 round wins.
    static func stand(_ zuege: [Person: [Int]]) -> Stand {
        var siege = SpielPunkte()
        var runden = 0
        for (a, b) in zip(zuege[.ahmed] ?? [], zuege[.annika] ?? []) {
            runden += 1
            if let w = rundenSieger(ahmed: a, annika: b) { siege[w] += 1 }
            if siege.ahmed == ziel || siege.annika == ziel { return Stand(siege: siege, runden: runden, sieger: siege.fuehrend) }
        }
        return Stand(siege: siege, runden: runden, sieger: nil)
    }
}

// MARK: - Memory

enum Memory {
    /// Each motif twice, shuffled by the seed.
    static func karten(motive: [String], seed: UInt64) -> [String] {
        var z = Zufall(seed)
        return z.gemischt(motive + motive)
    }

    struct Stand: Equatable {
        var gefunden: [Int: Person] = [:]
        var offen: [Int] = []       // first card of the running turn
        var zuletzt: [Int] = []     // last miss, stays visible until the next flip
        var amZug: Person
        var paare = SpielPunkte()
        var fertig = false
    }

    /// Replays flips two at a time. A match keeps the turn, a miss passes it.
    static func stand(karten: [String], starter: Person, zuege: [Person: [Int]]) -> Stand {
        var s = Stand(amZug: starter)
        var index: [Person: Int] = [:]
        func gueltig(_ k: Int) -> Bool { karten.indices.contains(k) && s.gefunden[k] == nil }
        while true {
            if !karten.isEmpty, s.gefunden.count == karten.count { s.fertig = true; return s }
            let liste = zuege[s.amZug] ?? []
            let i = index[s.amZug, default: 0]
            guard i < liste.count, gueltig(liste[i]) else { return s }
            s.zuletzt = []
            s.offen = [liste[i]]
            guard i + 1 < liste.count, liste[i + 1] != liste[i], gueltig(liste[i + 1]) else { return s }
            let (a, b) = (liste[i], liste[i + 1])
            index[s.amZug] = i + 2
            s.offen = []
            if karten[a] == karten[b] {
                s.gefunden[a] = s.amZug
                s.gefunden[b] = s.amZug
                s.paare[s.amZug] += 1
            } else {
                s.zuletzt = [a, b]
                s.amZug = s.amZug.partner
            }
        }
    }
}

// MARK: - Wie gut kennst du mich?

struct KennenFrage: Codable, Sendable, Equatable {
    var text: String        // "{name}" is replaced with the person asked about
    var optionen: [String]

    func text(fuer p: Person) -> String { text.replacingOccurrences(of: "{name}", with: p.name) }
}

enum Kennen {
    static let anzahl = 5

    /// Up to 2 questions from own data first, the rest from the fixed set, in seeded order.
    static func fragen(eigene: [KennenFrage], seed: UInt64) -> [KennenFrage] {
        var z = Zufall(seed)
        let aus = Array(z.gemischt(eigene).prefix(2))
        let rest = Array(z.gemischt(fest).prefix(anzahl - aus.count))
        let alle = aus + rest
        return z.gemischt(alle)
    }

    static func treffer(antworten: [Int], tipps: [Int]) -> Int {
        zip(antworten, tipps).filter { $0 == $1 }.count
    }

    static let fest: [KennenFrage] = [
        KennenFrage(text: "Was würde {name} als Erstes retten, wenn es brennt?", optionen: ["Das Handy", "Das Kuscheltier", "Alte Fotos", "Dich"]),
        KennenFrage(text: "Was isst {name} am allerliebsten?", optionen: ["Pizza", "Pasta", "Burger", "Sushi"]),
        KennenFrage(text: "Was trinkt {name} am liebsten?", optionen: ["Wasser", "Tee", "Saft", "Eistee"]),
        KennenFrage(text: "Wo würde {name} am liebsten Urlaub machen?", optionen: ["Am Strand", "In den Bergen", "In einer großen Stadt", "Zu Hause auf dem Sofa"]),
        KennenFrage(text: "Was macht {name} an einem freien Sonntag?", optionen: ["Ausschlafen", "Rausgehen", "Serien schauen", "Mit dir schreiben"]),
        KennenFrage(text: "Welche Superkraft hätte {name} gern?", optionen: ["Fliegen", "Unsichtbar sein", "Zeitreisen", "Gedanken lesen"]),
        KennenFrage(text: "Was bringt {name} sofort zum Lachen?", optionen: ["Tiervideos", "Deine Witze", "Peinliche Momente", "Memes"]),
        KennenFrage(text: "Wann ist {name} am wachsten?", optionen: ["Früh morgens", "Mittags", "Abends", "Mitten in der Nacht"]),
        KennenFrage(text: "Welches Tier wäre {name}?", optionen: ["Katze", "Hund", "Faultier", "Pinguin"]),
        KennenFrage(text: "Was nervt {name} am meisten?", optionen: ["Warten", "Lautes Schmatzen", "Leerer Akku", "Früh aufstehen"]),
        KennenFrage(text: "Welche Jahreszeit mag {name} am liebsten?", optionen: ["Frühling", "Sommer", "Herbst", "Winter"]),
        KennenFrage(text: "Was würde {name} mit einer Million machen?", optionen: ["Reisen", "Ein Haus kaufen", "Sparen", "Allen etwas schenken"]),
        KennenFrage(text: "Womit tröstet man {name} am besten?", optionen: ["Einer Umarmung", "Essen", "Zuhören", "Ablenkung"]),
        KennenFrage(text: "Wie schläft {name} am liebsten?", optionen: ["Auf dem Bauch", "Auf dem Rücken", "Auf der Seite", "Eingerollt wie ein Burrito"]),
        KennenFrage(text: "Was wäre {name}s perfektes Date?", optionen: ["Kino", "Picknick", "Zusammen kochen", "Ein langer Spaziergang"]),
        KennenFrage(text: "Was würde {name} nie freiwillig essen?", optionen: ["Oliven", "Pilze", "Fisch", "Rosenkohl"]),
        KennenFrage(text: "Was schaut {name} am liebsten?", optionen: ["Serien", "Filme", "YouTube", "Reels"]),
        KennenFrage(text: "Was macht {name}, wenn eine Spinne auftaucht?", optionen: ["Schreien", "Wegrennen", "Cool bleiben", "Sie nach draußen retten"]),
        KennenFrage(text: "Was ist {name}s Lieblingsfarbe?", optionen: ["Rosa", "Blau", "Schwarz", "Grün"]),
        KennenFrage(text: "Worauf könnte {name} am wenigsten verzichten?", optionen: ["Das Handy", "Musik", "Schokolade", "Dich"]),
        KennenFrage(text: "Was macht {name} bei Langeweile?", optionen: ["Schlafen", "Snacken", "Am Handy hängen", "Dir schreiben"]),
        KennenFrage(text: "Welches Emoji schickt {name} am häufigsten?", optionen: ["😂", "🥺", "❤️", "🙈"]),
    ]
}
