import CryptoKit
import Foundation
@preconcurrency import Metal

/// Moves a saved drawing between the two phones as media: document JSON, one PNG per layer, preview.
/// No zip: every file is its own medium, unchanged files keep their medium id.
@MainActor
enum StandPaket {
    /// Content hash → medium id of files this process already uploaded.
    private static var hochgeladen: [String: String] = [:]
    private static var zuletzt: [String: TimeInterval] = [:]
    private static var geplant: Set<String> = []
    private static var letzterStand: [String: ZeichnungStand] = [:]
    /// Layer file → medium id already written into the shared library (viewer).
    private static var importiert: [String: String] = [:]

    // MARK: Owner

    /// Publishes the saved state of an own drawing, at most every 30 s per drawing. Calls inside the
    /// window fold into one publish at its end.
    static func planen(_ artworkID: UUID, library: ArtworkLibrary) {
        let id = artworkID.uuidString
        guard !geplant.contains(id) else { return }
        geplant.insert(id)
        let warten = max(0, 30 - (ProcessInfo.processInfo.systemUptime - (zuletzt[id] ?? -30)))
        Task {
            try? await Task.sleep(for: .seconds(warten))
            geplant.remove(id)
            zuletzt[id] = ProcessInfo.processInfo.systemUptime
            await veroeffentlichen(artworkID, library: library)
        }
    }

    private static func veroeffentlichen(_ artworkID: UUID, library: ArtworkLibrary) async {
        let id = artworkID.uuidString
        let teilen = TeilenModell.shared.stand
        guard let document = library.document(artworkID), teilen.istGeteilt(document) else { return }
        // This save is already published (also across app starts, from the op log). The library's
        // ISO dates drop fractions after a restart, which only rounds down: still "not newer".
        if let letzter = teilen.staende[id], letzter.von == Raum.shared.ich,
           let gespeichert = letzter.wert.gespeichert, document.updatedAt.timeIntervalSince1970 <= gespeichert { return }
        await library.waitForWrites()
        do {
            var ebenen: [ZeichnungStand.Ebene] = []
            for layer in document.layers {
                let url = library.layerAssetURL(fileName: layer.contentFile, artworkID: artworkID)
                if let medienId = try await hochladen(url) {
                    ebenen.append(.init(ebene: layer.id.uuidString, medienId: medienId))
                }
            }
            let vorschau = try await hochladen(library.previewURL(for: artworkID))
            let json = try encoder().encode(document)
            let datei = FileManager.default.temporaryDirectory.appendingPathComponent("stand-\(id).json")
            try await Task.detached { try json.write(to: datei, options: .atomic) }.value
            guard let medienId = try await hochladen(datei) else { return }
            let stand = ZeichnungStand(
                zeichnungId: id, medienId: medienId, basis: document.basis ?? 0,
                ebenen: ebenen, name: document.name, projektId: document.projectID?.uuidString,
                vorschau: vorschau, offen: document.offen, gespeichert: document.updatedAt.timeIntervalSince1970
            )
            guard stand != letzterStand[id] else { return }
            // I-5: the server deletes the previous stand's media the new one doesn't use. Forget them
            // here too, or an undo back to old content would reuse a deleted medium id.
            if let alt = letzterStand[id] {
                let weg = medienIds(alt).subtracting(medienIds(stand))
                hochgeladen = hochgeladen.filter { !weg.contains($0.value) }
            }
            letzterStand[id] = stand
            Raum.shared.senden("zeichnung.stand", stand)
        } catch {
            // ponytail: no retry loop; the next autosave or opening publishes again.
            return
        }
    }

    private static func medienIds(_ stand: ZeichnungStand) -> Set<String> {
        Set(stand.ebenen.map(\.medienId) + [stand.medienId] + (stand.vorschau.map { [$0] } ?? []))
    }

    /// Uploads a file once per content. Nil when the file doesn't exist (empty, never saved layer).
    private static func hochladen(_ url: URL) async throws -> String? {
        let schluessel = await Task.detached(priority: .utility) { () -> String? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }.value
        guard let schluessel else { return nil }
        if let bekannt = hochgeladen[schluessel] { return bekannt }
        let medienId = UUID().uuidString
        try await Medien.hochladen(id: medienId, original: url, klein: nil)
        // The sender never needs its own stand back.
        if let kopie = Medien.lokal(medienId) { try? FileManager.default.removeItem(at: kopie) }
        hochgeladen[schluessel] = medienId
        return medienId
    }

    // MARK: Viewer

    /// Downloads a partner stand into `library` (the shared library) and returns its document.
    /// Layers whose medium is already there are skipped.
    static func laden(_ stand: ZeichnungStand, into library: ArtworkLibrary) async throws -> ArtworkDocument {
        let jsonURL = try await Medien.holen(stand.medienId)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = try await lesen(jsonURL)
        let document = try decoder.decode(ArtworkDocument.self, from: json)
        for layer in document.layers {
            let schluessel = "\(document.id.uuidString)/\(layer.contentFile)"
            guard let ebene = stand.ebenen.first(where: { $0.ebene == layer.id.uuidString }) else {
                library.removeLayerAsset(fileName: layer.contentFile, artworkID: document.id)
                importiert[schluessel] = nil
                continue
            }
            guard importiert[schluessel] != ebene.medienId else { continue }
            let url = try await Medien.holen(ebene.medienId)
            let data = try await lesen(url)
            library.saveLayerData(data, layer: layer, artworkID: document.id)
            try? FileManager.default.removeItem(at: url)
            importiert[schluessel] = ebene.medienId
        }
        library.saveDocument(document)
        try? FileManager.default.removeItem(at: jsonURL)
        return document
    }

    // MARK: Pixels of shared-drawing ops

    /// Uploads the pixels an own op carries and fills in their medium ids.
    static func medienHochladen(_ aktion: ZeichnungAktion, texturen: [String: MTLTexture]) async throws -> ZeichnungAktion {
        switch aktion {
        case let .pixel(ebene, x, y, breite, hoehe, _):
            guard let textur = texturen[ebene], let medienId = try await hochladen(textur) else { throw Medien.MedienFehler.datei }
            return .pixel(ebene: ebene, x: x, y: y, breite: breite, hoehe: hoehe, medienId: medienId)
        case var .ebenen(aenderung):
            for index in aenderung.neu.indices {
                if let textur = texturen[aenderung.neu[index].ebene.id.uuidString] {
                    aenderung.neu[index].medienId = try await hochladen(textur)
                }
            }
            return .ebenen(aenderung)
        case .strich, .fuellen:
            return aktion
        }
    }

    /// Downloads the pixels an incoming op needs, as textures by layer id. Three tries, then it gives up.
    static func medienLaden(_ aktion: ZeichnungAktion) async throws -> [String: MTLTexture] {
        var medien: [(ebene: String, medienId: String)] = []
        switch aktion {
        case let .pixel(ebene, _, _, _, _, medienId):
            medien = [(ebene: ebene, medienId: medienId)]
        case let .ebenen(aenderung):
            medien = aenderung.neu.compactMap { neu in neu.medienId.map { (ebene: neu.ebene.id.uuidString, medienId: $0) } }
        case .strich, .fuellen:
            break
        }
        var texturen: [String: MTLTexture] = [:]
        for medium in medien {
            var versuch = 0
            while true {
                do {
                    let url = try await Medien.holen(medium.medienId)
                    let pixels = try await Task.detached(priority: .userInitiated) { () throws -> RasterOps.Pixels in
                        guard let pixels = RasterOps.decode(try Data(contentsOf: url)) else { throw Medien.MedienFehler.datei }
                        return pixels
                    }.value
                    guard let textur = GPU.upload(pixels.bytes, width: pixels.width, height: pixels.height) else {
                        throw Medien.MedienFehler.datei
                    }
                    texturen[medium.ebene] = textur
                    break
                } catch {
                    versuch += 1
                    if versuch >= 3 { throw error }
                    try? await Task.sleep(for: .seconds(versuch))
                }
            }
        }
        return texturen
    }

    private static func hochladen(_ textur: MTLTexture) async throws -> String? {
        let pixels = RasterOps.Pixels(bytes: await GPU.readBytes(textur), width: textur.width, height: textur.height)
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent("op-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: datei) }
        try await Task.detached(priority: .utility) {
            guard let png = RasterOps.encode(pixels) else { throw Medien.MedienFehler.datei }
            try png.write(to: datei, options: .atomic)
        }.value
        return try await hochladen(datei)
    }

    private static func lesen(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: Chat

    private struct BildNachricht: Encodable {
        struct Medium: Encodable {
            let id: String
            let typ: String
            let breite: Int
            let hoehe: Int
        }

        let id: String
        let medien: [Medium]
        var text: String?
    }

    /// "Als Bild senden": the flattened PNG plus a small JPEG as a chat photo.
    static func alsBildSenden(_ engine: CanvasEngine, text: String? = nil) async throws {
        guard let pixels = await engine.flattenedPixels(), let klein = await engine.thumbnailJPEG(maxDimension: 1024) else {
            throw Medien.MedienFehler.datei
        }
        let medienId = UUID().uuidString
        let ordner = FileManager.default.temporaryDirectory
        let original = ordner.appendingPathComponent("\(medienId).png")
        let kleinURL = ordner.appendingPathComponent("\(medienId)-klein.jpg")
        try await Task.detached(priority: .userInitiated) {
            guard let png = RasterOps.encode(pixels) else { throw Medien.MedienFehler.datei }
            try png.write(to: original, options: .atomic)
            try klein.write(to: kleinURL, options: .atomic)
        }.value
        try await Medien.hochladen(id: medienId, original: original, klein: kleinURL)
        Raum.shared.senden("nachricht.neu", BildNachricht(
            id: UUID().uuidString,
            medien: [.init(id: medienId, typ: "foto", breite: pixels.width, hoehe: pixels.height)],
            text: text
        ))
    }
}
