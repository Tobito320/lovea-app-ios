import Foundation

/// Ein Protokoll, zwei Quellen: Annikas echte Daten (`.echt`) und feste Testdaten (`.demo`).
/// `tage` ist nach `ZyklusTag.id` (yyyy-MM-dd) geschlüsselt. Ein leerer Tag (`istLeer`) wird beim Setzen entfernt.
@MainActor
protocol ZyklusSpeicher: AnyObject {
    var quelle: ZyklusQuelle { get }
    var tage: [String: ZyklusTag] { get }
    var einstellung: ZyklusEinstellung { get set }
    func setze(_ tag: ZyklusTag)
}

extension ZyklusSpeicher {
    func logik(heute: String = Datum.text(Date())) -> ZyklusLogik {
        ZyklusLogik(tage: Array(tage.values), einstellung: einstellung, heute: heute)
    }
}
