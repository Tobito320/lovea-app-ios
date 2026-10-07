import Foundation

/// Einmaliger Dank: 5.000 Punkte je Person. Feste Op-ID je Person, damit jedes Gerät dieselbe Op
/// schickt (Server `INSERT OR IGNORE`) und die Faltung nach ID genau einmal zählt; nach einer
/// Neuinstallation kommt die Op aus dem Log zurück und wird nicht erneut gebucht.
enum DankLogik {
    static let art = "punkte.dank"
    static let datum = "2026-10-07"
    static let punkte = 5_000
    static let grund = "Danke fürs Aushalten der App-Probleme"

    struct D: Codable { var fuer: Person }

    static func opId(_ person: Person) -> String { "dank-\(datum)-\(person.rawValue)" }

    /// Nur die zwei festen IDs zählen, je ID einmal, egal wie oft oder von welchem Gerät geliefert.
    static func eintraege(_ ops: [(id: String, fuer: Person)]) -> [PunkteLogik.Eintrag] {
        let gueltig = Set(ops.filter { $0.id == opId($0.fuer) }.map(\.fuer))
        return Person.allCases.filter(gueltig.contains).map {
            PunkteLogik.Eintrag(datum: datum, von: $0, grund: grund, punkte: punkte)
        }
    }

    static func fehlende(gebucht: Set<Person>) -> [Person] { Person.allCases.filter { !gebucht.contains($0) } }

    static func op(fuer: Person, von: Person) -> Op {
        let neu = Op.neu(art, D(fuer: fuer), von: von)
        return Op(id: opId(fuer), seq: nil, art: art, von: von, zeit: neu.zeit, d: neu.d)
    }
}
