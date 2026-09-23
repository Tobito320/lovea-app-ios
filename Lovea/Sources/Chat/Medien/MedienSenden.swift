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
    // ponytail: in-memory only, lost on relaunch; a relaunch mid-upload falls back to the
    // placeholder until `ausstehendeAbarbeiten()` finishes the retry. Acceptable for a two-person app.
    private(set) static var eigeneQuellen: [String: URL] = [:]

    private static let warteschlangeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Lovea/chat-hochladen.json")

    // MARK: - Photos + videos, mixed PhotosPicker selection (Z-5.1)

    /// One `PhotosPicker` selects both kinds (`matching: .any(of: [.images, .videos])`); each item
    /// becomes its own `nachricht.neu` — simplest correct mapping onto the one-id-per-upload model,
    /// and matches sending several photos "auf einmal" as several bubbles instead of a multi-image one.
    static func auswahlSenden(_ items: [PhotosPickerItem], antwortAuf: String? = nil) async {
        for item in items {
            if let video = try? await item.loadTransferable(type: VideoDatei.self) {
                await videoSenden(video.url, antwortAuf: antwortAuf)
            } else if let daten = try? await item.loadTransferable(type: Data.self) {
                let id = UUID().uuidString
                guard let ergebnis = await Task.detached(priority: .userInitiated) { MedienKodierung.foto(daten, id: id) }.value else { continue }
                await hochladenUndSenden(id: id, ergebnis: ergebnis, typ: "foto", antwortAuf: antwortAuf)
            }
        }
    }

    static func videoSenden(_ quelle: URL, antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let ergebnis = await MedienKodierung.video(quelle, id: id) else { return }
        await hochladenUndSenden(id: id, ergebnis: ergebnis, typ: "video", antwortAuf: antwortAuf)
    }

    // MARK: - Voice (Z-5.2)

    static func sprachSenden(_ m4a: URL, dauer: Double, pegel: [Float], antwortAuf: String? = nil) async {
        let id = UUID().uuidString
        guard let originalURL = MedienKodierung.schreibeStaging((try? Data(contentsOf: m4a)) ?? Data(), id: id, rolle: "original", ext: "m4a") else { return }
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
        guard let originalURL = MedienKodierung.schreibeStaging(png, id: id, rolle: "original", ext: "png") else { return }
        let ergebnis = MedienKodierung.Ergebnis(original: originalURL, klein: nil, breite: breite, hoehe: hoehe, dauer: nil)
        await hochladenUndSenden(id: id, ergebnis: ergebnis, typ: "foto", antwortAuf: antwortAuf)
    }

    /// Sticker/figure-sticker upload (Z-5.3): returns the medium id for `nachricht.neu {sticker:{medienId}}`.
    static func stickerHochladen(png: Data) async -> String? {
        let id = UUID().uuidString
        guard let originalURL = MedienKodierung.schreibeStaging(png, id: id, rolle: "original", ext: "png") else { return nil }
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

    // MARK: - Upload + send

    private static func hochladenUndSenden(id: String, ergebnis: MedienKodierung.Ergebnis, typ: String, antwortAuf: String?) async {
        eigeneQuellen[id] = ergebnis.original
        merkeAusstehend(id: id, original: ergebnis.original, klein: ergebnis.klein)
        ChatModell.shared.medienSenden(
            [ChatModell.MedienEintrag(id: id, typ: typ, breite: ergebnis.breite, hoehe: ergebnis.hoehe, dauer: ergebnis.dauer, pegel: nil)],
            antwortAuf: antwortAuf
        )
        await hochladen(id: id, ergebnis: ergebnis)
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

    private static func speichereAusstehend(_ liste: [AusstehendeUpload]) {
        try? FileManager.default.createDirectory(at: warteschlangeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(liste) else { return }
        try? data.write(to: warteschlangeURL, options: .atomic)
    }
}
