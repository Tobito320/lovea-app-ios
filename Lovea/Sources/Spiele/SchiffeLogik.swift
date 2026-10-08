import Foundation

// "Schiffe versenken": reine Logik. 8x8, Flotte 4/3/3/2/2. Beide Geräte spielen dieselben
// gespeicherten Ops (`spiel.flotte`, `spiel.schuss`) in derselben Reihenfolge ab und kommen
// so ohne Schiedsrichter zum selben Stand. Das Spiel darf über Tage laufen.

/// Ein Schiff: Startfeld (Reihe * 8 + Spalte), Länge, waagerecht (`quer`) oder senkrecht.
struct Schiff: Codable, Sendable, Equatable {
    var start: Int
    var laenge: Int
    var quer: Bool

    var zellen: [Int] {
        (0..<max(laenge, 0)).map { quer ? start + $0 : start + $0 * Schiffe.breite }
    }

    /// Liegt komplett auf dem Brett (kein Umbruch in die nächste Reihe).
    var aufDemBrett: Bool {
        guard laenge >= 1, (0..<Schiffe.felder).contains(start) else { return false }
        let reihe = start / Schiffe.breite, spalte = start % Schiffe.breite
        return quer ? spalte + laenge <= Schiffe.breite : reihe + laenge <= Schiffe.breite
    }
}

enum Schiffe {
    static let breite = 8
    static let felder = breite * breite
    static let laengen = [4, 3, 3, 2, 2]

    /// "C5": Spalte als Buchstabe, Reihe als Zahl.
    static func koordinate(_ zelle: Int) -> String {
        let buchstaben = Array("ABCDEFGH")
        guard (0..<felder).contains(zelle) else { return "?" }
        return "\(buchstaben[zelle % breite])\(zelle / breite + 1)"
    }

    // MARK: - Platzieren

    /// Richtige Längen, alle auf dem Brett, keine Überlappung.
    static func gueltig(_ flotte: [Schiff]) -> Bool {
        guard flotte.map(\.laenge).sorted() == laengen.sorted(), flotte.allSatisfy(\.aufDemBrett) else { return false }
        let alle = flotte.flatMap(\.zellen)
        return Set(alle).count == alle.count
    }

    private static func beruehrt(_ zellen: [Int], _ besetzt: Set<Int>) -> Bool {
        for z in zellen {
            let r = z / breite, c = z % breite
            for dr in -1...1 {
                for dc in -1...1 {
                    let rr = r + dr, cc = c + dc
                    if (0..<breite).contains(rr), (0..<breite).contains(cc), besetzt.contains(rr * breite + cc) { return true }
                }
            }
        }
        return false
    }

    /// Zufällige Flotte. Schiffe berühren sich nach Möglichkeit nicht; klappt das nach vielen
    /// Versuchen nicht, ist Berührung erlaubt. Der letzte Ausweg ist fest und immer gültig.
    static func zufaellig(using z: inout Zufall) -> [Schiff] {
        for versuch in 0..<300 {
            let streng = versuch < 200
            var flotte: [Schiff] = []
            var besetzt = Set<Int>()
            var geklappt = true
            for laenge in laengen {
                var moeglich: [Schiff] = []
                for start in 0..<felder {
                    for quer in [true, false] {
                        let s = Schiff(start: start, laenge: laenge, quer: quer)
                        guard s.aufDemBrett else { continue }
                        let zellen = s.zellen
                        if zellen.contains(where: { besetzt.contains($0) }) { continue }
                        if streng && beruehrt(zellen, besetzt) { continue }
                        moeglich.append(s)
                    }
                }
                guard !moeglich.isEmpty else {
                    geklappt = false
                    break
                }
                let s = moeglich[z.zahl(moeglich.count)]
                flotte.append(s)
                besetzt.formUnion(s.zellen)
            }
            if geklappt { return flotte }
        }
        return laengen.enumerated().map { Schiff(start: $0.offset * breite, laenge: $0.element, quer: true) }
    }

    /// Mit frischem Zufall, für den Knopf "Neu würfeln".
    static func zufaellig() -> [Schiff] {
        var z = Zufall(UInt64.random(in: 0...UInt64.max))
        return zufaellig(using: &z)
    }

    // MARK: - Schüsse

    enum Ausgang: Equatable, Sendable {
        case wasser
        case treffer
        case versenkt(Schiff)
    }

    struct Schuss: Equatable, Sendable {
        var von: Person
        var zelle: Int
        var ausgang: Ausgang
    }

    struct Stand: Equatable, Sendable {
        var verlauf: [Schuss] = []
        /// Wer als Nächstes schießt. Nil, solange Flotten fehlen, und nach dem Sieg.
        var amZug: Person?
        var sieger: Person?
        /// Beide Flotten liegen vor.
        var bereit = false

        func schuesse(von p: Person) -> [Schuss] { verlauf.filter { $0.von == p } }

        /// Felder, auf die `p` schon geschossen hat.
        func beschossen(von p: Person) -> Set<Int> { Set(schuesse(von: p).map(\.zelle)) }

        /// Schiffe, die `p` versenkt hat.
        func versenkt(von p: Person) -> [Schiff] {
            var liste: [Schiff] = []
            for schuss in schuesse(von: p) {
                if case .versenkt(let schiff) = schuss.ausgang { liste.append(schiff) }
            }
            return liste
        }
    }

    /// Spielt die Schüsse ab, `starter` zuerst, streng abwechselnd (auch nach einem Treffer).
    /// Ein ungültiger oder doppelter Schuss wird übersprungen und kostet keinen Zug.
    static func stand(starter: Person, flotten: [Person: [Schiff]], schuesse: [Person: [Int]]) -> Stand {
        var s = Stand()
        guard let fa = flotten[.ahmed], let fn = flotten[.annika], gueltig(fa), gueltig(fn) else { return s }
        s.bereit = true
        var dran = starter
        var index: [Person: Int] = [:]
        var beschossen: [Person: Set<Int>] = [:]
        while true {
            let liste = schuesse[dran] ?? []
            var i = index[dran, default: 0]
            while i < liste.count, !(0..<felder).contains(liste[i]) || beschossen[dran, default: []].contains(liste[i]) { i += 1 }
            index[dran] = i
            guard i < liste.count else {
                s.amZug = dran
                return s
            }
            let zelle = liste[i]
            index[dran] = i + 1
            beschossen[dran, default: []].insert(zelle)
            let flotte = flotten[dran.partner] ?? []
            let getroffen = flotte.first { $0.zellen.contains(zelle) }
            if let schiff = getroffen {
                let gesunken = schiff.zellen.allSatisfy { beschossen[dran, default: []].contains($0) }
                s.verlauf.append(Schuss(von: dran, zelle: zelle, ausgang: gesunken ? .versenkt(schiff) : .treffer))
                if gesunken, flotte.allSatisfy({ $0.zellen.allSatisfy { beschossen[dran, default: []].contains($0) } }) {
                    s.sieger = dran
                    s.amZug = nil
                    return s
                }
            } else {
                s.verlauf.append(Schuss(von: dran, zelle: zelle, ausgang: .wasser))
            }
            dran = dran.partner
        }
    }

    /// Aus dem Wörterbuch Schussnummer → Feld (so liegt es im Modell) die lückenlose Liste ab 0.
    /// Eine Lücke (Op noch unterwegs) beendet die Liste, spätere Schüsse warten.
    static func liste(aus schuesse: [Int: Int]) -> [Int] {
        var l: [Int] = []
        while let z = schuesse[l.count] { l.append(z) }
        return l
    }
}
