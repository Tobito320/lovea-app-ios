import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// `PhotosPickerItem.loadTransferable(type:)` needs a concrete `Transferable` to get a video as a
/// file URL (there's no built-in one). The import copies the file out of `received.file` before the
/// closure returns — that path is deleted once it does.
struct VideoDatei: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { empfangen in
            let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            try FileManager.default.copyItem(at: empfangen.file, to: ziel)
            return Self(url: ziel)
        }
    }
}

/// Own resume queue for `Medien.hochladen` (Review-Fokus #5: an upload killed mid-flight must
/// continue, not leave the partner staring at "wird geladen" forever). `Medien.hochladen` itself
/// resumes a single call from wherever it stopped; nothing re-calls it after a relaunch — this
/// small JSON list plus `ausstehendeAbarbeiten()` is that missing piece.
private struct AusstehendeUpload: Codable { let id: String; let original: URL; let klein: URL? }

/// Upload + `nachricht.neu`/sticker sending for Chat media (Z-5.1, Z-5.2, Z-5.3, Z-5.5).
@MainActor
enum ChatMedien {
    /// This device's own just-sent media, shown immediately instead of "wird geladen" while
    /// `Medien.hochladen` is still running — `Medien.lokal` only has a copy once it finishes.
    /// Not `private(set)`: `ChatHintergrund.swift`'s own "Foto wählen" flow writes to this too.
    // ponytail: in-memory only, lost on relaunch; a relaunch mid-upload falls back to the
    // placeholder until `ausstehendeAbarbeiten()` finishes the retry. Acceptable for a two-person app.
    static var eigeneQuellen: [String: URL] = [:]

    private static let warteschlangeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Lovea/chat-hochladen.json")

    // MARK: - Photos + videos from the input bar's attachment tray (Z-5.1, Block 18)

    /// Each item becomes its own `nachricht.neu` (one id per upload, wire shape unchanged); the
    /// chat shows consecutive ones as one photo stack. All messages go out first, uploads after,
    /// so a slow upload never pushes the next photo out of the stack's 60 s window. Only the
    /// first message carries the reply reference.
    static func anhaengeSenden(_ inhalte: [ChatAnhang.Inhalt], antwortAuf: String? = nil) async {
        var antwort = antwortAuf
        var hochzuladen: [(id: String, ergebnis: MedienKodierung.Ergebnis)] = []
        for inhalt in inhalte {
            let id = UUID().uuidString
            let ergebnis: MedienKodierung.Ergebnis?
            let typ: String
            switch inhalt {
            case .foto(let daten):
                ergebnis = await Task.detached(priority: .userInitiated) { MedienKodierung.foto(daten, id: id) }.value
                typ = "foto"
            case .video(let quelle):
                ergebnis = await MedienKodierung.video(quelle, id: id)
                typ = "video"
            }
            guard let fertig = ergebnis else { continue }
            vormerkenUndSenden(id: id, ergebnis: fertig, typ: typ, antwortAuf: antwort)
            hochzuladen.append((id: id, ergebnis: fertig))
            antwort = nil
        }
        for eintrag in hochzuladen { await hochladen(id: eintrag.id, ergebnis: eintrag.ergebnis) }
    }

    static func videoSenden(_ quelle: URL, antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let ergebnis = await MedienKodierung.video(quelle, id: id) else { return }
        await hochladenUndSenden(id: id, ergebnis: ergebnis, typ: "video", antwortAuf: antwortAuf)
    }

    // MARK: - Voice (Z-5.2)

    static func sprachSenden(_ m4a: URL, dauer: Double, pegel: [Float], antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let originalURL = await Task.detached(priority: .userInitiated, operation: {
            MedienKodierung.schreibeStaging((try? Data(contentsOf: m4a)) ?? Data(), id: id, rolle: "original", ext: "m4a")
        }).value else { return }
        let ergebnis = MedienKodierung.Ergebnis(original: originalURL, klein: nil, breite: 0, hoehe: 0, dauer: dauer)
        eigeneQuellen[id] = originalURL
        merkeAusstehend(id: id, original: originalURL, klein: nil)
        ChatModell.shared.medienSenden(
            [ChatModell.MedienEintrag(id: id, typ: "sprache", breite: 0, hoehe: 0, dauer: dauer, pegel: pegel)],
            antwortAuf: antwortAuf
        )
        await hochladen(id: id, ergebnis: ergebnis)
    }

    // MARK: - Drawing hook (Z-5.5) — "Als Bild senden" (Level-2/Drawing) calls this with the PNG export.

    static func bildSenden(png: Data, breite: Double, hoehe: Double, antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let originalURL = await Task.detached(priority: .userInitiated, operation: {
            MedienKodierung.schreibeStaging(png, id: id, rolle: "original", ext: "png")
        }).value else { return }
        let ergebnis = MedienKodierung.Ergebnis(original: originalURL, klein: nil, breite: breite, hoehe: hoehe, dauer: nil)
        await hochladenUndSenden(id: id, ergebnis: ergebnis, typ: "foto", antwortAuf: antwortAuf)
    }

    // MARK: - Snaps (Z-6.2): editor hands the already-flattened photo/video to these — from here on
    // it's exactly Z-5.1's own pipeline (original + `klein`, off the main thread), just filed under
    // `snap.bleibt` instead of a plain `nachricht.neu`.

    static func snapFotoSenden(jpeg: Data, bleibt: Bool, antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let ergebnis = await Task.detached(priority: .userInitiated) { MedienKodierung.foto(jpeg, id: id) }.value else { return }
        eigeneQuellen[id] = ergebnis.original
        merkeAusstehend(id: id, original: ergebnis.original, klein: ergebnis.klein)
        ChatModell.shared.snapSenden(
            ChatModell.MedienEintrag(id: id, typ: "foto", breite: ergebnis.breite, hoehe: ergebnis.hoehe, dauer: nil, pegel: nil),
            bleibt: bleibt, antwortAuf: antwortAuf
        )
        await hochladen(id: id, ergebnis: ergebnis)
    }

    /// `quelle` is `SnapExport.video`'s already-flattened (overlay burned in) output — `MedienKodierung.video`
    /// re-encodes it the same way any other chat video is (720p original + 480p `klein`, ≤30s trim,
    /// redundant here since it's already ≤30s, but keeps one encoding path instead of two).
    static func snapVideoSenden(quelle: URL, bleibt: Bool, antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let ergebnis = await MedienKodierung.video(quelle, id: id) else { return }
        eigeneQuellen[id] = ergebnis.original
        merkeAusstehend(id: id, original: ergebnis.original, klein: ergebnis.klein)
        ChatModell.shared.snapSenden(
            ChatModell.MedienEintrag(id: id, typ: "video", breite: ergebnis.breite, hoehe: ergebnis.hoehe, dauer: ergebnis.dauer, pegel: nil),
            bleibt: bleibt, antwortAuf: antwortAuf
        )
        await hochladen(id: id, ergebnis: ergebnis)
    }

    /// Sticker/figure-sticker upload (Z-5.3): returns the medium id for `nachricht.neu {sticker:{medienId}}`.
    static func stickerHochladen(png: Data) async -> String? {
        let id = UUID().uuidString
        guard let originalURL = await Task.detached(priority: .userInitiated, operation: {
            MedienKodierung.schreibeStaging(png, id: id, rolle: "original", ext: "png")
        }).value else { return nil }
        eigeneQuellen[id] = originalURL
        merkeAusstehend(id: id, original: originalURL, klein: nil)
        do {
            try await Medien.hochladen(id: id, original: originalURL, klein: nil)
            vergisAusstehend(id: id)
            return id
        } catch {
            return id // stays in the resume queue; caller can still send the reference now, the media catches up
        }
    }

    // MARK: - Draft uploads (Z-26.2): upload right away, don't send a message — the caller keeps
    // the returned id for `entwurf.setzen` and reuses it unchanged (via `ChatModell.medienSenden`)
    // once the draft is actually sent, so the photo/voice note is never uploaded twice.

    static func entwurfBildHochladen(_ daten: Data) async -> (medienId: String, breite: Double, hoehe: Double)? {
        let id = UUID().uuidString
        guard let ergebnis = await Task.detached(priority: .userInitiated) { MedienKodierung.foto(daten, id: id) }.value else { return nil }
        eigeneQuellen[id] = ergebnis.original
        merkeAusstehend(id: id, original: ergebnis.original, klein: ergebnis.klein)
        await hochladen(id: id, ergebnis: ergebnis)
        return (id, ergebnis.breite, ergebnis.hoehe)
    }

    static func entwurfSprachHochladen(_ m4a: URL) async -> String? {
        let id = UUID().uuidString
        guard let originalURL = await Task.detached(priority: .userInitiated, operation: {
            MedienKodierung.schreibeStaging((try? Data(contentsOf: m4a)) ?? Data(), id: id, rolle: "original", ext: "m4a")
        }).value else { return nil }
        eigeneQuellen[id] = originalURL
        merkeAusstehend(id: id, original: originalURL, klein: nil)
        await hochladen(id: id, ergebnis: MedienKodierung.Ergebnis(original: originalURL, klein: nil, breite: 0, hoehe: 0, dauer: nil))
        return id
    }

    // MARK: - Video vorab (Schalter "Videos vorab hochladen (Test)", `VideoVorab`)
    // Das gewählte Video wird schon im Anhang-Streifen kodiert und hochgeladen. Es kommt NICHT in den
    // Entwurf (`entwurf.setzen`): die Wiederherstellung kennt nur Fotos und würde es als Foto senden.
    // Beim Senden geht nur `nachricht.neu`; wurde der Anhang vorher entfernt, wird die Arbeit
    // abgebrochen und aufgeräumt, es entsteht nie eine Nachricht.
    // ponytail: die Kodierung selbst läuft nach einem Abbruch noch zu Ende (nicht abbrechbar ohne
    // Gerätetest), nur der Upload startet dann nicht mehr. Der Chat ist ein Tab: der Anhang-Streifen
    // überlebt einen Tabwechsel, also kein Abbruch bei `onDisappear`. Bleibt nur: App wird mitten im
    // Upload beendet, dann setzt `Medien.fortsetzen` ihn einmal fort (Waise, keine Nachricht).

    struct VideoVorabErgebnis: Sendable { let id: String; let ergebnis: MedienKodierung.Ergebnis; let hochgeladen: Bool }

    private static var vorab: [UUID: Task<VideoVorabErgebnis?, Never>] = [:]
    private static var vorabLaufende = 0

    static func videoVorabStarten(anhang: UUID, quelle: URL) {
        guard VideoVorab.starten(schalter: VideoVorab.an(), laufende: vorabLaufende) else { return }
        vorabLaufende += 1
        vorab[anhang] = Task<VideoVorabErgebnis?, Never> {
            defer { vorabLaufende -= 1 }
            return await videoVorabArbeit(quelle: quelle)
        }
    }

    /// Kodieren, dann hochladen. `nil` = Kodierung gescheitert oder abgebrochen (dann ist schon aufgeräumt).
    private static func videoVorabArbeit(quelle: URL) async -> VideoVorabErgebnis? {
        let id = UUID().uuidString
        let kodiert = await MedienKodierung.video(quelle, id: id)
        guard let ergebnis = kodiert, !Task.isCancelled else {
            videoVorabVerwerfen(id: id, ergebnis: kodiert)
            return nil
        }
        eigeneQuellen[id] = ergebnis.original
        var hochgeladen = false
        do {
            try await Medien.hochladen(id: id, original: ergebnis.original, klein: ergebnis.klein)
            hochgeladen = true
        } catch {
            // stiller Rückfall: beim Senden geht die Op raus und der Upload läuft über die Warteschlange
        }
        if Task.isCancelled {
            videoVorabVerwerfen(id: id, ergebnis: ergebnis)
            return nil
        }
        return VideoVorabErgebnis(id: id, ergebnis: ergebnis, hochgeladen: hochgeladen)
    }

    /// Bricht jedes Vorab ab, dessen Anhang nicht mehr im Entwurf steht, und räumt auf.
    static func videoVorabAufraeumen(behalten: Set<UUID>) {
        for anhang in VideoVorab.abzubrechen(offen: Set(vorab.keys), imEntwurf: behalten) {
            guard let task = vorab.removeValue(forKey: anhang) else { continue }
            task.cancel()
            // War es schon fertig, bevor das Abbrechen griff: das Ergebnis hier wegwerfen.
            Task {
                if let fertig = await task.value { videoVorabVerwerfen(id: fertig.id, ergebnis: fertig.ergebnis) }
            }
        }
    }

    /// Nimmt die laufenden Vorab-Aufträge der gesendeten Anhänge aus der Liste, damit
    /// `videoVorabAufraeumen` sie nicht abbricht. Vor dem Leeren des Entwurfs aufrufen.
    static func videoVorabAbholen(_ anhaenge: [UUID]) -> [UUID: Task<VideoVorabErgebnis?, Never>] {
        var geholt: [UUID: Task<VideoVorabErgebnis?, Never>] = [:]
        for anhang in anhaenge { geholt[anhang] = vorab.removeValue(forKey: anhang) }
        return geholt
    }

    /// Ein Video aus dem Anhang-Streifen senden: mit fertigem Vorab nur die Op, mit laufendem warten
    /// (ohne neu zu kodieren), sonst der heutige Weg.
    static func videoVorabSenden(_ auftrag: Task<VideoVorabErgebnis?, Never>?, quelle: URL, antwortAuf: String?) async {
        var stand: VideoVorab.Stand = auftrag == nil ? .keiner : .offen
        var fertig: VideoVorabErgebnis?
        if VideoVorab.weg(beimSenden: stand) == .aufEndeWarten, let auftrag {
            fertig = await auftrag.value
            stand = VideoVorab.stand(kodiert: fertig != nil, hochgeladen: fertig?.hochgeladen ?? false)
        }
        switch (VideoVorab.weg(beimSenden: stand), fertig) {
        case (.nurOp, let f?):
            ChatModell.shared.medienSenden(
                [ChatModell.MedienEintrag(id: f.id, typ: "video", breite: f.ergebnis.breite, hoehe: f.ergebnis.hoehe, dauer: f.ergebnis.dauer, pegel: nil)],
                antwortAuf: antwortAuf
            )
        case (.opDannHochladen, let f?):
            await hochladenUndSenden(id: f.id, ergebnis: f.ergebnis, typ: "video", antwortAuf: antwortAuf)
        default:
            await anhaengeSenden([.video(quelle)], antwortAuf: antwortAuf)
        }
    }

    /// Löscht, was ein verworfenes Vorab hinterlassen hat: Staging-Dateien, die Upload-Kopie
    /// (`Sync/Medien.swift` legt sie unter `Lovea/medien/hochladen/<id>-<rolle>` ab) und die Cache-Kopie.
    private static func videoVorabVerwerfen(id: String, ergebnis: MedienKodierung.Ergebnis?) {
        eigeneQuellen[id] = nil
        let medien = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/medien", isDirectory: true)
        var weg = [medien.appendingPathComponent(id)]
        for rolle in ["original", "klein"] {
            weg.append(medien.appendingPathComponent("hochladen/\(id)-\(rolle)"))
            weg.append(medien.appendingPathComponent("hochladen/\(id)-\(rolle).tmp"))
            weg.append(MedienKodierung.stagingURL(id: id, rolle: rolle, ext: "mov"))
        }
        if let ergebnis {
            weg.append(ergebnis.original)
            if let klein = ergebnis.klein { weg.append(klein) }
        }
        for url in weg { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Upload + send

    private static func hochladenUndSenden(id: String, ergebnis: MedienKodierung.Ergebnis, typ: String, antwortAuf: String?) async {
        vormerkenUndSenden(id: id, ergebnis: ergebnis, typ: typ, antwortAuf: antwortAuf)
        await hochladen(id: id, ergebnis: ergebnis)
    }

    private static func vormerkenUndSenden(id: String, ergebnis: MedienKodierung.Ergebnis, typ: String, antwortAuf: String?) {
        eigeneQuellen[id] = ergebnis.original
        merkeAusstehend(id: id, original: ergebnis.original, klein: ergebnis.klein)
        ChatModell.shared.medienSenden(
            [ChatModell.MedienEintrag(id: id, typ: typ, breite: ergebnis.breite, hoehe: ergebnis.hoehe, dauer: ergebnis.dauer, pegel: nil)],
            antwortAuf: antwortAuf
        )
    }

    private static func hochladen(id: String, ergebnis: MedienKodierung.Ergebnis) async {
        do {
            try await Medien.hochladen(id: id, original: ergebnis.original, klein: ergebnis.klein)
            vergisAusstehend(id: id)
        } catch {
            // stays in the resume queue; `ausstehendeAbarbeiten()` retries later
        }
    }

    /// Retries every not-yet-finished upload. Call from `ChatTab` on appear and whenever
    /// `Raum.shared.verbunden` flips true — Block 5 doesn't touch `LoveaApp`/`Sync` (wave3.md file
    /// ownership), so there's no app-wide hook; this covers the practical case of the chat being open.
    static func ausstehendeAbarbeiten() async {
        for eintrag in ladeAusstehend() {
            do {
                try await Medien.hochladen(id: eintrag.id, original: eintrag.original, klein: eintrag.klein)
                vergisAusstehend(id: eintrag.id)
            } catch {
                continue
            }
        }
    }

    // MARK: - Manifest

    private static func merkeAusstehend(id: String, original: URL, klein: URL?) {
        var liste = ladeAusstehend()
        liste.removeAll { $0.id == id }
        liste.append(AusstehendeUpload(id: id, original: original, klein: klein))
        speichereAusstehend(liste)
    }

    private static func vergisAusstehend(id: String) {
        var liste = ladeAusstehend()
        liste.removeAll { $0.id == id }
        speichereAusstehend(liste)
    }

    private static func ladeAusstehend() -> [AusstehendeUpload] {
        guard let data = try? Data(contentsOf: warteschlangeURL) else { return [] }
        return (try? JSONDecoder().decode([AusstehendeUpload].self, from: data)) ?? []
    }

    // ponytail: the manifest stays a synchronous (tiny) main-actor write on purpose — it must be on
    // disk before `nachricht.neu` goes out, or an app kill in between loses the resume entry
    // (Review-Fokus #5). Upgrade: an actor-owned manifest if it ever grows beyond a few entries.
    private static func speichereAusstehend(_ liste: [AusstehendeUpload]) {
        try? FileManager.default.createDirectory(at: warteschlangeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(liste) else { return }
        try? data.write(to: warteschlangeURL, options: .atomic)
    }
}

/// Snapshot writes for small JSON stores whose source of truth is already in memory
/// (`EigeneSticker`, `GesichtsFilter`): one serial queue, so writes land in order, off the main thread.
enum KleineDatei {
    private static let schlange = DispatchQueue(label: "lovea.chat.kleine-datei", qos: .utility)

    static func schreiben(_ daten: Data, nach url: URL) {
        schlange.async {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? daten.write(to: url, options: .atomic)
        }
    }
}
