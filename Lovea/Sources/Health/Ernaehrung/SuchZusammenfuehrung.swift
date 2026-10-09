import Foundation

/// Stand einer laufenden Suche: `nummer` zählt jede Texteingabe, damit eine späte Server-Antwort zu
/// einer schon überholten Eingabe erkannt und verworfen werden kann.
struct SuchStand: Equatable {
    var nummer: Int = 0
    var lokal: [Lebensmittel] = []
    var server: [Lebensmittel] = []
    var sichtbar: [Lebensmittel] = []
}

/// Server-Treffer kommen später als lokale. Sie werden nur hinten angehängt, damit nichts springt,
/// und eine Antwort zu einer älteren Eingabe wird verworfen.
enum SuchZusammenfuehrung {
    static func server(_ s: SuchStand, antwort: [Lebensmittel], nummer: Int) -> SuchStand {
        guard nummer == s.nummer else { return s }
        var neu = s
        var ids = Set(s.sichtbar.map(\.id))
        var codes = Set(s.sichtbar.compactMap(\.barcode))
        let dazu = antwort.filter { l in
            guard !ids.contains(l.id), l.barcode.map({ !codes.contains($0) }) ?? true else { return false }
            ids.insert(l.id)
            if let c = l.barcode { codes.insert(c) }
            return true
        }
        neu.server = antwort
        neu.sichtbar = Array((s.sichtbar + dazu).prefix(80))
        return neu
    }
}
