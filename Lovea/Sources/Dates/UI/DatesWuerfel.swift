import Foundation

struct DatesWuerfelEintrag: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
}

/// Der Würfel der Date-Ideen zieht aus allem Offenen: offene Date-Ideen und offene Wünsche aus "Unsere Liste".
/// Die letzten gezogenen bleiben draußen, solange noch etwas anderes da ist.
enum DatesWuerfel {
    static func pool(ideen: [DateIdee], wuensche: [(id: String, text: String)], letzte: [String]) -> [DatesWuerfelEintrag] {
        let offen = ideen.filter { !$0.erledigt && !$0.geloescht }.map { DatesWuerfelEintrag(id: $0.id, text: $0.titel) }
        let liste = wuensche.map { DatesWuerfelEintrag(id: "liste-" + $0.id, text: $0.text) }
        let alle = offen + liste
        let frisch = alle.filter { !letzte.contains($0.id) }
        return frisch.isEmpty ? alle : frisch
    }
}
