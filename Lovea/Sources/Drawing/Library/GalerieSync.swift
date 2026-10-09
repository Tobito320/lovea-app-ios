import CryptoKit
import Foundation

/// Galerie-Sync (Design 27.09.2026): syncs one person's drawing gallery across their own devices
/// (iPhone + iPad, same profile) -- never with the partner. Writes incoming stands through its own
/// `ArtworkLibrary()` instance (same disk root as every other instance, see the multi-instance note
/// on `.artworkLibraryGeaendert` in `ArtworkLibrary.swift`) and posts that notification so an open
/// gallery reloads. `ArtworkLibrary`'s own mutating methods call back into this singleton
/// (`markiereSchmutzig`/`artworkGeloescht`/`projekteGeaendert`) -- except the raw-write methods this
/// file uses for incoming stands, which must never re-dirty what they just wrote (that would be an
/// endless echo loop between two devices).
@MainActor
final class GalerieSync {
    static let shared = GalerieSync()

    private static let arten: Set<String> = ["galerie.stand", "galerie.geloescht", "galerie.projekte", "galerie.sticker"]
    private static let schmutzigKey = "galerie.sync.schmutzig"
    private static let backfillKey = "galerie.sync.backfill"
    private static let projekteSeqKey = "galerie.sync.projekteSeq"
    private static let stickerSeqKey = "galerie.sync.stickerSeq"
    /// Deleted drawing id -> deletion time. The full log is replayed at every launch; without this an
    /// old `galerie.stand` (async download) lands after its sync `galerie.geloescht` and resurrects it.
    private static let geloeschtKey = "galerie.sync.geloescht"

    /// Lazy: `ArtworkLibrary.init` liest die ganze Bibliothek auf dem Main Thread. Schneller Start
    /// (`StartPlan`) legt sie erst nach dem ersten Bild an; `start()` erzwingt sie sonst wie vorher.
    private lazy var library: ArtworkLibrary = {
        StartProtokoll.marke("galerie.bibliothek.neu")
        return self.vorgegebeneBibliothek ?? ArtworkLibrary()
    }()
    private let vorgegebeneBibliothek: ArtworkLibrary?
    /// Schneller Start: auch das Replay (gelöscht, Projekte) fasst die Bibliothek erst nach dem ersten Bild an.
    private var bibliothekSpaeter = false
    /// Own drawing currently open in the Studio -- an incoming stand for it is held back until the
    /// Studio closes (design: "offene Zeichnung zurückstellen").
    private var offenesArtworkID: UUID?
    private var zurueckgestellt: [UUID: GalerieStandD] = [:]
    /// Chains every upload attempt (studio-close, background, backfill) so drawings go out one at a
    /// time, never in parallel (design: Erststart-Backfill "nacheinander").
    private var hochladeKette: Task<Void, Never>?
    /// Newest known incoming stand per drawing, not yet applied (see `eingehend`).
    private var wartend: [UUID: GalerieStandD] = [:]

    init(library: ArtworkLibrary? = nil) {
        vorgegebeneBibliothek = library
    }

    /// `nachErstemBild` (Schneller Start): die Beobachtung muss VOR dem Replay stehen und bleibt hier.
    /// Eingehende Stände, Hochladen und der Erststart-Backfill laufen aber erst, wenn das erste Bild
    /// steht (`hochladeKette` wartet), und die Bibliothek wird erst dann gelesen.
    func start(nachErstemBild: Bool = false) {
        bibliothekSpaeter = nachErstemBild
        if nachErstemBild {
            hochladeKette = Task { @MainActor in await AppStart.erstesBildAbwarten() }
        } else {
            _ = library
        }
        Raum.shared.beobachten(Self.arten) { [weak self] op in self?.eingehend(op) }
        if nachErstemBild {
            reihen { [weak self] in self?.backfillFallsNoetig() }
        } else {
            backfillFallsNoetig()
        }
    }

    // MARK: - Own changes (called by `ArtworkLibrary`)

    func markiereSchmutzig(_ id: UUID) {
        var ids = schmutzigeIDs()
        guard ids.insert(id.uuidString).inserted else { return }
        UserDefaults.standard.set(Array(ids), forKey: Self.schmutzigKey)
    }

    func istSchmutzig(_ id: UUID) -> Bool { schmutzigeIDs().contains(id.uuidString) }

    /// Design: "Löschen sendet sofort galerie.geloescht", no dirty-marking detour.
    func artworkGeloescht(_ id: UUID) {
        schmutzigEntfernen(id)
        grabsteinSetzen(id, zeit: Date())
        Raum.shared.senden("galerie.geloescht", GalerieGeloeschtD(artworkId: id.uuidString, zeit: Date()))
    }

    /// Design: "Projektänderungen senden galerie.projekte", right away.
    func projekteGeaendert(_ projects: [ArtworkProject]) {
        Raum.shared.senden("galerie.projekte", GalerieProjekteD(projekte: projects, reihenfolge: projects.map(\.id)))
    }

    func stickerGeaendert(_ medienIds: [String]) {
        Raum.shared.senden("galerie.sticker", GalerieStickerD(medienIds: medienIds))
    }

    // MARK: - Studio lifecycle

    func studioBetreten(_ id: UUID) { offenesArtworkID = id }

    /// Applies a stand held back while this drawing was open, then tries to upload it (design:
    /// upload happens "beim Schließen des Studios").
    func studioVerlassen(_ id: UUID) {
        if offenesArtworkID == id { offenesArtworkID = nil }
        if let d = zurueckgestellt.removeValue(forKey: id) {
            reihen { [weak self] in await self?.standEingegangen(d) }
        }
        hochladenVersuchen(id)
    }

    // MARK: - Uploading

    /// App backgrounding: every dirty drawing goes out (design: "beim Wechsel in den Hintergrund").
    func hintergrund() {
        for id in schmutzigeIDs().compactMap({ UUID(uuidString: $0) }) { hochladenVersuchen(id) }
    }

    private func hochladenVersuchen(_ id: UUID) {
        guard istSchmutzig(id) else { return }
        reihen { [weak self] in await self?.hochladen(id) }
    }

    private func reihen(_ arbeit: @escaping () async -> Void) {
        let vorherige = hochladeKette
        hochladeKette = Task { @MainActor in
            await vorherige?.value
            await arbeit()
        }
    }

    private func hochladen(_ id: UUID) async {
        // This instance's own copy (design note in `ArtworkLibrary.swift`: every write from the UI's
        // instance is invisible here until reloaded) -- refresh before reading.
        library.load()
        guard istSchmutzig(id), let ich = Raum.shared.ich, let document = library.document(id) else { return }
        await library.waitForWrites()
        var dateien: [String: String] = [:]
        for layer in document.layers {
            guard let inhalt = library.layerAsset(fileName: layer.contentFile, artworkID: id),
                  let inhaltId = await hochladeDatei(inhalt, person: ich) else { return } // retry next occasion
            dateien[layer.contentFile] = inhaltId
            if let maskFile = layer.alphaMaskFile {
                guard let maske = library.layerAsset(fileName: maskFile, artworkID: id),
                      let maskId = await hochladeDatei(maske, person: ich) else { return }
                dateien[maskFile] = maskId
            }
        }
        if let vorschau = try? Data(contentsOf: library.previewURL(for: id)),
           let vorschauId = await hochladeDatei(vorschau, person: ich) {
            dateien["vorschau.jpg"] = vorschauId
        }
        Raum.shared.senden("galerie.stand", GalerieStandD(artworkId: id.uuidString, dokument: document, dateien: dateien))
        schmutzigEntfernen(id)
    }

    /// Content-addressed id (design): an unchanged layer already sits in the local media cache
    /// under this exact id (from a prior upload, or a download of the same content), so it's
    /// skipped instead of uploaded again.
    private func hochladeDatei(_ data: Data, person: Person) async -> String? {
        let id = Self.medienId(person: person, bytes: data)
        guard Medien.lokal(id) == nil else { return id }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(id)
        guard (try? data.write(to: temp, options: .atomic)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: temp) }
        do {
            try await Medien.hochladen(id: id, original: temp)
            return id
        } catch {
            return nil
        }
    }

    private func schmutzigEntfernen(_ id: UUID) {
        var ids = schmutzigeIDs()
        guard ids.remove(id.uuidString) != nil else { return }
        UserDefaults.standard.set(Array(ids), forKey: Self.schmutzigKey)
    }

    private func schmutzigeIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.schmutzigKey) ?? [])
    }

    // MARK: - Backfill (first launch on this device)

    private func backfillFallsNoetig() {
        guard !UserDefaults.standard.bool(forKey: Self.backfillKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.backfillKey)
        library.load()
        for artwork in library.artworks { markiereSchmutzig(artwork.id) }
        projekteGeaendert(library.projects)
        stickerGeaendert(EigeneSticker.gespeicherte())
        hintergrund()
    }

    // MARK: - Receiving

    private func eingehend(_ op: Op) {
        switch op.art {
        case "galerie.stand":
            guard let d = op.daten(GalerieStandD.self), let id = UUID(uuidString: d.artworkId) else { return }
            // The launch replay delivers every historical stand: keep only the newest per drawing and
            // apply through the serial chain, so an older download can't finish after a newer one.
            if let alt = wartend[id], alt.dokument.updatedAt >= d.dokument.updatedAt { return }
            let neuPlanen = wartend[id] == nil
            wartend[id] = d
            if neuPlanen { reihen { [weak self] in await self?.wartendenAnwenden(id) } }
        case "galerie.geloescht":
            guard let d = op.daten(GalerieGeloeschtD.self) else { return }
            geloeschtEingegangen(d)
        case "galerie.projekte":
            guard let d = op.daten(GalerieProjekteD.self) else { return }
            projekteEingegangen(d, seq: op.seq)
        case "galerie.sticker":
            guard let d = op.daten(GalerieStickerD.self) else { return }
            stickerEingegangen(d, seq: op.seq)
        default:
            break
        }
    }

    private func wartendenAnwenden(_ id: UUID) async {
        guard let d = wartend.removeValue(forKey: id) else { return }
        await standEingegangen(d)
    }

    private func standEingegangen(_ d: GalerieStandD) async {
        guard let artworkId = UUID(uuidString: d.artworkId) else { return }
        if Self.vonLoeschungUeberholt(geloeschtAm: grabstein(artworkId), updatedAt: d.dokument.updatedAt) { return }
        library.load() // see the note in `hochladen` -- this instance's own copy can be stale
        let vorhanden = library.document(artworkId)
        if vorhanden == nil, let duplikat = duplikatID(fuer: d, artworkId: artworkId) {
            library.removeWithoutSync(duplikat)
        }
        switch Self.entscheidung(
            eingehendUpdatedAt: d.dokument.updatedAt,
            lokalUpdatedAt: vorhanden?.updatedAt,
            offenInStudio: offenesArtworkID == artworkId
        ) {
        case .zurueckstellen:
            zurueckgestellt[artworkId] = d
        case .ueberspringen:
            break
        case .anwenden:
            await anwenden(d, artworkId: artworkId)
        }
    }

    private func anwenden(_ d: GalerieStandD, artworkId: UUID) async {
        var dateien: [String: Data] = [:]
        for layer in d.dokument.layers {
            guard let medienId = d.dateien[layer.contentFile],
                  let url = try? await Medien.holen(medienId),
                  let bytes = try? Data(contentsOf: url) else { return } // upload not finished yet, retry later
            dateien[layer.contentFile] = bytes
            if let maskFile = layer.alphaMaskFile {
                guard let maskId = d.dateien[maskFile],
                      let maskURL = try? await Medien.holen(maskId),
                      let maskBytes = try? Data(contentsOf: maskURL) else { return }
                dateien[maskFile] = maskBytes
            }
        }
        if let vorschauId = d.dateien["vorschau.jpg"], let url = try? await Medien.holen(vorschauId),
           let bytes = try? Data(contentsOf: url) {
            dateien["vorschau.jpg"] = bytes
        }
        var dokument = d.dokument
        dokument.id = artworkId
        await schreiben(dokument, dateien: dateien)
    }

    /// Writes an already-resolved remote stand into `library`, raw (`updatedAt` kept, not marked
    /// dirty). Split out from `anwenden` so it's testable without touching the network.
    func schreiben(_ dokument: ArtworkDocument, dateien: [String: Data]) async {
        for (name, data) in dateien where name != "vorschau.jpg" {
            library.saveLayerAsset(data, fileName: name, artworkID: dokument.id)
        }
        if let vorschau = dateien["vorschau.jpg"] {
            library.savePreview(jpeg: vorschau, artworkID: dokument.id)
        }
        library.applyRemoteDocument(dokument)
        await library.waitForWrites()
        NotificationCenter.default.post(name: .artworkLibraryGeaendert, object: nil)
    }

    private func geloeschtEingegangen(_ d: GalerieGeloeschtD) {
        guard let id = UUID(uuidString: d.artworkId) else { return }
        grabsteinSetzen(id, zeit: d.zeit) // sofort: schützt `standEingegangen` vor Wiederauferstehen
        bibliothekArbeit { [weak self] in self?.loeschenAnwenden(id, zeit: d.zeit) }
    }

    private func loeschenAnwenden(_ id: UUID, zeit: Date) {
        // Open in the Studio: keep it for now; the next launch's replay deletes it via the tombstone.
        guard offenesArtworkID != id, let lokal = library.document(id), zeit >= lokal.updatedAt else { return }
        library.removeWithoutSync(id)
        NotificationCenter.default.post(name: .artworkLibraryGeaendert, object: nil)
    }

    /// Schneller Start: Arbeit an der Bibliothek geht in die Kette (nach dem ersten Bild), sonst sofort wie vorher.
    private func bibliothekArbeit(_ arbeit: @escaping () -> Void) {
        if bibliothekSpaeter { reihen { arbeit() } } else { arbeit() }
    }

    private func projekteEingegangen(_ d: GalerieProjekteD, seq: Int?) {
        guard Self.istNeuer(seq: seq, letzte: UserDefaults.standard.object(forKey: Self.projekteSeqKey) as? Int) else { return }
        if let seq { UserDefaults.standard.set(seq, forKey: Self.projekteSeqKey) }
        let rang = Dictionary(d.reihenfolge.enumerated().map { ($1, $0) }, uniquingKeysWith: { erster, _ in erster })
        let geordnet = d.projekte.sorted { (rang[$0.id] ?? Int.max) < (rang[$1.id] ?? Int.max) }
        bibliothekArbeit { [weak self] in
            self?.library.applyRemoteProjects(geordnet)
            NotificationCenter.default.post(name: .artworkLibraryGeaendert, object: nil)
        }
    }

    private func stickerEingegangen(_ d: GalerieStickerD, seq: Int?) {
        guard Self.istNeuer(seq: seq, letzte: UserDefaults.standard.object(forKey: Self.stickerSeqKey) as? Int) else { return }
        if let seq { UserDefaults.standard.set(seq, forKey: Self.stickerSeqKey) }
        EigeneSticker.ersetzen(d.medienIds)
    }

    /// Old per-device Umzug import gave the very same drawing a different UUID on each device
    /// (design: duplicate detection over layer-content hashes + name). Finds a locally different-id
    /// artwork that is really this drawing, so the incoming stand replaces it instead of creating a
    /// second copy.
    private func duplikatID(fuer d: GalerieStandD, artworkId: UUID) -> UUID? {
        let eingehendeHashes = Set(d.dokument.layers.compactMap { d.dateien[$0.contentFile] }.compactMap(Self.hashSuffix))
        guard !eingehendeHashes.isEmpty else { return nil }
        for kandidat in library.artworks where kandidat.id != artworkId {
            let lokaleHashes = Set(kandidat.layers.compactMap {
                library.layerAsset(fileName: $0.contentFile, artworkID: kandidat.id).map(Self.hashHex)
            })
            if Self.istDuplikat(lokalerName: kandidat.name, lokaleHashes: lokaleHashes, eingehenderName: d.dokument.name, eingehendeHashes: eingehendeHashes) {
                return kandidat.id
            }
        }
        return nil
    }

    private func grabstein(_ id: UUID) -> Date? {
        (UserDefaults.standard.dictionary(forKey: Self.geloeschtKey)?[id.uuidString] as? Double)
            .map(Date.init(timeIntervalSince1970:))
    }

    private func grabsteinSetzen(_ id: UUID, zeit: Date) {
        var alle = UserDefaults.standard.dictionary(forKey: Self.geloeschtKey) ?? [:]
        let bisher = alle[id.uuidString] as? Double ?? 0
        alle[id.uuidString] = max(bisher, zeit.timeIntervalSince1970)
        UserDefaults.standard.set(alle, forKey: Self.geloeschtKey)
    }

    // MARK: - Pure logic (XCTest-covered without Raum/Medien/disk)

    /// A stand older than (or as old as) the drawing's deletion must not bring it back. A newer one
    /// (edited offline on the other device after the delete) does -- last write wins, as designed.
    nonisolated static func vonLoeschungUeberholt(geloeschtAm: Date?, updatedAt: Date) -> Bool {
        guard let geloeschtAm else { return false }
        return geloeschtAm >= updatedAt
    }

    enum AnwendenEntscheidung: Equatable { case anwenden, ueberspringen, zurueckstellen }

    /// "Offen im Studio" wins over freshness (design: hold back regardless, apply once it closes).
    /// Otherwise: missing locally, or strictly newer (`>`, so the sender's own echo of what it just
    /// wrote -- equal `updatedAt` -- is skipped instead of looping).
    nonisolated static func entscheidung(eingehendUpdatedAt: Date, lokalUpdatedAt: Date?, offenInStudio: Bool) -> AnwendenEntscheidung {
        if offenInStudio { return .zurueckstellen }
        guard let lokalUpdatedAt else { return .anwenden }
        return eingehendUpdatedAt > lokalUpdatedAt ? .anwenden : .ueberspringen
    }

    nonisolated static func istDuplikat(lokalerName: String, lokaleHashes: Set<String>, eingehenderName: String, eingehendeHashes: Set<String>) -> Bool {
        !eingehendeHashes.isEmpty && lokalerName == eingehenderName && lokaleHashes == eingehendeHashes
    }

    nonisolated static func istNeuer(seq: Int?, letzte: Int?) -> Bool {
        guard let seq else { return true } // this device's own just-sent (still optimistic) op
        guard let letzte else { return true }
        return seq > letzte
    }

    nonisolated static func medienId(person: Person, bytes: Data) -> String {
        "galerie-\(person.rawValue)-\(hashHex(bytes))"
    }

    nonisolated static func hashHex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The content hash out of a `"galerie-<person>-<hex>"` medium id, nil for anything else.
    nonisolated static func hashSuffix(_ medienId: String) -> String? {
        guard medienId.hasPrefix("galerie-") else { return nil }
        let rest = medienId.dropFirst("galerie-".count)
        guard let bindestrich = rest.firstIndex(of: "-") else { return nil }
        return String(rest[rest.index(after: bindestrich)...])
    }
}

struct GalerieStandD: Codable, Equatable, Sendable {
    let artworkId: String
    let dokument: ArtworkDocument
    let dateien: [String: String]
}

struct GalerieGeloeschtD: Codable, Sendable {
    let artworkId: String
    let zeit: Date
}

struct GalerieProjekteD: Codable, Sendable {
    let projekte: [ArtworkProject]
    let reihenfolge: [UUID]
}

struct GalerieStickerD: Codable, Sendable {
    let medienIds: [String]
}
