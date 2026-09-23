import Foundation

/// Z-11.2: imports the one-time `umzug.galerie` / `umzug.aufkleber` ops (Z-11.1, `server/umzug.mjs`)
/// as native drawings and own stickers. Registers a `Raum` observer for both kinds; each op is
/// only ever imported once (`op.id` tracked in UserDefaults) and only on the device of the person
/// who owned it (`op.von == Raum.shared.ich`) -- the op log is shared and both devices see every
/// op, but only the owner's device needs to materialize the media into its local library.
///
/// Known limitation, same as `ChatGalerie.inGaleriesSpeichern` (Chat/Medien/MedienBildView.swift):
/// this uses a fresh `ArtworkLibrary()` on the default root, the same file on disk `DrawingView`'s
/// `@StateObject ArtworkLibrary` uses -- an import survives and shows up there, but that tab's
/// already-open instance won't refresh until it re-`load()`s (or is recreated). Reported rather
/// than fixed here, since it's a Drawing/Library-wide instance-sharing question, not specific to
/// the umzug import.
@MainActor
final class UmzugImport {
    static let shared = UmzugImport()

    private static let arten: Set<String> = ["umzug.galerie", "umzug.aufkleber"]
    private static let importiertKey = "lovea.umzugImport.importiert"

    /// The default library root -- the same one `DrawingView`/the gallery opens.
    private let library = ArtworkLibrary()
    private var importiert: Set<String>
    /// Ops currently being imported this launch, so a duplicate delivery (Raum's contract: an
    /// op can arrive twice, optimistic + confirmed) doesn't start a second, concurrent import
    /// while the first is still downloading. Cleared implicitly on relaunch; a failed import is
    /// never removed from `importiert`, so it retries next launch regardless.
    private var laufend: Set<String> = []

    private init() {
        importiert = Set(UserDefaults.standard.stringArray(forKey: Self.importiertKey) ?? [])
        Raum.shared.beobachten(Self.arten) { [weak self] op in self?.eingehend(op) }
    }

    private func eingehend(_ op: Op) {
        guard op.von == Raum.shared.ich, !importiert.contains(op.id), laufend.insert(op.id).inserted else { return }
        switch op.art {
        case "umzug.galerie":
            guard let d = op.daten(GalerieOp.self) else { return }
            Task { @MainActor [weak self] in await self?.galerieImportieren(d, opId: op.id) }
        case "umzug.aufkleber":
            guard let d = op.daten(AufkleberOp.self) else { return }
            Task { @MainActor [weak self] in await self?.aufkleberImportieren(d, opId: op.id) }
        default:
            break
        }
    }

    /// One image layer per old canvas layer, downloaded via `Medien.holen`. Any single missing
    /// layer aborts the whole drawing (not marked imported) so a later launch retries it whole --
    /// a half-imported drawing with a missing layer would be worse than one retried once more.
    private func galerieImportieren(_ d: GalerieOp, opId: String) async {
        var geladen: [(layer: ArtworkLayer, bytes: Data)] = []
        for (index, ebene) in d.ebenen.enumerated() {
            guard let url = try? await Medien.holen(ebene.medienId),
                  let bytes = try? await Task.detached(priority: .utility, operation: { try Data(contentsOf: url) }).value
            else { return }
            geladen.append((UmzugMapping.layer(ebene, index: index), bytes))
        }
        guard !geladen.isEmpty else { return }

        var document = library.createArtwork(
            name: d.name ?? "",
            projectID: nil,
            format: UmzugMapping.format(d.format),
            background: UmzugMapping.background(d.papier)
        )
        document.layers = geladen.map { $0.layer }
        for (layer, bytes) in geladen { library.saveLayerData(bytes, layer: layer, artworkID: document.id) }
        library.saveDocument(document)
        // Written before marking imported: a kill between the two would otherwise leave the op
        // marked done with no file on disk, and it would never be retried.
        await library.waitForWrites()
        markiereImportiert(opId)
    }

    private func aufkleberImportieren(_ d: AufkleberOp, opId: String) async {
        guard (try? await Medien.holen(d.medienId)) != nil else { return }
        EigeneSticker.hinzufuegen(medienId: d.medienId) // writes its own JSON file synchronously
        markiereImportiert(opId)
    }

    private func markiereImportiert(_ opId: String) {
        importiert.insert(opId)
        UserDefaults.standard.set(Array(importiert), forKey: Self.importiertKey)
    }
}

/// `d` field names match `server/umzug.mjs` (`zeileZuEintraege`, `galerie/`/`aufkleber/` cases)
/// exactly. Every field but `medienId`/`ebenen` is optional: the old app filled in its own
/// defaults (`web/studio.js:107-108`) when a key was missing, and `JSON.stringify` drops
/// `undefined` keys entirely, so old rows can legitimately lack them.
struct GalerieOp: Decodable {
    struct Ebene: Decodable {
        let medienId: String
        let name: String?
        let deckkraft: Double?
        let modus: String?
        let clip: Bool?
        let schuetzt: Bool?
        let sichtbar: Bool?
    }
    let name: String?
    let format: String?
    let papier: String?
    let ebenen: [Ebene]
}

struct AufkleberOp: Decodable {
    let medienId: String
}

/// Pure old-web-app (`web/studio.js`) -> app mappings, kept separate from the I/O above so
/// `UmzugImportTests` can check them without a `Raum`/`ArtworkLibrary`.
enum UmzugMapping {
    /// One `ArtworkLayer` for one old canvas layer, with `studio.js`'s own defaults
    /// (`ebeneNeu`, line 107-108) for anything the old row didn't have.
    static func layer(_ ebene: GalerieOp.Ebene, index: Int) -> ArtworkLayer {
        var layer = ArtworkLayer.image(name: ebene.name ?? "Ebene \(index + 1)")
        layer.opacity = min(max(ebene.deckkraft ?? 1, 0), 1)
        layer.blendMode = blendMode(ebene.modus ?? "source-over")
        layer.clipping = ebene.clip ?? false
        layer.isLocked = ebene.schuetzt ?? false
        layer.isVisible = ebene.sichtbar ?? true
        return layer
    }

    static func blendMode(_ modus: String) -> LayerBlendMode {
        switch modus {
        case "source-over": .normal
        case "multiply": .multiply
        case "screen": .screen
        case "overlay": .overlay
        case "darken": .darken
        case "lighten": .lighten
        // ponytail: LayerBlendMode has no color-burn/color-dodge case, darken/lighten are the
        // closest direction match -- add real cases if the missing precision turns out to matter.
        case "color-burn": .darken
        case "color-dodge": .lighten
        case "lighter": .add
        case "soft-light": .softLight
        default: .normal
        }
    }

    static func format(_ id: String?) -> ArtworkFormat {
        switch id {
        case "quadrat": .square
        case "4-3": .landscape4x3
        case "3-4": .portrait3x4
        case "16-9": .landscape16x9
        case "9-16": .portrait9x16
        case "a4": .a4
        default: .landscape4x3 // matches the old app's formatVon fallback (FORMATE[1])
        }
    }

    static func background(_ papier: String?) -> CanvasBackground {
        switch papier {
        case "weiss": .white
        case "transparent": .transparent
        default: .dark // matches the old app's papierVon fallback (PAPIERE[0] = "dunkel")
        }
    }
}
