import Foundation
import Observation

/// Sammelt aus den schon gesyncten Ops den Tag einer Person ("Ahmeds Tag"): Schlaf, Schritte, Gym,
/// Herzen. Fotos und Snaps kommen beim Lesen aus dem Chat. Kein eigener Op-Typ, kein Timer, kein
/// Netzwerk: der Raum spielt den Op-Verlauf beim Registrieren ab, danach kommen nur neue Ops.
/// Eigene Ops kommen doppelt an (optimistisch, dann bestätigt): alles hier ist über die Op-ID idempotent.
@MainActor @Observable
final class TagModell {
    static let shared = TagModell()

    /// Rohwerte je Person, nach Op-ID. Nur die letzten Tage (`behaltenTage`).
    private(set) var roh: [Person: [String: TagRoh]] = [:]
    private(set) var geloeschteSessions: Set<String> = []
    /// Letzte Übung, an der die Person gearbeitet hat ("im Gym · Bankdrücken").
    private(set) var aktuelleUebung: [Person: (name: String, zeit: Date)] = [:]

    private static let behaltenTage = 3

    private init() {
        Raum.shared.beobachten(
            ["schritte.setzen", "schlaf.setzen", "gym.checkin", "gym.uebung", "gym.checkout", "gym.loeschen", "geste"]
        ) { [weak self] op in self?.aufnehmen(op) }
    }

    // MARK: - Lesen

    /// Zeitleiste für `person` an dem Berliner Kalendertag von `tag`, aus Sicht der Person, die schaut.
    func ansicht(person: Person, tag: Date) -> TagAnsicht {
        let schauer = Raum.shared.ich ?? person.partner
        let ausOps = (roh[person] ?? [:]).values.filter { r in
            guard let session = Self.session(von: r.art) else { return true }
            return !geloeschteSessions.contains(session)
        }
        return TagLogik.zeitleiste(Array(ausOps) + chatRoh(person: person, tag: tag), tag: tag, ansicht: schauer, person: person)
    }

    /// Letzter Moment von heute als kurzer Text mit Uhrzeit, `nil` ohne Momente (Widget, Karte).
    func letzterMoment(person: Person, jetzt: Date = Date()) -> String? {
        guard let m = ansicht(person: person, tag: jetzt).momente.last else { return nil }
        return "\(Self.uhrzeit(m.zeit)) \(m.text)"
    }

    /// Status in Worten: "im Gym · Bankdrücken", "bei der Arbeit", "schläft".
    func statusText(person: Person, jetzt: Date = Date()) -> String {
        let haupt = FigurenModell.shared.anzeige(person).haupt
        var text = haupt.titel
        if haupt == .gym, let u = aktuelleUebung[person], jetzt.timeIntervalSince(u.zeit) < 90 * 60 { text += " · \(u.name)" }
        return text
    }

    /// Was die Person gerade hört, nur wenn der Stand schon geladen ist. Ruft nie `schauen()` auf
    /// (kein neues Netzwerk, kein Polling nur für diese Ansicht).
    func hoertGerade(person: Person) -> String? {
        guard person == (Raum.shared.ich ?? person.partner).partner,
              let song = SpotifyModell.shared.partner, song.gueltig else { return nil }
        let titel = (song.titel ?? "").isEmpty ? nil : song.titel
        let kuenstler = (song.kuenstler ?? "").isEmpty ? nil : song.kuenstler
        switch (titel, kuenstler) {
        case let (t?, k?): return "\(t) · \(k)"
        case let (t?, nil): return t
        case let (nil, k?): return k
        default: return "hört Musik"
        }
    }

    static func uhrzeit(_ datum: Date) -> String {
        let teile = Calendar.berlin.dateComponents([.hour, .minute], from: datum)
        return String(format: "%02d:%02d", teile.hour ?? 0, teile.minute ?? 0)
    }

    // MARK: - Chat: Fotos und Snaps

    private func chatRoh(person: Person, tag: Date) -> [TagRoh] {
        let start = Calendar.berlin.startOfDay(for: tag)
        guard let ende = Calendar.berlin.date(byAdding: .day, value: 1, to: start) else { return [] }
        var liste: [TagRoh] = []
        // Neueste zuerst; eine Stunde Luft, weil die Liste nicht streng nach Zeit sortiert sein muss.
        for n in ChatModell.shared.nachrichten.reversed() {
            if n.zeit < start.addingTimeInterval(-3600) { break }
            guard n.von == person, n.zeit >= start, n.zeit < ende, !n.geloescht, n.system == nil else { continue }
            if n.snap != nil {
                liste.append(TagRoh(id: "snap-\(n.id)", zeit: n.zeit, art: .snap))
            } else if let m = n.medien.first(where: { $0.typ == "foto" }) {
                liste.append(TagRoh(id: "foto-\(n.id)", zeit: n.zeit, art: .foto(medienId: m.id)))
            }
        }
        return liste
    }

    // MARK: - Ops

    private struct SchritteRoh: Decodable { let datum: String; let anzahl: Int; let nachgetragen: Bool? }
    private struct SchlafRoh: Decodable { let datum: String; let minuten: Int; let von: String; let bis: String }
    private struct GesteRoh: Decodable { let art: String }

    private func aufnehmen(_ op: Op) {
        switch op.art {
        case "schritte.setzen":
            // Nur der Stand von heute, den das Handy selbst meldet (kein Nachtragen für alte Tage).
            guard let d = op.daten(SchritteRoh.self), d.nachgetragen != true, d.datum == Datum.text(op.zeit) else { return }
            ablegen(TagRoh(id: op.id, zeit: op.zeit, art: .schritte(anzahl: d.anzahl)), von: op.von)
        case "schlaf.setzen":
            guard let d = op.daten(SchlafRoh.self), let von = Self.iso(d.von), let bis = Self.iso(d.bis), bis > von else { return }
            ablegen(TagRoh(id: op.id, zeit: bis, art: .schlaf(von: von, bis: bis, minuten: d.minuten)), von: op.von)
        case "gym.checkin":
            guard let d = op.daten(GymD.self), let start = d.start else { return }
            ablegen(TagRoh(id: op.id, zeit: start, art: .gymStart(session: d.session)), von: op.von)
        case "gym.uebung":
            guard let d = op.daten(GymD.self) else { return }
            let kandidat = Self.uebungsName(d)
            if let name = kandidat, ["start", "satz", "fertig"].contains(d.status ?? ""), op.zeit >= (aktuelleUebung[op.von]?.zeit ?? .distantPast) {
                aktuelleUebung[op.von] = (name, op.zeit)
            }
            guard Self.uebungZaehlt(d), let name = kandidat else { return }
            ablegen(TagRoh(id: op.id, zeit: op.zeit, art: .gymUebung(session: d.session, name: name)), von: op.von)
        case "gym.checkout":
            // Nur das echte Beenden; reine Zeitkorrekturen tragen weder Dauer noch Sätze.
            guard let d = op.daten(GymD.self), d.status == "ende" else { return }
            ablegen(TagRoh(id: op.id, zeit: d.ende ?? op.zeit, art: .gymEnde(session: d.session, minuten: d.minuten, saetze: d.zahl)), von: op.von)
        case "gym.loeschen":
            if let d = op.daten(GymD.self) { geloeschteSessions.insert(d.session) }
        case "geste":
            guard op.daten(GesteRoh.self)?.art == "herz" else { return }
            ablegen(TagRoh(id: op.id, zeit: op.zeit, art: .herz), von: op.von)
        default:
            break
        }
    }

    private func ablegen(_ eintrag: TagRoh, von person: Person) {
        let grenze = Calendar.berlin.startOfDay(for: Date()).addingTimeInterval(-Double(Self.behaltenTage) * 86_400)
        guard eintrag.zeit >= grenze, roh[person]?[eintrag.id] != eintrag else { return }
        roh[person, default: [:]][eintrag.id] = eintrag
        // Selten aufräumen: nur wenn die App Tage lang lief und viel zusammenkam.
        if (roh[person]?.count ?? 0) > 600 { roh[person] = roh[person]?.filter { $0.value.zeit >= grenze } }
    }

    private static func uebungZaehlt(_ d: GymD) -> Bool {
        if d.status == "fertig" { return true }
        return d.status == "satz" && (d.saetze?.contains { $0.ok == true } ?? false)
    }

    private static func uebungsName(_ d: GymD) -> String? {
        if let name = d.name, !name.isEmpty { return name }
        guard let id = d.uebung else { return nil }
        return UebungsKatalog.nachId[id]?.name
    }

    private static func session(von art: TagRoh.Art) -> String? {
        switch art {
        case let .gymStart(session), let .gymUebung(session, _), let .gymEnde(session, _, _): return session
        default: return nil
        }
    }

    // Frischer Formatter je Aufruf: ISO8601DateFormatter ist keine Sendable-Klasse (wie in HealthModell).
    private static func iso(_ text: String) -> Date? {
        let fraktional = ISO8601DateFormatter()
        fraktional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let datum = fraktional.date(from: text) { return datum }
        return ISO8601DateFormatter().date(from: text)
    }
}
