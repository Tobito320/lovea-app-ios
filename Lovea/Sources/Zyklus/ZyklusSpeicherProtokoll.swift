import Foundation

/// Ein Protokoll, zwei Quellen: Annikas Daten (`.echt`; Ahmed sieht sie nur, `nurLesen`) und feste Testdaten in Tests (`.demo`).
/// `tage` ist nach `ZyklusTag.id` (yyyy-MM-dd) geschlüsselt. Ein leerer Tag (`istLeer`) wird beim Setzen entfernt.
@MainActor
protocol ZyklusSpeicher: AnyObject {
    var quelle: ZyklusQuelle { get }
    var tage: [String: ZyklusTag] { get }
    var einstellung: ZyklusEinstellung { get set }
    /// Wahr auf Ahmeds Gerät: Annikas Zyklus nur ansehen, nichts ändern.
    var nurLesen: Bool { get }
    func setze(_ tag: ZyklusTag)
}

extension ZyklusSpeicher {
    var nurLesen: Bool { false }
    func logik(heute: String = Datum.text(Date())) -> ZyklusLogik {
        ZyklusLogik(tage: Array(tage.values), einstellung: einstellung, heute: heute)
    }
}
