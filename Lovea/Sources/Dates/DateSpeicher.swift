import Foundation
import Observation

/// Faltet die Ops `dates.idee` (ganzes Objekt, last-writer-wins nach `geaendert`) in einen Stand, der auf
/// beiden Handys gleich ist. Gespeichert wird wie bei Kalender und Treffen im Op-Log (`OpLog`,
/// `Warteschlange`): `Raum.beobachtenStapel` spielt beim Start alles wieder ein.
@MainActor @Observable
final class DateSpeicher {
    static let shared = DateSpeicher()

    nonisolated static let art = "dates.idee"

    struct Zustand: Sendable, Equatable {
        /// Auch gelöschte (Flag), sonst käme eine gelöschte Startidee zurück.
        var ideen: [String: DateIdee] = [:]
        var sichtbar: [DateIdee] { ideen.values.filter { !$0.geloescht } }
    }

    private(set) var zustand = Zustand()

    var ideen: [DateIdee] { DateLogik.sortiert(zustand.sichtbar) }

    @ObservationIgnored private let ich: () -> Person?
    @ObservationIgnored private let senden: (Op) -> Void
    @ObservationIgnored private let jetzt: () -> Date
    @ObservationIgnored private let merker: UserDefaults

    /// Ohne `Raum`-Anbindung für Tests; `shared` hängt sich an den Raum.
    init(
        ich: @escaping () -> Person?, senden: @escaping (Op) -> Void, jetzt: @escaping () -> Date = Date.init,
        merker: UserDefaults = .standard
    ) {
        self.ich = ich
        self.senden = senden
        self.jetzt = jetzt
        self.merker = merker
    }

    private convenience init() {
        self.init(ich: { Raum.shared.ich }, senden: { Raum.shared.einreihen($0) })
        Raum.shared.beobachtenStapel([Self.art]) { [weak self] ops in self?.einarbeiten(ops) }
        startdatenFallsNoetig()
    }

    // MARK: - Faltung (testbar ohne Raum)

    /// Reihenfolgefrei bis auf gleiche Zeitstempel; doppelte Zustellung (Op und Echo) ändert nichts.
    nonisolated static func anwenden(_ ops: [Op], auf start: Zustand = Zustand()) -> Zustand {
        var z = start
        for op in ops where op.art == art {
            if let idee = op.daten(DateIdee.self) { DateLogik.zusammenfuehren(&z.ideen, idee) }
        }
        return z
    }

    func einarbeiten(_ ops: [Op]) {
        zustand = Self.anwenden(ops, auf: zustand)
    }

    // MARK: - Ändern

    /// Legt eine neue Idee an. Leerer Titel: nil.
    @discardableResult
    func anlegen(titel: String, kategorie: DateKategorie, ort: PunktOrt? = nil, links: [DateLink] = [], notiz: String? = nil) -> DateIdee? {
        let name = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let ich = ich() else { return nil }
        let text = notiz?.trimmingCharacters(in: .whitespacesAndNewlines)
        let idee = DateIdee(
            id: "idee-" + UUID().uuidString, titel: name, kategorie: kategorie, ort: ort, links: links,
            notiz: (text?.isEmpty ?? true) ? nil : text, geaendert: jetzt(), von: ich
        )
        uebernehmen(idee)
        return idee
    }

    func aendern(_ id: String, _ aenderung: (inout DateIdee) -> Void) {
        guard let alt = zustand.ideen[id], let ich = ich() else { return }
        uebernehmen(DateLogik.geaendert(alt, von: ich, jetzt: jetzt(), aenderung))
    }

    func abhaken(_ id: String, erledigt: Bool) {
        guard let alt = zustand.ideen[id], alt.erledigt != erledigt, let ich = ich() else { return }
        uebernehmen(DateLogik.abgehakt(alt, erledigt: erledigt, von: ich, jetzt: jetzt(), heute: Datum.text(jetzt())))
    }

    func loeschen(_ id: String) {
        guard let alt = zustand.ideen[id], !alt.geloescht, let ich = ich() else { return }
        uebernehmen(DateLogik.geloescht(alt, von: ich, jetzt: jetzt()))
    }

    /// Undo-Leiste: Flag zurück, mit neuem Zeitstempel, damit es auch gegen die Löschung beim Partner gewinnt.
    func rueckgaengig(_ id: String) {
        guard let alt = zustand.ideen[id], alt.geloescht, let ich = ich() else { return }
        uebernehmen(DateLogik.wiederhergestellt(alt, von: ich, jetzt: jetzt()))
    }

    /// Sofort lokal anwenden (die Ansicht reagiert ohne Warten), dann senden. Das Echo ändert nichts mehr.
    private func uebernehmen(_ idee: DateIdee) {
        guard let ich = ich() else { return }
        DateLogik.zusammenfuehren(&zustand.ideen, idee)
        senden(Op.neu(Self.art, idee, von: ich))
    }

    // MARK: - Startdaten

    /// Einmal je Gerät, erst nach dem ersten vollständigen Nachholen, sonst sähe ein neues Handy einen leeren Log.
    /// Senden zwei Geräte, sind IDs und Zeitstempel gleich: kein Duplikat.
    private func startdatenFallsNoetig() {
        Task { @MainActor [weak self] in
            guard Raum.shared.eingerichtet else { return }
            while !Raum.shared.nachgeholt {
                try? await Task.sleep(for: .seconds(1))
            }
            await Raum.shared.leer()
            self?.startdatenSenden()
        }
    }

    func startdatenSenden() {
        guard !merker.bool(forKey: DateStartdaten.schluessel), let ich = ich() else { return }
        merker.set(true, forKey: DateStartdaten.schluessel)
        for idee in DateStartdaten.fehlende(in: zustand.ideen) {
            DateLogik.zusammenfuehren(&zustand.ideen, idee)
            senden(Op.neu(Self.art, idee, von: ich))
        }
    }
}
