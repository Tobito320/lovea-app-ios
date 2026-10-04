import SwiftUI
import UserNotifications

enum ErinnerungsArt: String, Codable, CaseIterable, Hashable {
    case periodeBald, fruchtbar, eisprung, pille, wasser, eintragen, verspaetung

    var titel: String {
        switch self {
        case .periodeBald: "Periode bald"
        case .fruchtbar: "Fruchtbare Tage"
        case .eisprung: "Eisprung"
        case .pille: "Pille"
        case .wasser: "Wasser trinken"
        case .eintragen: "Tag eintragen"
        case .verspaetung: "Verspätung"
        }
    }

    var symbol: String {
        switch self {
        case .periodeBald: "drop.fill"
        case .fruchtbar: "sparkles"
        case .eisprung: "circle.dotted"
        case .pille: "pills.fill"
        case .wasser: "waterbottle.fill"
        case .eintragen: "square.and.pencil"
        case .verspaetung: "clock.fill"
        }
    }

    /// Standard-Uhrzeit in Minuten seit Mitternacht.
    var standardMinute: Int {
        switch self {
        case .pille: 20 * 60
        case .wasser: 15 * 60
        case .eintragen: 21 * 60
        default: 9 * 60
        }
    }

    /// Nur auf dem Sperrbildschirm sichtbar: neutral, kein Zyklus-Wort.
    var text: String {
        switch self {
        case .periodeBald: "Gönn dir heute etwas Gemütliches."
        case .fruchtbar: "Ein kleiner Gruß für dich."
        case .eisprung: "Heute ist ein besonderer Tag."
        case .pille: "Dein kleiner Moment am Tag."
        case .wasser: "Zeit für ein Glas Wasser."
        case .eintragen: "Wie war dein Tag? Erzähl es kurz."
        case .verspaetung: "Schau mal rein, wie es dir geht."
        }
    }
}

/// Welche Arten an sind und wann. Standard: alles aus, die Berechtigung kommt erst auf Wunsch.
struct ErinnerungsEinstellung: Codable, Equatable {
    var aktiv: Set<ErinnerungsArt> = []
    var minuten: [ErinnerungsArt: Int] = [:]
    /// Tage vor der erwarteten Periode.
    var vorlaufTage = 2

    func minute(_ art: ErinnerungsArt) -> Int { minuten[art] ?? art.standardMinute }

    private static let schluessel = "lovea.zyklus.erinnerungen"

    static func laden(_ defaults: UserDefaults = .standard) -> ErinnerungsEinstellung {
        defaults.data(forKey: schluessel).flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? ErinnerungsEinstellung()
    }

    func speichern(_ defaults: UserDefaults = .standard) {
        if let daten = try? JSONEncoder().encode(self) { defaults.set(daten, forKey: Self.schluessel) }
    }
}

struct GeplanteErinnerung: Equatable, Identifiable {
    enum Zeit: Equatable {
        case taeglich(minute: Int)
        case einmalig(tag: String, minute: Int)
    }

    let art: ErinnerungsArt
    let zeit: Zeit
    var titel: String { "Lovea" }
    var text: String { art.text }

    var id: String {
        switch zeit {
        case .taeglich: "\(ErinnerungsPlan.praefix)\(art.rawValue).taeglich"
        case .einmalig(let tag, _): "\(ErinnerungsPlan.praefix)\(art.rawValue).\(tag)"
        }
    }
}

/// Reine Planung: welche Termine gibt es? Kein Zugriff auf das System.
enum ErinnerungsPlan {
    static let praefix = "lovea.zyklus."
    /// So viele Zyklen werden vorausgeplant.
    static let zyklen = 2
    /// Verspätungs-Erinnerung so viele Tage nach dem erwarteten Termin.
    static let verspaetungNachTagen = 3

    /// `jetztMinute`: Uhrzeit jetzt in Minuten; heutige Termine davor entfallen.
    static func plan(logik: ZyklusLogik, einstellung: ErinnerungsEinstellung, heute: String, jetztMinute: Int) -> [GeplanteErinnerung] {
        let modus = logik.einstellung.modus
        var ergebnis: [GeplanteErinnerung] = []

        func taeglich(_ art: ErinnerungsArt) {
            guard einstellung.aktiv.contains(art) else { return }
            ergebnis.append(GeplanteErinnerung(art: art, zeit: .taeglich(minute: einstellung.minute(art))))
        }
        func einmalig(_ art: ErinnerungsArt, _ tag: String) {
            guard einstellung.aktiv.contains(art) else { return }
            let minute = einstellung.minute(art)
            if tag < heute || (tag == heute && minute <= jetztMinute) { return }
            ergebnis.append(GeplanteErinnerung(art: art, zeit: .einmalig(tag: tag, minute: minute)))
        }

        taeglich(.wasser)
        taeglich(.eintragen)
        if modus == .pille { taeglich(.pille) }

        if modus == .zyklus || modus == .kinderwunsch, let naechste = logik.naechstePeriode {
            let laenge = logik.mittlereZyklusLaenge
            for k in 0..<zyklen {
                let periode = Datum.addTage(naechste, k * laenge)
                let eisprung = Datum.addTage(periode, -ZyklusLogik.lutealTage)
                einmalig(.periodeBald, Datum.addTage(periode, -einstellung.vorlaufTage))
                einmalig(.fruchtbar, Datum.addTage(eisprung, -5))
                einmalig(.eisprung, eisprung)
                if k == 0 { einmalig(.verspaetung, Datum.addTage(periode, verspaetungNachTagen)) }
            }
        }
        return ergebnis.sorted { $0.id < $1.id }
    }
}

/// Bringt den Plan zum System. Die Berechtigung wird nur auf Wunsch abgefragt.
@MainActor
final class ZyklusErinnerungsPlaner {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var erlaubt: Bool {
        get async {
            let s = await center.notificationSettings().authorizationStatus
            return s == .authorized || s == .provisional || s == .ephemeral
        }
    }

    func berechtigungErfragen() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Ersetzt alle Zyklus-Erinnerungen durch den neuen Plan. Ohne Berechtigung bleibt alles leer.
    func planen(_ plan: [GeplanteErinnerung]) async {
        let alt = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(ErinnerungsPlan.praefix) }
        center.removePendingNotificationRequests(withIdentifiers: alt)
        guard await erlaubt else { return }
        for e in plan {
            let inhalt = UNMutableNotificationContent()
            inhalt.title = e.titel
            inhalt.body = e.text
            inhalt.sound = .default
            var teile = DateComponents()
            let minute: Int
            let wiederholt: Bool
            switch e.zeit {
            case .taeglich(let m):
                minute = m; wiederholt = true
            case .einmalig(let tag, let m):
                minute = m; wiederholt = false
                let k = Datum.kalender.dateComponents([.year, .month, .day], from: Datum.datum(tag))
                teile.year = k.year; teile.month = k.month; teile.day = k.day
            }
            teile.hour = minute / 60
            teile.minute = minute % 60
            teile.timeZone = Datum.kalender.timeZone
            let ausloeser = UNCalendarNotificationTrigger(dateMatching: teile, repeats: wiederholt)
            try? await center.add(UNNotificationRequest(identifier: e.id, content: inhalt, trigger: ausloeser))
        }
    }

    func alleEntfernen() async {
        let alt = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(ErinnerungsPlan.praefix) }
        center.removePendingNotificationRequests(withIdentifiers: alt)
    }
}

/// Schalter je Art. `erlauben` wird beim Einschalten gerufen; die Verdrahtung fragt dort die Berechtigung ab und plant neu.
struct ZyklusErinnerungenView: View {
    @Binding var einstellung: ErinnerungsEinstellung
    var arten: [ErinnerungsArt] = ErinnerungsArt.allCases
    var erlauben: () -> Void = {}
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                Text("Erinnerungen")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                ForEach(arten, id: \.self) { art in
                    Toggle(isOn: Binding(
                        get: { einstellung.aktiv.contains(art) },
                        set: { an in
                            if an { einstellung.aktiv.insert(art); erlauben() } else { einstellung.aktiv.remove(art) }
                        })
                    ) {
                        Label(art.titel, systemImage: art.symbol)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(ZyklusFarbe.tinte(schema))
                    }
                    .tint(ZyklusFarbe.himbeere.farbe(schema))
                }
                Text("Auf dem Sperrbildschirm steht nur ein lieber Gruß, nichts Privates.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
            }
        }
    }
}
