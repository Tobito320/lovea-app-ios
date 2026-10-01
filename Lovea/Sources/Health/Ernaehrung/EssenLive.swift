import ActivityKit
import Foundation

/// Reine Berechnung des Live-Activity-Stands aus den heutigen Einträgen und Zielen. Kein ActivityKit
/// hier drin, deshalb ohne Gerät testbar.
enum EssenLiveLogik {
    static func stand(_ eintraege: [EssenEintrag], ziele: ErnaehrungsZiele, tag: String) -> EssenAktivitaet.ContentState {
        let summe = ErnaehrungLogik.summe(eintraege)
        // Reihenfolge fest wie `Mahlzeit.allCases` (fruehstueck, mittag, abend, snack) — muss zu
        // `EssenMahlzeitAnzeige.allCases` im Widget-Ziel passen.
        let mahlzeitenKcal = Mahlzeit.allCases.map { m in
            Int(ErnaehrungLogik.summe(eintraege.filter { $0.mahlzeit == m }).kcal.rounded())
        }
        return EssenAktivitaet.ContentState(
            kcal: Int(summe.kcal.rounded()), kcalZiel: ziele.kcal,
            proteinG: Int(summe.protein.rounded()), proteinZiel: ziele.protein,
            kohlenhydrateG: Int(summe.kohlenhydrate.rounded()), kohlenhydrateZiel: ziele.kohlenhydrate,
            fettG: Int(summe.fett.rounded()), fettZiel: ziele.fett,
            mahlzeitenKcal: mahlzeitenKcal, tag: tag)
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
        // R10 (Ahmed, 01.10.: "nur Gym, wenn gestartet" in der Dynamic Island) — läuft ein Training,
        // darf Essen gar nicht erst anfordern, sonst teilt iOS die Insel zwischen beiden auf.
        let gymLaeuft = !Activity<GymAktivitaet>.activities.isEmpty
        let vorher = letzter
        letzter = Task {
            await vorher?.value
            await anwenden(ziel, an: an, gymLaeuft: gymLaeuft)
        }
    }

    /// Gym läuft -> beenden (geht vor allem anderen). Sonst: Schalter aus -> beenden. Läuft schon eine
    /// für `heute`, mit Mahlzeitendaten -> aktualisieren. Läuft keine, eine vom Vortag, oder eine
    /// veraltete (altes Format, siehe `istVeraltet`) -> (die alte beenden und) neu starten.
    nonisolated static func aktion(laufendTag: String?, heute: String, an: Bool, laufendVeraltet: Bool = false, gymLaeuft: Bool = false) -> Aktion {
        guard !gymLaeuft else { return .beenden }
        guard an else { return .beenden }
        if laufendVeraltet { return .neuStarten }
        return laufendTag == heute ? .aktualisieren : .neuStarten
    }

    /// R8 (Review, Critical): eine von einer älteren App-Version gestartete Aktivität erkennen, statt
    /// sie mit `update()` einfach weiterlaufen zu lassen. `ContentState.init(from:)` füllt ein
    /// fehlendes `mahlzeitenKcal` mit `[0, 0, 0, 0]` — läuft trotzdem schon kcal > 0, kann das Feld
    /// nur fehlen, nicht wirklich leer sein (eine nagelneue, echte Aktivität startet ohnehin frisch
    /// über `neuStarten`, landet also nie hier mit kcal > 0 und leeren Mahlzeiten).
    nonisolated static func istVeraltet(_ s: EssenAktivitaet.ContentState) -> Bool {
        s.kcal > 0 && s.mahlzeitenKcal == [0, 0, 0, 0]
    }

    private nonisolated static func anwenden(_ ziel: Ziel, an: Bool, gymLaeuft: Bool) async {
        let laufend = Activity<EssenAktivitaet>.activities.first
        let mitternacht = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(86400)
        let veraltet = laufend.map { istVeraltet($0.content.state) } ?? false
        switch aktion(laufendTag: laufend?.content.state.tag, heute: ziel.stand.tag, an: an, laufendVeraltet: veraltet, gymLaeuft: gymLaeuft) {
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
