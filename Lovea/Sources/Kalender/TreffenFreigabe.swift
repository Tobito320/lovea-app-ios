import Foundation
import UIKit
import UserNotifications

extension TreffenSendung {
    @MainActor func senden() {
        switch self {
        case .setzen(let d): Raum.shared.senden(art, d)
        case .platzhalter(let d): Raum.shared.senden(art, d)
        case .loeschen(let d): Raum.shared.senden(art, d)
        case .geheim(let d): Raum.shared.senden(art, d)
        }
    }
}

/// Gibt versteckte Punkte zur Zeit `sichtbarAb` frei: Der Server kann das nicht, also sendet ein Gerät des
/// Erstellers den vollen Inhalt als öffentliche Op. Kein Polling, kein Hintergrundmodus. Geprüft wird,
/// wenn die App aktiv wird, nach Ops (läuft auch beim stillen Push-Wecken), und ein einziger
/// Schlaf-Timer bis zur nächsten Fälligkeit. Dazu eine lokale Erinnerung je Überraschung.
@MainActor
final class TreffenFreigabe {
    static let shared = TreffenFreigabe()

    private var gestartet = false
    private var schlaf: Task<Void, Never>?
    /// Schon gesendete Freigaben, bis das Echo im Zustand ankommt (kein Doppelsenden).
    private var gesendet: Set<String> = []
    private var geplant: [String: Date] = [:]

    private init() {}

    private static func erinnerungId(_ id: String) -> String { "treffen.freigabe.\(id)" }

    func starten() {
        guard !gestartet else { return }
        gestartet = true
        _ = TreffenGeheimModell.shared // vor dem Beobachter unten, damit er zuerst faltet
        Raum.shared.beobachtenStapel(["nachricht.neu", "entwurf.setzen"]) { [weak self] _ in self?.pruefen() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in TreffenFreigabe.shared.pruefen() }
        }
        // Einmal nach dem ersten Nachholen: vorher fehlt der öffentliche Stand, und eine alte Fassung
        // würde nach einer Änderung noch einmal veröffentlicht.
        Task { @MainActor [weak self] in
            for _ in 0..<30 {
                if Raum.shared.nachgeholt { break }
                try? await Task.sleep(for: .seconds(1))
            }
            self?.pruefen()
        }
    }

    func pruefen() {
        guard Raum.shared.ich != nil else { return }
        let jetzt = Date()
        let geheim = Array(TreffenGeheimModell.shared.punkte.values)
        let zustand = KalenderModell.shared.zustand
        let oeffentlich = zustand.punkte.values.flatMap { $0 }
        let geloescht = zustand.geloeschtePunkte

        if Raum.shared.nachgeholt {
            let faellig = TreffenLogik.faelligeFreigaben(geheim: geheim, oeffentlich: oeffentlich, geloescht: geloescht, jetzt: jetzt)
            for g in faellig where gesendet.insert(g.id).inserted {
                TreffenOps.freigeben(g).senden()
                erinnerungEntfernen(g.id)
            }
        }

        let offene = TreffenLogik.offene(geheim, oeffentlich, geloescht)
        let offeneIds = Set(offene.map(\.id))
        for g in geheim where !offeneIds.contains(g.id) { erinnerungEntfernen(g.id) }
        for g in offene where g.sichtbarAb > jetzt { erinnerungPlanen(g, jetzt: jetzt) }

        schlaf?.cancel()
        schlaf = nil
        guard let naechste = TreffenLogik.naechsteFaelligkeit(geheim: geheim, oeffentlich: oeffentlich, geloescht: geloescht, jetzt: jetzt) else { return }
        let dauer = max(1, naechste.timeIntervalSince(jetzt)) + 0.5
        schlaf = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(dauer))
            guard !Task.isCancelled else { return }
            self?.pruefen()
        }
    }

    /// „Jetzt freigeben" und die Prüfung teilen sich den Weg.
    func freigeben(_ g: GeheimPunkt) {
        guard !g.geloescht, gesendet.insert(g.id).inserted else { return }
        TreffenOps.freigeben(g).senden()
        erinnerungEntfernen(g.id)
    }

    private func erinnerungPlanen(_ g: GeheimPunkt, jetzt: Date) {
        guard geplant[g.id] != g.sichtbarAb else { return }
        geplant[g.id] = g.sichtbarAb
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Deine Überraschung wird sichtbar"
        inhalt.body = "Lovea kurz öffnen."
        let ausloeser = UNTimeIntervalNotificationTrigger(timeInterval: max(1, g.sichtbarAb.timeIntervalSince(jetzt)), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.erinnerungId(g.id), content: inhalt, trigger: ausloeser), withCompletionHandler: nil)
    }

    func erinnerungEntfernen(_ id: String) {
        geplant[id] = nil
        let kennung = [Self.erinnerungId(id)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: kennung)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: kennung)
    }
}

/// Der Weg der Ansicht zu den Ops. Der Inhalt eines versteckten Punkts geht nie öffentlich raus
/// (`TreffenOps`); die Prüfung startet, wenn das Echo der eigenen Ops ankommt.
@MainActor
enum TreffenPunktSender {
    static func speichern(_ p: PunktEntwurf) {
        let id = p.id ?? UUID().uuidString
        let schon = KalenderModell.shared.zustand.punkte.values.contains { liste in liste.contains { $0.id == id && $0.hatInhalt } }
        for sendung in TreffenOps.speichern(p, id: id, jetzt: Date(), schonOeffentlich: schon) { sendung.senden() }
    }

    static func loeschen(datum: String, id: String) {
        for sendung in TreffenOps.loeschen(datum: datum, id: id, geheim: TreffenGeheimModell.shared.punkte[id]) { sendung.senden() }
        TreffenFreigabe.shared.erinnerungEntfernen(id)
    }

    static func jetztFreigeben(id: String) {
        guard let g = TreffenGeheimModell.shared.punkte[id] else { return }
        TreffenFreigabe.shared.freigeben(g)
    }
}

/// Die Punkte eines Tages für die Ansicht: eigene Platzhalter mit Inhalt gefüllt, nach Zeit sortiert.
/// `jetzt` ist für Aufrufer, die ihre Ansicht mit `TreffenLogik.ansicht` entscheiden; hier wird nichts nach Uhr versteckt.
@MainActor
func treffenPunkte(datum: String, ich: Person, jetzt: Date) -> [TreffenPunkt] {
    let oeffentlich = KalenderModell.shared.zustand.punkte[datum] ?? []
    return TreffenLogik.sortiert(TreffenLogik.zusammengefuehrt(oeffentlich: oeffentlich, geheim: TreffenGeheimModell.shared.punkte, ich: ich))
}
