import Foundation
import Observation

// Health-Coach: Zustand des Chats und der Lader für die Regel-Karten.
//
// Akku: Nichts davon läuft beim App-Start. `CoachModell.shared` wird erst angefasst, wenn der Chat aufgeht, und
// hängt sich auch erst dort an den Op-Strom (`oeffnen`). Kein Timer, Netz nur in `frage`. Die Kachel in Heute liest
// nur schon geladene Modelle (`CoachDaten`).

/// Schlüssel an einer Stelle, damit Kachel, Chat und Modell dieselben nehmen.
enum CoachSchluessel {
    /// Pause gilt pro Gerät (`@AppStorage`).
    static let pause = "lovea.coach.pausiert"
    /// Einstellung (`einstellung.setzen`), Wert "1" oder "0"; der Server schreibt nur bei "1" morgens von allein.
    static let morgen = "coach.morgen"
    static func ausgeblendet(_ person: Person) -> String { "lovea.coach.ausgeblendetBis.\(person.rawValue)" }
}

private struct CoachFrageBody: Encodable { let text: String }
private struct CoachAntwortBody: Decodable { let text: String }

@MainActor @Observable
final class CoachModell {
    static let shared = CoachModell()

    /// So lang darf eine Frage sein. Das Limit des Servers ist nicht bekannt, die Zahl ist bewusst großzügig.
    static let maxZeichen = 1000
    /// Der Server wartet beim Modell bis zu 25 s, dazu etwas Luft.
    static let wartezeit: TimeInterval = 40

    private var ausOps: [String: CoachNachricht] = [:]
    private var lokal: [CoachNachricht] = []
    private var geoeffnet = false

    private(set) var sendet = false
    private(set) var fehler: CoachFehler?
    /// Alles vor diesem Zeitpunkt ist auf diesem Gerät ausgeblendet ("Verlauf ausblenden").
    private(set) var ausgeblendetBis: Date?

    private init() {}

    private var ich: Person { Raum.shared.ich ?? .ahmed }

    /// Sichtbarer Verlauf: Server-Ops plus noch unbestätigte lokale Einträge, ohne den ausgeblendeten Teil.
    var liste: [CoachNachricht] {
        CoachVerlauf.sichtbar(CoachVerlauf.zusammenfuehren(ops: Array(ausOps.values), lokal: lokal), ausgeblendetBis: ausgeblendetBis)
    }

    // MARK: - Öffnen

    /// Erster Aufruf beim Öffnen des Chats: Verlauf aus dem Op-Strom lesen. `beobachten` spielt die Historie ab und
    /// bleibt danach hängen, deshalb genau einmal. Die App sendet `coach.nachricht` nie selbst, es kommt nur vom
    /// Server und nur für den Absender; der Filter auf `von` ist die zweite Sicherung.
    func oeffnen() {
        guard !geoeffnet else { return }
        geoeffnet = true
        let zeitpunkt = UserDefaults.standard.double(forKey: CoachSchluessel.ausgeblendet(ich))
        ausgeblendetBis = zeitpunkt > 0 ? Date(timeIntervalSince1970: zeitpunkt) : nil
        Raum.shared.beobachten(["coach.nachricht"]) { [weak self] op in
            guard let self, op.von == Raum.shared.ich, let nachricht = CoachNachricht.aus(op) else { return }
            // Nach `id` ersetzen: kommt dieselbe Op noch einmal mit `seq`, gilt die neue Fassung.
            self.ausOps[nachricht.id] = nachricht
        }
    }

    // MARK: - Fragen

    /// Schickt die Frage. `nil` = gesendet (oder nichts zu senden), sonst der Fehler; dann steht die Frage nicht im
    /// Verlauf und die Oberfläche kann den Text zurück ins Feld legen.
    @discardableResult
    func frage(_ roh: String) async -> CoachFehler? {
        let text = String(roh.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxZeichen))
        guard !text.isEmpty, !sendet else { return nil }
        oeffnen()
        sendet = true
        fehler = nil
        defer { sendet = false }

        let eigene = CoachNachricht(id: "lokal-\(UUID().uuidString)", rolle: .du, text: text, zeit: Date(), lokal: true)
        lokal.append(eigene)

        let (status, antwort) = await senden(text)
        if let problem = CoachFehler.aus(status: status) {
            lokal.removeAll { $0.id == eigene.id }
            fehler = problem
            return problem
        }
        if let antwort, !antwort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lokal.append(CoachNachricht(id: "lokal-\(UUID().uuidString)", rolle: .coach, text: antwort, zeit: Date(), lokal: true))
        }
        return nil
    }

    /// `POST coach/frage` `{ "text" }` -> `{ "text" }`. Status 0 = keine Antwort (Netz, Zeitlimit, Raum nicht
    /// eingerichtet). Ein Erfolg mit unlesbarem Body zählt als Erfolg ohne Blase; die Antwort kommt dann über die Op.
    private func senden(_ text: String) async -> (status: Int, antwort: String?) {
        guard let konfig = Raum.shared.httpKonfiguration(),
              let body = try? JSONEncoder().encode(CoachFrageBody(text: text)) else { return (0, nil) }
        var anfrage = URLRequest(url: konfig.basis.appendingPathComponent("coach/frage"))
        anfrage.httpMethod = "POST"
        anfrage.timeoutInterval = Self.wartezeit
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { anfrage.setValue(wert, forHTTPHeaderField: feld) }
        anfrage.httpBody = body
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage) else { return (0, nil) }
        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        return (status, try? JSONDecoder().decode(CoachAntwortBody.self, from: daten).text)
    }

    func fehlerLoeschen() { fehler = nil }

    // MARK: - Einstellungen

    /// Morgen-Nachricht: Standard aus, nur auf eigenen Schalter (Plan). Gespeichert als Einstellung der Person.
    var morgenAn: Bool { EinstellungenModell.shared.string(CoachSchluessel.morgen, default: "0") == "1" }

    func morgenSetzen(_ an: Bool) {
        EinstellungenModell.shared.setzen(CoachSchluessel.morgen, .string(an ? "1" : "0"))
    }

    /// Ops lassen sich nicht löschen. Der Verlauf wird deshalb nur auf diesem Gerät ausgeblendet; der Server und
    /// der Coach kennen die letzten Nachrichten weiter.
    func verlaufAusblenden() {
        let jetzt = Date()
        ausgeblendetBis = jetzt
        fehler = nil
        UserDefaults.standard.set(jetzt.timeIntervalSince1970, forKey: CoachSchluessel.ausgeblendet(ich))
    }
}

// MARK: - Daten für die Regel-Karten

/// Baut `CoachEingabe` aus den Modellen. Liest nur, was ohnehin geladen ist (Heute zeigt dieselben Modelle), und
/// rechnet nichts Teures: Essen der letzten 14 Tage, Gewicht, Schritte, Wochensätze, die letzten zwei Einheiten.
enum CoachDaten {
    @MainActor
    static func eingabe(_ ich: Person, heute: String) -> CoachEingabe {
        let essen = ErnaehrungModell.shared, health = HealthModell.shared, training = TrainingModell.shared
        var e = CoachEingabe(heute: heute)

        let ziele = essen.ziele(ich)
        e.geschlecht = ziele.geschlecht
        e.zieleEingerichtet = ziele.eingerichtet
        e.proteinZiel = ziele.protein

        let tageMitEssen = essen.tage(ich)
        for zurueck in 1...CoachRegeln.fensterTage {
            let tag = Datum.addTage(heute, -zurueck)
            guard tageMitEssen.contains(tag) else { continue }
            let summe = essen.summe(ich, tag)
            e.essenKcal[tag] = summe.kcal
            e.essenProtein[tag] = summe.protein
        }

        e.gewicht = health.habitWerte(Habit.gewicht.id, ich)
        e.schritte = health.schritteWerte(ich)
        e.schrittZiel = health.zielSchritte(ich)

        let sessions = training.sessions(ich)
        let koerperZiele = KoerperZiele.lesen(person: ich, wert: { health.ziel($0, ich) })
        let woche = MuskelLogik.wochenSaetze(sessions, woche: heute)
        let faellig = KoerperLogik.faellig(prio: koerperZiele.prio, ziele: koerperZiele, woche: woche)
        e.gruppen = koerperZiele.reihenfolge.compactMap { gruppe -> CoachGruppe? in
            guard let ziel = koerperZiele.saetze[gruppe], ziel > 0 else { return nil }
            let gemacht = MuskelTeil.allCases.filter { $0.gruppe == gruppe }.reduce(0.0) { $0 + (woche[$1] ?? 0) }
            return CoachGruppe(name: gruppe.name, saetze: gemacht, ziel: ziel, faellig: faellig.contains(gruppe))
        }

        // Sessions sind neueste zuerst: je Übung zählt der neueste Lauf der letzten zwei Einheiten.
        var gesehen: Set<String> = []
        for session in sessions.prefix(2) {
            for lauf in session.laeufe where lauf.fertig {
                guard let uebung = UebungsKatalog.nachId[lauf.uebung], !uebung.istCardio, gesehen.insert(uebung.id).inserted,
                      let saetze = lauf.saetze, let vorschlag = KoerperLogik.naechstesMal(saetze) else { continue }
                e.uebungen.append(CoachUebung(name: uebung.name, vorschlag: vorschlag))
            }
        }
        return e
    }
}
