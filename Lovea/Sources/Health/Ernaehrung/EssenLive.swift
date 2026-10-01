import ActivityKit
import Foundation

/// Reine Berechnung des Live-Activity-Stands aus den heutigen Einträgen und Zielen. Kein ActivityKit
/// hier drin, deshalb ohne Gerät testbar.
enum EssenLiveLogik {
    static func stand(_ eintraege: [EssenEintrag], ziele: ErnaehrungsZiele) -> EssenAktivitaet.ContentState {
        let summe = ErnaehrungLogik.summe(eintraege)
        return EssenAktivitaet.ContentState(
            kcal: Int(summe.kcal.rounded()), kcalZiel: ziele.kcal,
            proteinG: Int(summe.protein.rounded()), proteinZiel: ziele.protein,
            kohlenhydrateG: Int(summe.kohlenhydrate.rounded()), kohlenhydrateZiel: ziele.kohlenhydrate,
            fettG: Int(summe.fett.rounded()), fettZiel: ziele.fett)
    }
}

/// Opt-in-Schalter für die Essen-Live-Activity (Ahmed, 01.10.): einmaliger Vorschlag in der
/// Ernährung-Ansicht, dazu ein Schalter in "Tagebuch anpassen". Beides nur in UserDefaults, kein Sync.
enum EssenLiveEinstellungen {
    private static let anSchluessel = "essen.liveAktivitaet.an"
    private static let vorschlagSchluessel = "essen.liveAktivitaet.vorschlagGezeigt"

    static var an: Bool {
        get { UserDefaults.standard.bool(forKey: anSchluessel) }
        set {
            UserDefaults.standard.set(newValue, forKey: anSchluessel)
            EssenLive.abgleichen()
        }
    }

    /// Noch nie "Anzeigen" oder "Nein danke" gewählt.
    static var vorschlagZeigen: Bool { !UserDefaults.standard.bool(forKey: vorschlagSchluessel) }

    static func vorschlagEntschieden(an: Bool) {
        UserDefaults.standard.set(true, forKey: vorschlagSchluessel)
        Self.an = an
    }
}

/// Hält die Live Activity passend zum heutigen Tagebuch (Ahmed, 01.10.): aktualisiert nur, wenn der
/// Nutzer selbst etwas einträgt, ändert oder löscht, und wenn die App aktiv wird. Kein Timer, keine
/// Hintergrund-Aktualisierung, kein Push — Akku-Kosten damit vernachlässigbar. Höchstens eine Aktivität.
@MainActor
enum EssenLive {
    private struct Ziel: Sendable {
        var attribute: EssenAktivitaet
        var stand: EssenAktivitaet.ContentState
    }

    /// Abgleiche laufen nacheinander, wie bei `GymLive`.
    private static var letzter: Task<Void, Never>?

    static func abgleichen() {
        let modell = ErnaehrungModell.shared
        let ich = modell.ich
        guard EssenLiveEinstellungen.an else {
            letzter = Task { await beenden() }
            return
        }
        let heute = Datum.text(Date())
        let ziel = Ziel(
            attribute: EssenAktivitaet(name: ich.name),
            stand: EssenLiveLogik.stand(modell.eintraege(ich, heute), ziele: modell.ziele(ich, tag: heute)))
        let vorher = letzter
        letzter = Task {
            await vorher?.value
            await anwenden(ziel)
        }
    }

    private nonisolated static func beenden() async {
        for a in Activity<EssenAktivitaet>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }

    /// Ein Tag ist um Mitternacht vorbei: `staleDate` lässt das System sie als veraltet markieren,
    /// der nächste Abgleich (nächster App-Start) rechnet ohnehin neu vom aktuellen Tag aus.
    private nonisolated static func anwenden(_ ziel: Ziel) async {
        let mitternacht = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(86400)
        if let a = Activity<EssenAktivitaet>.activities.first {
            if a.content.state != ziel.stand { await a.update(ActivityContent(state: ziel.stand, staleDate: mitternacht)) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // Klappt nur im Vordergrund; sonst holt der nächste Abgleich beim Öffnen es nach.
            _ = try? Activity.request(attributes: ziel.attribute, content: ActivityContent(state: ziel.stand, staleDate: mitternacht))
        }
    }
}
