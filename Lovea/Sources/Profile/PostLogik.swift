import Foundation

/// p71 (aus p67 B): Briefkasten und Telefon im Profil zeigen die vorhandene Post (`BriefeSpeicher`, `SprachpostSpeicher`),
/// nichts Neues. Hier nur die Regel für Punkt und Beschriftung.
enum PostLogik {
    /// Roter Punkt nur, wenn etwas Ungeöffnetes oder Ungehörtes da ist.
    static func punkt(_ neu: Int) -> Bool { neu > 0 }

    static func beschriftung(_ name: String, neu: Int) -> String { neu > 0 ? "\(name), \(neu) neu" : name }
}
