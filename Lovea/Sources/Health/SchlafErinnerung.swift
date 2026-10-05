import Foundation
import UserNotifications

/// Auswertungen und Erinnerung rund um den Schlaf. Reine Rechnung, außer `BettErinnerung.planen`.
extension SchlafLogik {
    /// Schlafschuld: wie viel unter dem Ziel über die letzten Nächte, nie unter 0 (Überschuss gleicht aus).
    /// Unter 3 Nächten mit Daten: nichts.
    static func schuld(_ naechte: [(minuten: Int, ziel: Int)]) -> Int? {
        guard naechte.count >= 3 else { return nil }
        return max(0, naechte.reduce(0) { $0 + $1.ziel - $1.minuten })
    }

    /// Schlaf nach Tagen mit spätem Koffein (ab 16 Uhr) gegen Schlaf nach Tagen ohne. Je Gruppe mindestens 3 Nächte,
    /// sonst nichts. Zeigt nur einen Unterschied ab 20 min.
    static func koffeinVergleich(_ naechte: [(minuten: Int, spaet: Bool)]) -> (mit: Int, ohne: Int)? {
        let mit = naechte.filter(\.spaet).map(\.minuten)
        let ohne = naechte.filter { !$0.spaet }.map(\.minuten)
        guard mit.count >= 3, ohne.count >= 3 else { return nil }
        let a = mit.reduce(0, +) / mit.count
        let b = ohne.reduce(0, +) / ohne.count
        return b - a >= 20 ? (a, b) : nil
    }
}

extension SchlafSignale {
    /// Erste eigene Chat-Nachricht am Morgen mit "Guten Morgen" oder "Moin": wach. Wie "Wecker aus" beendet sie die Nacht.
    static func guterMorgen(_ nachrichten: [(zeit: Date, text: String)], tagStart: Date) -> Date? {
        let kal = Calendar.berlin
        guard let von = kal.date(byAdding: .hour, value: 3, to: tagStart),
              let bis = kal.date(byAdding: .hour, value: 14, to: tagStart) else { return nil }
        return nachrichten
            .filter { n in
                let t = n.text.lowercased()
                return n.zeit >= von && n.zeit < bis && (t.contains("guten morgen") || t.contains("moin") || t.hasPrefix("morgen"))
            }
            .map(\.zeit).min()
    }
}

/// Stille Erinnerung "Bettzeit in 30 Minuten", aus der gelernten Bettzeit (`SchlafLogik.gewohnheit`).
/// Ein Eintrag je Wochentag, wiederholt sich, kein Timer. Standardmäßig aus (Einstellungen).
enum BettErinnerung {
    static let schluessel = "schlaf.bettErinnerung"
    static let vorlauf = 30
    private static func kennung(_ wochentag: Int) -> String { "schlaf.bett.\(wochentag)" }

    static var an: Bool { UserDefaults.standard.bool(forKey: schluessel) }

    /// Wochentag (1 = Sonntag … 7 = Samstag) und Minute am Tag für die Erinnerung vor der Nacht, die am Abend dieses Tages beginnt.
    static func plan(werktag: (bett: Int, auf: Int)?, wochenende: (bett: Int, auf: Int)?) -> [(wochentag: Int, minute: Int)] {
        (1...7).compactMap { w in
            let aufwachTag = (w % 7) + 1
            let istWochenende = aufwachTag == 1 || aufwachTag == 7
            guard let g = istWochenende ? (wochenende ?? werktag) : (werktag ?? wochenende) else { return nil }
            // Nach Mitternacht (00:30) liegt die Bettzeit hinter 23:00; die Erinnerung kann dann schon am nächsten Kalendertag fallen.
            let verschoben = (g.bett < 720 ? g.bett + 1440 : g.bett) - vorlauf
            let tagVersatz = verschoben >= 1440 ? 1 : 0
            return (((w - 1 + tagVersatz) % 7) + 1, verschoben % 1440)
        }
    }

    static func planen(werktag: (bett: Int, auf: Int)?, wochenende: (bett: Int, auf: Int)?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map(kennung))
        guard an else { return }
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Bettzeit"
        inhalt.body = "In \(vorlauf) Minuten ist deine übliche Bettzeit."
        inhalt.sound = UNNotificationSound(named: UNNotificationSoundName("stille.wav"))
        for p in plan(werktag: werktag, wochenende: wochenende) {
            var komponenten = DateComponents()
            komponenten.weekday = p.wochentag
            komponenten.hour = p.minute / 60
            komponenten.minute = p.minute % 60
            center.add(UNNotificationRequest(identifier: kennung(p.wochentag), content: inhalt,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: komponenten, repeats: true)), withCompletionHandler: nil)
        }
    }
}
