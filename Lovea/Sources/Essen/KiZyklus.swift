import Foundation

/// Zyklustag und Phase fuer Coach und Bericht. Standard ist AUS: ohne Freigabe in den
/// Zyklus-Einstellungen verlaesst kein Zyklus-Wert das Geraet. Nur Annikas Geraet sendet,
/// auf Ahmeds Geraet (`nurLesen`) bleibt es still -- er sieht die Felder nie.
enum KiZyklus {
    /// Die Namen, die der Server kennt (`server/ki.js`).
    static func name(_ phase: Phase) -> String {
        switch phase {
        case .periode: return "menstruation"
        case .follikel, .fruchtbar: return "follikel"
        case .eisprung: return "ovulation"
        case .luteal: return "luteal"
        }
    }

    static func fuerKi(freigabe: Bool, nurLesen: Bool, logik: ZyklusLogik, heute: String) -> (tag: Int, phase: String?)? {
        guard freigabe, !nurLesen, let nummer = logik.zyklusTagNummer(am: heute) else { return nil }
        return (nummer, logik.phase(am: heute).map(name))
    }
}
