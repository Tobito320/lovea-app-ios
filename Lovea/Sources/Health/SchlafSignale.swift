import Foundation

/// Rohsignale für das Schlaf-Punktesystem (`SchlafPunkte.swift`), die iOS nicht von selbst aufbewahrt:
/// Laden, Fokus "Schlafen", Wecker aus, Heim-WLAN (kommen als Kurzbefehl, `SchlafSignalIntent`), App
/// geöffnet, Boot-Zeit. Ein kleines Protokoll in UserDefaults, 14 Tage. Kein Sensor, kein Timer: jedes
/// Signal schreibt nur, wenn es ohnehin passiert.
struct SchlafSignal: Codable, Sendable, Equatable {
    /// "laden", "fokus", "daheim", "aus" (Zustände mit an/aus) oder "aktiv", "wecker" (Punkte, `an` immer true).
    var art: String
    var zeit: Date
    var an: Bool
}

enum SchlafSignale {
    typealias Spanne = HealthLogik.SchlafIntervall

    static let schluessel = "schlaf.signale.v1"
    static let bootSchluessel = "schlaf.boot.v1"
    static let lebtSchluessel = "schlaf.lebt.v1"
    static let behalten: TimeInterval = 14 * 86_400
    /// So lange gilt ein Griff zum Handy (App geöffnet, Chat gesendet, Neustart) als wach.
    static let aktivDauer: TimeInterval = 3 * 60
    /// War das Handy länger aus, ist das eher eine leere Akku-Nacht oder Flugmodus als ein Ausschalten: nur ein Wach-Punkt beim Start.
    static let ausMax: TimeInterval = 3 * 3600
    static let ausMin: TimeInterval = 60

    // MARK: - Reine Rechnung

    /// Zustände ohne Änderung (zweimal "lädt") werden nicht doppelt gespeichert. Alte Einträge fallen weg.
    static func hinzufuegen(_ liste: [SchlafSignal], _ neu: SchlafSignal, jetzt: Date) -> [SchlafSignal] {
        var l = liste.filter { jetzt.timeIntervalSince($0.zeit) < behalten }
        if neu.art != "aktiv", neu.art != "wecker",
           let letzter = l.last(where: { $0.art == neu.art }), letzter.an == neu.an { return l }
        l.append(neu)
        return l
    }

    /// Zustand `wennAn` von einem Ereignis bis zum nächsten der Gegenrichtung; offen: bis `bis`.
    static func spannen(_ liste: [SchlafSignal], art: String, wennAn: Bool = true, bis: Date) -> [Spanne] {
        let eigene = liste.filter { $0.art == art }.sorted { $0.zeit < $1.zeit }
        var ergebnis: [Spanne] = []
        var start: Date?
        for e in eigene {
            if e.an == wennAn {
                if start == nil { start = e.zeit }
            } else if let s = start {
                if e.zeit > s { ergebnis.append(Spanne(von: s, bis: e.zeit)) }
                start = nil
            }
        }
        if let s = start, bis > s { ergebnis.append(Spanne(von: s, bis: bis)) }
        return ergebnis
    }

    /// Jeder Zeitpunkt (App geöffnet, Chat gesendet, Neustart) ist eine kurze Wach-Spanne.
    static func kurzWach(_ zeiten: [Date]) -> [Spanne] {
        zeiten.map { Spanne(von: $0, bis: $0.addingTimeInterval(aktivDauer)) }
    }

    static func aktivZeiten(_ liste: [SchlafSignal]) -> [Date] {
        liste.filter { $0.art == "aktiv" }.map(\.zeit)
    }

    /// Letztes "Wecker aus" des Aufwach-Tages, früh genug am Morgen (ab 03 Uhr bis 14 Uhr).
    static func weckerAus(_ liste: [SchlafSignal], tagStart: Date) -> Date? {
        let kal = Calendar.berlin
        guard let von = kal.date(byAdding: .hour, value: 3, to: tagStart),
              let bis = kal.date(byAdding: .hour, value: 14, to: tagStart) else { return nil }
        return liste.filter { $0.art == "wecker" && $0.zeit >= von && $0.zeit < bis }.map(\.zeit).min()
    }

    /// Neuer Start des Handys erkannt (`boot` anders als beim letzten Mal): Wach-Punkt beim Start, und die Zeit
    /// seit dem letzten Lebenszeichen als "aus", wenn sie zwischen 1 min und 3 h liegt.
    /// Ohne bekannten letzten Boot (erster Start nach der Installation): nichts.
    static func bootEreignisse(boot: Date, letzterBoot: Date?, lebt: Date?) -> [SchlafSignal] {
        guard let letzterBoot, abs(boot.timeIntervalSince(letzterBoot)) > 5 else { return [] }
        var e = [SchlafSignal(art: "aktiv", zeit: boot, an: true)]
        if let lebt, boot > lebt {
            let luecke = boot.timeIntervalSince(lebt)
            if luecke >= ausMin, luecke <= ausMax {
                e.append(SchlafSignal(art: "aus", zeit: lebt, an: true))
                e.append(SchlafSignal(art: "aus", zeit: boot, an: false))
            }
        }
        return e
    }

    // MARK: - Speicher (UserDefaults)

    static func laden() -> [SchlafSignal] {
        guard let daten = UserDefaults.standard.data(forKey: schluessel),
              let liste = try? JSONDecoder().decode([SchlafSignal].self, from: daten) else { return [] }
        return liste
    }

    static func aufzeichnen(art: String, an: Bool, zeit: Date = Date()) {
        let liste = hinzufuegen(laden(), SchlafSignal(art: art, zeit: zeit, an: an), jetzt: zeit)
        if let daten = try? JSONEncoder().encode(liste) { UserDefaults.standard.set(daten, forKey: schluessel) }
    }

    /// Zeit des letzten Neustarts (`kern.boottime`), nicht `jetzt - systemUptime`: der Uptime-Zähler hält im Standby an.
    static func bootZeit() -> Date? {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var tv = timeval()
        var groesse = MemoryLayout<timeval>.stride
        guard sysctl(&mib, UInt32(mib.count), &tv, &groesse, nil, 0) == 0, tv.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec))
    }

    // MARK: - Haken in der App (nur auf dem iPhone)

    /// Beim Start: neuer Boot? Dann Ereignisse schreiben. Merkt sich den Boot immer.
    @MainActor static func bootErfassen() {
        guard Geraet.wirdGetragen, let boot = bootZeit() else { return }
        let d = UserDefaults.standard
        let letzter = (d.object(forKey: bootSchluessel) as? Double).map { Date(timeIntervalSince1970: $0) }
        let lebt = (d.object(forKey: lebtSchluessel) as? Double).map { Date(timeIntervalSince1970: $0) }
        for e in bootEreignisse(boot: boot, letzterBoot: letzter, lebt: lebt) {
            aufzeichnen(art: e.art, an: e.an, zeit: e.zeit)
        }
        d.set(boot.timeIntervalSince1970, forKey: bootSchluessel)
    }

    /// App wurde geöffnet: wach. Höchstens einmal je Minute.
    @MainActor static func aktivMelden() {
        guard Geraet.wirdGetragen else { return }
        let jetzt = Date()
        if let letzter = aktivZeiten(laden()).max(), jetzt.timeIntervalSince(letzter) < 60 { return }
        aufzeichnen(art: "aktiv", an: true, zeit: jetzt)
        lebtMelden()
    }

    /// Letztes Lebenszeichen der App (Öffnen und in den Hintergrund gehen), für die Aus-Lücke beim nächsten Boot.
    @MainActor static func lebtMelden() {
        guard Geraet.wirdGetragen else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lebtSchluessel)
    }
}
