import Foundation

/// Z-33.3, like iMessage: edit up to 5 times within 15 minutes, unsend within 2 minutes. UI only —
/// the menu items disappear, the fold keeps accepting every op (old edits and deletes stay valid).
enum ChatZeitfenster {
    static func darfBearbeiten(gesendet: Date, bearbeitungen: Int, jetzt: Date) -> Bool {
        jetzt.timeIntervalSince(gesendet) < 15 * 60 && bearbeitungen < 5
    }

    static func darfZurueckziehen(gesendet: Date, jetzt: Date) -> Bool {
        jetzt.timeIntervalSince(gesendet) < 2 * 60
    }
}
