import Foundation
import Observation
import UserNotifications

/// Eine Übung im Training: aus dem Plantag, oder im Training dazugekommen (`extra`).
struct WorkoutUebung: Identifiable, Equatable, Sendable {
    var planUebung: PlanUebung
    /// Die Satzzeilen, wie sie gerade stehen; leer bei Cardio.
    var saetze: [PlanSatz]
    /// Dieselbe Übung beim letzten Mal (Spalte "Vorher").
    var vorher: [PlanSatz]
    var extra: Bool
    var cardioFertig = false

    var id: String { planUebung.id }
    var gesamt: Int { planUebung.istCardio ? 1 : saetze.count }
    var fertigZahl: Int { planUebung.istCardio ? (cardioFertig ? 1 : 0) : saetze.filter { $0.ok == true }.count }
    var fertig: Bool { gesamt > 0 && fertigZahl == gesamt }
}

enum WorkoutLogik {
    static let standardPause = 120
    static let pausen = [0, 60, 90, 120, 150, 180, 240, 300]
    static let scheibenGroessen: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    /// Plan-Übungen in Planreihenfolge, dahinter die im Training dazugekommenen. `frueher`: ältere
    /// Einheiten, neueste zuerst.
    static func uebungen(_ s: GymSession, tag: TrainingsTag?, frueher: [GymSession]) -> [WorkoutUebung] {
        var letzter: [String: UebungsLauf] = [:]
        var reihenfolge: [String] = []
        for l in s.laeufe {
            if letzter[l.plan] == nil { reihenfolge.append(l.plan) }
            letzter[l.plan] = l
        }
        let geplant = tag?.uebungen ?? []
        let planIds = Set(geplant.map(\.id))
        let extras = reihenfolge.filter { !planIds.contains($0) }.compactMap { id -> PlanUebung? in
            guard let l = letzter[id] else { return nil }
            let cardio = UebungsKatalog.nachId[l.uebung]?.istCardio == true
            return PlanUebung(id: id, uebung: l.uebung, name: l.name, saetze: [], minuten: cardio ? 20 : nil)
        }
        let alle = geplant.map { ($0, false) } + extras.map { ($0, true) }
        return alle.map { u, extra in
            let vorher = vorherige(u, in: frueher)
            let lauf = letzter[u.id]
            return WorkoutUebung(planUebung: u, saetze: zeilen(u, lauf: lauf, vorher: vorher), vorher: vorher, extra: extra,
                                 cardioFertig: u.istCardio && lauf?.fertig == true)
        }
    }

    /// Die Satzzeilen einer Übung: der gesendete Stand, sonst (alte Einheit) die abgehakten Sätze,
    /// sonst die Plan-Sätze mit den Werten vom letzten Mal.
    static func zeilen(_ u: PlanUebung, lauf: UebungsLauf?, vorher: [PlanSatz]) -> [PlanSatz] {
        if u.istCardio { return [] }
        if let stand = lauf?.stand { return stand }
        if let lauf, lauf.fertig {
            return (lauf.saetze ?? u.saetze).map { alt in
                var s = alt
                s.ok = true
                return s
            }
        }
        return u.saetze.enumerated().map { i, p in
            var s = p.alsPlan
            if vorher.indices.contains(i) {
                s.kg = vorher[i].kg
                s.wdh = vorher[i].wdh
            }
            return s
        }
    }

    /// Die abgehakten Sätze derselben Übung aus der letzten Einheit davor. Katalog-Übungen über die
    /// Katalog-id (egal an welchem Tag), eigene über ihren Plan-Eintrag.
    static func vorherige(_ u: PlanUebung, in frueher: [GymSession]) -> [PlanSatz] {
        for s in frueher {
            for l in s.laeufe.reversed() {
                guard u.uebung == PlanUebung.eigen ? l.plan == u.id : l.uebung == u.uebung else { continue }
                let gemacht = l.stand?.filter { $0.ok == true } ?? (l.fertig ? l.saetze ?? [] : [])
                if !gemacht.isEmpty { return gemacht }
            }
        }
        return []
    }

    /// Der erste offene Satz in Reihenfolge: welche Übung, welcher Satz. nil = alles fertig.
    static func dran(_ liste: [WorkoutUebung]) -> (uebung: Int, satz: Int)? {
        for (i, u) in liste.enumerated() where !u.fertig {
            if u.planUebung.istCardio { return (i, 0) }
            if let j = u.saetze.firstIndex(where: { $0.ok != true }) { return (i, j) }
        }
        return nil
    }

    static func volumen(_ liste: [WorkoutUebung]) -> Double {
        liste.flatMap(\.saetze).filter(\.zaehlt).reduce(0) { $0 + ($1.kg ?? 0) * Double($1.wdh) }
    }

    static func saetzeZahl(_ liste: [WorkoutUebung]) -> Int {
        liste.flatMap(\.saetze).filter { $0.ok == true }.count
    }

    /// Der Plantag, wie er nach diesem Training aussähe. nil, wenn sich am Aufbau nichts geändert
    /// hat (gleiche Übungen, gleich viele Sätze, gleiche Satztypen): dann wird nicht gefragt.
    static func neuerTag(_ tag: TrainingsTag, _ liste: [WorkoutUebung]) -> TrainingsTag? {
        var neu = tag
        var anders = false
        for u in liste where !u.planUebung.istCardio {
            let saetze = u.saetze.map(\.alsPlan)
            if let i = neu.uebungen.firstIndex(where: { $0.id == u.id }) {
                if neu.uebungen[i].saetze.map(\.kuerzel) != saetze.map(\.kuerzel) { anders = true }
                neu.uebungen[i].saetze = saetze
            } else if u.fertigZahl > 0 {
                var dazu = u.planUebung
                dazu.saetze = saetze
                neu.uebungen.append(dazu)
                anders = true
            }
        }
        return anders ? neu : nil
    }

    /// "1", "2" für normale Sätze (Aufwärmsätze zählen nicht mit), sonst "W", "D", "F".
    static func nummer(_ saetze: [PlanSatz], _ i: Int) -> String {
        guard saetze.indices.contains(i) else { return "" }
        return saetze[i].kuerzel ?? String(saetze[...i].filter { $0.typ != "w" }.count)
    }

    /// Scheiben pro Seite für `kg` auf der Stange, schwerste zuerst.
    static func scheiben(kg: Double, stange: Double = 20) -> [Double] {
        var rest = (kg - stange) / 2
        var liste: [Double] = []
        for g in scheibenGroessen {
            while rest >= g - 0.001 {
                liste.append(g)
                rest -= g
            }
        }
        return liste
    }

    /// Drei Aufwärmsätze aus dem Arbeitsgewicht: 40 % × 10, 60 % × 5, 80 % × 3, auf 2,5 kg gerundet.
    static func aufwaermen(arbeit: Double) -> [PlanSatz] {
        let stufen: [(Double, Int)] = [(0.4, 10), (0.6, 5), (0.8, 3)]
        return stufen.map { anteil, wdh in
            PlanSatz(wdh: wdh, kg: max(2.5, (arbeit * anteil / 2.5).rounded() * 2.5), failure: false, typ: "w")
        }
    }

    /// "32 kg × 12", ohne Gewicht "12 Wdh".
    static func satzText(_ s: PlanSatz) -> String {
        s.kg.map { "\(TrainingLogik.kgText($0)) kg × \(s.wdh)" } ?? "\(s.wdh) Wdh"
    }

    /// "1:05".
    static func zeitText(_ sekunden: Double) -> String {
        let s = max(0, Int(sekunden.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "2:00", bei 0 "aus".
    static func pauseText(_ sekunden: Int) -> String {
        sekunden == 0 ? "aus" : zeitText(Double(sekunden))
    }
}

/// Was gerade läuft: ein Satz oder die Pause danach. Nur auf diesem Gerät (kein Op): gespeichert
/// werden Zeitpunkte, die Anzeige rechnet daraus. Kein Timer im Hintergrund (Akku-Regel).
@MainActor @Observable
final class WorkoutUhr {
    static let shared = WorkoutUhr()
    private static let schluessel = "gym.uhr"
    private static let mitteilungId = "gym.pause"

    struct Stand: Codable, Equatable, Sendable {
        var session: String
        var plan: String
        var satz: Int
        var seit: Date
        var pause: Bool
        /// Pausenziel in Sekunden, 0 = ohne Ziel.
        var ziel: Int

        var pauseEnde: Date? { pause && ziel > 0 ? seit.addingTimeInterval(Double(ziel)) : nil }
    }

    private(set) var stand: Stand?

    private init() {
        if let daten = UserDefaults.standard.data(forKey: Self.schluessel) {
            stand = try? JSONDecoder().decode(Stand.self, from: daten)
        }
    }

    private func setzen(_ neu: Stand?) {
        stand = neu
        UserDefaults.standard.set(neu.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.schluessel)
        GymLive.abgleichen()
    }

    func satzStarten(session: String, plan: String, satz: Int) {
        setzen(Stand(session: session, plan: plan, satz: satz, seit: Date(), pause: false, ziel: 0))
    }

    /// Wie lange genau dieser Satz schon läuft; nil, wenn er nicht gestartet wurde.
    func satzDauer(plan: String, satz: Int) -> Double? {
        guard let s = stand, !s.pause, s.plan == plan, s.satz == satz else { return nil }
        return Date().timeIntervalSince(s.seit)
    }

    func pauseStarten(session: String, plan: String, satz: Int, ziel: Int) {
        setzen(Stand(session: session, plan: plan, satz: satz, seit: Date(), pause: true, ziel: ziel))
    }

    /// Beendet eine laufende Pause: nach welchem Satz sie lief und wie lang sie war.
    func pauseBeenden() -> (plan: String, satz: Int, sek: Double)? {
        guard let s = stand, s.pause else { return nil }
        setzen(nil)
        return (s.plan, s.satz, Date().timeIntervalSince(s.seit))
    }

    func aus() {
        if stand != nil { setzen(nil) }
        mitteilungLoeschen()
    }

    /// Geht die App in den Hintergrund, meldet iOS das Pausenende: stille Mitteilung, die nur
    /// vibriert (Ahmed, 01.10.: kein Ton). Einmal vorab geplant, kein eigener Timer.
    func mitteilungPlanen() {
        guard let ende = stand?.pauseEnde, ende.timeIntervalSinceNow > 1 else { return }
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Pause vorbei"
        inhalt.body = "Der nächste Satz wartet."
        inhalt.sound = UNNotificationSound(named: UNNotificationSoundName("stille.wav"))
        let ausloeser = UNTimeIntervalNotificationTrigger(timeInterval: ende.timeIntervalSinceNow, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.mitteilungId, content: inhalt, trigger: ausloeser), withCompletionHandler: nil)
    }

    func mitteilungLoeschen() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.mitteilungId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.mitteilungId])
    }
}

/// Die Schritte im Training: Satz starten, abhaken, Pause abschließen. Jeder Schritt sendet höchstens
/// einen Op pro Übung.
@MainActor
enum WorkoutAktion {
    /// Der Satz läuft; eine Pause davor wird an ihren Satz geschrieben. Gibt die neuen Zeilen zurück.
    static func satzStarten(_ session: String, _ u: PlanUebung, _ saetze: [PlanSatz], _ i: Int) -> [PlanSatz] {
        let neu = pauseAbschliessen(session, u, saetze)
        // Auch ohne Pause senden: so beginnt die Übung für den Partner und die Figur.
        TrainingModell.shared.saetzeSenden(session, u, neu)
        WorkoutUhr.shared.satzStarten(session: session, plan: u.id, satz: i)
        return neu
    }

    /// Haken an Satz `i`. Gesetzt: Satzdauer merken (falls er gestartet war) und die Pause starten.
    /// Entfernt: Haken und Zeiten weg. Gibt die neuen Zeilen zurück.
    static func haken(_ session: String, _ u: PlanUebung, _ saetze: [PlanSatz], _ i: Int) -> [PlanSatz] {
        guard saetze.indices.contains(i) else { return saetze }
        let uhr = WorkoutUhr.shared
        var neu = saetze
        if neu[i].ok == true {
            neu[i].ok = nil
            neu[i].sek = nil
            neu[i].pause = nil
            if let s = uhr.stand, s.pause, s.plan == u.id, s.satz == i { uhr.aus() }
        } else {
            let dauer = uhr.satzDauer(plan: u.id, satz: i)
            neu = pauseAbschliessen(session, u, neu)
            neu[i].ok = true
            neu[i].sek = dauer
            uhr.pauseStarten(session: session, plan: u.id, satz: i, ziel: u.pause ?? WorkoutLogik.standardPause)
        }
        TrainingModell.shared.saetzeSenden(session, u, neu)
        return neu
    }

    /// Schreibt die Länge der laufenden Pause an ihren Satz. Gehört er zu `u`, nur in die Zeilen
    /// (der Aufrufer sendet), sonst wird die andere Übung direkt gesendet.
    @discardableResult
    static func pauseAbschliessen(_ session: String, _ u: PlanUebung?, _ saetze: [PlanSatz]) -> [PlanSatz] {
        guard let p = WorkoutUhr.shared.pauseBeenden() else { return saetze }
        if let u, p.plan == u.id {
            var neu = saetze
            if neu.indices.contains(p.satz) { neu[p.satz].pause = p.sek }
            return neu
        }
        let modell = TrainingModell.shared
        if let andere = modell.workout(session).first(where: { $0.id == p.plan }), andere.saetze.indices.contains(p.satz) {
            var zeilen = andere.saetze
            zeilen[p.satz].pause = p.sek
            modell.saetzeSenden(session, andere.planUebung, zeilen)
        }
        return saetze
    }
}
