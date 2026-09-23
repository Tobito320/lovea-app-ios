import Foundation

/// Z-26.4: the Runde-1 move imported old drawings straight into the chat (`umzug:zeichnung/…`
/// message ids, `server/umzug.mjs`'s `zeichnung/` case — one `nachricht.neu` with a single `foto`
/// medium per drawing, `von` is who drew it). This moves each of those, once per person, into that
/// person's own drawing library (`ArtworkLibrary`, reusing `ChatGalerie`'s "In Galerie speichern"
/// shape) and then deletes it from the chat. `umzug.aufraeumen {}` marks a person done so a later
/// launch never rescans (`ChatModell.arten` folds it; the check lives here as `aufgeraeumt`).
enum UmzugMigrationLogik {
    /// Pure selection (testable without `Raum`/`ChatModell`): this person's own, not-yet-deleted
    /// `umzug:zeichnung/…` messages.
    static func auszuraeumen(_ nachrichten: [ChatModell.Nachricht], ich: Person) -> [ChatModell.Nachricht] {
        nachrichten.filter { $0.von == ich && !$0.geloescht && $0.id.hasPrefix("umzug:zeichnung/") }
    }
}

@MainActor
final class UmzugAufraeumen {
    static let shared = UmzugAufraeumen()

    private var aufgeraeumt: Set<Person> = []
    private var laeuft = false

    private init() {
        Raum.shared.beobachten(["umzug.aufraeumen"]) { [weak self] op in
            self?.aufgeraeumt.insert(op.von)
        }
    }

    /// Safe to call repeatedly (on appear, and whenever the log finishes catching up) — a run only
    /// starts once the log has fully replayed (`Raum.shared.nachgeholt`, so `aufgeraeumt` already
    /// reflects any earlier launch's own op) and only one run is ever in flight at a time.
    func versuchen() {
        guard Raum.shared.nachgeholt, !laeuft, let ich = Raum.shared.ich, !aufgeraeumt.contains(ich) else { return }
        let ziel = UmzugMigrationLogik.auszuraeumen(ChatModell.shared.nachrichten, ich: ich)
        guard !ziel.isEmpty else {
            Raum.shared.senden("umzug.aufraeumen", UmzugAufraeumenPayload())
            return
        }
        laeuft = true
        Task {
            defer { laeuft = false }
            // One shared library for the whole batch — `ArtworkLibrary.init` synchronously reads
            // library.json plus every document.json (Main Thread frei), so one instance beats one
            // per message.
            let library = ArtworkLibrary()
            var allesOk = true
            var geretteteZeichnung = false
            for nachricht in ziel {
                // `Medien.holen` (not `MedienDatei.url`, which retries forever on a Task that's
                // never cancelled) — one attempt; a miss just leaves this message for the next
                // catch-up to retry, same as any other failure here.
                guard let medium = nachricht.medien.first, let url = try? await Medien.holen(medium.id) else {
                    allesOk = false
                    continue
                }
                guard await ChatGalerie.speichernUndWarten(bildURL: url, name: "Aus dem Umzug", library: library) else {
                    allesOk = false
                    continue
                }
                geretteteZeichnung = true
                ChatModell.shared.loeschen(nachricht.id)
            }
            // Brief I.4: once for the whole batch, not once per message — an already-open Zeichnen
            // gallery (a DIFFERENT `ArtworkLibrary()` instance) reloads on this.
            if geretteteZeichnung { NotificationCenter.default.post(name: .artworkLibraryGeaendert, object: nil) }
            // A partial failure just leaves those messages for the next successful catch-up to
            // retry — `umzug.aufraeumen` only goes out once every one of them is done.
            guard allesOk else { return }
            Raum.shared.senden("umzug.aufraeumen", UmzugAufraeumenPayload())
        }
    }
}

private struct UmzugAufraeumenPayload: Codable {}
