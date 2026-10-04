import Foundation
import Observation

/// Ahmeds Testdaten: feste Beispiele im Speicher. Nie gesendet, nie auf Platte.
@MainActor
@Observable
final class DemoZyklusSpeicher: ZyklusSpeicher {
    let quelle: ZyklusQuelle = .demo
    private(set) var tage: [String: ZyklusTag]
    var einstellung: ZyklusEinstellung

    init(heute: String = Datum.text(Date())) {
        tage = ZyklusDemoDaten.tage(heute: heute)
        einstellung = ZyklusDemoDaten.einstellung
    }

    func setze(_ tag: ZyklusTag) {
        tage[tag.id] = tag.istLeer ? nil : tag
    }
}

enum ZyklusSpeicherWahl {
    @MainActor private static var annikas: EchterZyklusSpeicher?

    /// Annika bekommt den echten Speicher (einmal angelegt), Ahmed immer die Demo.
    @MainActor
    static func fuer(person: Person) -> any ZyklusSpeicher {
        switch person {
        case .annika:
            if let s = annikas { return s }
            let s = EchterZyklusSpeicher.standard()
            annikas = s
            return s
        case .ahmed:
            return DemoZyklusSpeicher()
        }
    }
}
