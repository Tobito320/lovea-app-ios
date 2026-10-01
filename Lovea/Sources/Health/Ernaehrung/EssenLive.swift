import ActivityKit
import Foundation

/// Reine Berechnung des Live-Activity-Stands aus den heutigen Einträgen und Zielen. Kein ActivityKit
/// hier drin, deshalb ohne Gerät testbar.
enum EssenLiveLogik {
    static func stand(_ eintraege: [EssenEintrag], ziele: ErnaehrungsZiele, tag: String) -> EssenAktivitaet.ContentState {
        let summe = ErnaehrungLogik.summe(eintraege)
        return EssenAktivitaet.ContentState(
            kcal: Int(summe.kcal.rounded()), kcalZiel: ziele.kcal,
            proteinG: Int(summe.protein.rounded()), proteinZiel: ziele.protein,
            kohlenhydrateG: Int(summe.kohlenhydrate.rounded()), kohlenhydrateZiel: ziele.kohlenhydrate,
            fettG: Int(summe.fett.rounded()), fettZiel: ziele.fett, tag: tag)
    }
}

/// Opt-in-Schalter für die Essen-Live-Activity (Ahmed, 01.10.): einmaliger Vorschlag in der
/// Ernährung-Ansicht, dazu ein Schalter in "Tagebuch anpassen". Beides nur in UserDefaults, kein Sync.
/// Nur schreiben/lesen, nie selbst `EssenLive.abgleichen()` auslösen (das macht der MainActor-Aufrufer,
/// sonst Swift-6-Isolationsfehler: dieser Typ ist absichtlich nicht an den MainActor gebunden).
enum EssenLiveEinstellungen {
    private static let anSchluessel = "essen.liveAktivitaet.an"
    private static let vorschlagSchluessel = "essen.liveAktivitaet.vorschlagGezeigt"

    static var an: Bool {
        get { UserDefaults.standard.bool(forKey: anSchluessel) }
        set { UserDefaults.standard.set(newValue, forKey: anSchluessel) }
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
    /// Was mit der laufenden Aktivität passieren soll. Reine Entscheidung ohne ActivityKit, testbar.
    enum Aktion: Equatable { case aktualisieren, neuStarten, beenden }

    private struct Ziel: Sendable {
        var attribute: EssenAktivitaet
        var stand: EssenAktivitaet.ContentState
    }

    /// Abgleiche laufen nacheinander, wie bei `GymLive`.
    private static var letzter: Task<Void, Never>?

    static func abgleichen() {
        let modell = ErnaehrungModell.shared
        let ich = modell.ich
        let heute = Datum.text(Date())
        let ziel = Ziel(
            attribute: EssenAktivitaet(name: ich.name),
            stand: EssenLiveLogik.stand(modell.eintraege(ich, heute), ziele: modell.ziele(ich, tag: heute), tag: heute))
        let an = EssenLiveEinstellungen.an
        let vorher = letzter
        letzter = Task {
            await vorher?.value
            await anwenden(ziel, an: an)
        }
    }

    /// Schalter aus -> beenden. Läuft schon eine für `heute` -> aktualisieren. Läuft keine oder eine
    /// vom Vortag -> (die alte beenden und) neu starten.
    nonisolated static func aktion(laufendTag: String?, heute: String, an: Bool) -> Aktion {
        guard an else { return .beenden }
        return laufendTag == heute ? .aktualisieren : .neuStarten
    }

    private nonisolated static func anwenden(_ ziel: Ziel, an: Bool) async {
        let laufend = Activity<EssenAktivitaet>.activities.first
        let mitternacht = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(86400)
        switch aktion(laufendTag: laufend?.content.state.tag, heute: ziel.stand.tag, an: an) {
        case .beenden:
            for a in Activity<EssenAktivitaet>.activities { await a.end(nil, dismissalPolicy: .immediate) }
        case .neuStarten:
            // Vom Vortag übrig (oder keine da): sauber beenden statt mit neuen Werten überschreiben,
            // dann frisch für heute anfordern.
            for a in Activity<EssenAktivitaet>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            // Klappt nur im Vordergrund; sonst holt der nächste Abgleich beim Öffnen es nach.
            _ = try? Activity.request(attributes: ziel.attribute, content: ActivityContent(state: ziel.stand, staleDate: mitternacht))
        case .aktualisieren:
            guard let laufend, laufend.content.state != ziel.stand else { return }
            await laufend.update(ActivityContent(state: ziel.stand, staleDate: mitternacht))
        }
    }
}
