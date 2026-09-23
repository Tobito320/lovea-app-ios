@preconcurrency import Metal
import CoreGraphics
import Foundation

// Drawing Level 3: both people edit one drawing (Z-13.1 to Z-13.3).

/// Layer structure change as a diff, so it can be replayed on top of the partner's changes.
struct EbenenAenderung: Codable, Equatable, Sendable {
    struct Neu: Codable, Equatable, Sendable {
        var ebene: ArtworkLayer
        /// Layer directly below in the result, nil = bottom.
        var ueber: String?
        var medienId: String?
    }

    var neu: [Neu] = []
    var weg: [String] = []
    /// Changed properties, whole layer matched by id.
    var geaendert: [ArtworkLayer] = []
    /// Order of the kept layers (bottom first), only when it changed.
    var reihenfolge: [String]?

    init(von vorher: [ArtworkLayer], zu nachher: [ArtworkLayer]) {
        let alt = Dictionary(vorher.map { ($0.id, $0) }, uniquingKeysWith: { erster, _ in erster })
        let bleiben = Set(nachher.map(\.id))
        weg = vorher.filter { !bleiben.contains($0.id) }.map(\.id.uuidString)
        for (index, layer) in nachher.enumerated() {
            if let vorige = alt[layer.id] {
                if vorige != layer { geaendert.append(layer) }
            } else {
                neu.append(Neu(ebene: layer, ueber: index > 0 ? nachher[index - 1].id.uuidString : nil))
            }
        }
        let ordnungVorher = vorher.map(\.id).filter { bleiben.contains($0) }
        let ordnungNachher = nachher.map(\.id).filter { alt[$0] != nil }
        if ordnungVorher != ordnungNachher { reihenfolge = ordnungNachher.map(\.uuidString) }
    }

    var istLeer: Bool { neu.isEmpty && weg.isEmpty && geaendert.isEmpty && reihenfolge == nil }

    /// Layers the change touches besides adding: a partner lock on one of them rejects it.
    var betroffen: [String] { weg + geaendert.map(\.id.uuidString) }

    /// Applies the diff to whatever layers exist now. Unknown ids are skipped, so it also works
    /// after the partner changed the structure in between.
    func anwenden(auf layers: inout [ArtworkLayer]) {
        let wegIDs = Set(weg)
        layers.removeAll { wegIDs.contains($0.id.uuidString) }
        for layer in geaendert {
            if let index = layers.firstIndex(where: { $0.id == layer.id }) { layers[index] = layer }
        }
        if let reihenfolge {
            let rang = Dictionary(reihenfolge.enumerated().map { ($1, $0) }, uniquingKeysWith: { erster, _ in erster })
            let plaetze = layers.indices.filter { rang[layers[$0].id.uuidString] != nil }
            let sortiert = plaetze.map { layers[$0] }
                .sorted { (rang[$0.id.uuidString] ?? 0) < (rang[$1.id.uuidString] ?? 0) }
            for (platz, layer) in zip(plaetze, sortiert) { layers[platz] = layer }
        }
        for eintrag in neu where !layers.contains(where: { $0.id == eintrag.ebene.id }) {
            let index: Int
            if let ueber = eintrag.ueber {
                index = layers.firstIndex { $0.id.uuidString == ueber }.map { $0 + 1 } ?? layers.count
            } else {
                index = 0
            }
            layers.insert(eintrag.ebene, at: index)
        }
    }
}

/// Where a step acts. `ebene == nil`: the layer structure, or it reads every layer.
struct ZeichenBereich {
    static let alles = CGRect(x: -1e9, y: -1e9, width: 2e9, height: 2e9)

    var ebene: UUID?
    var rect: CGRect

    func trifft(_ anderer: ZeichenBereich) -> Bool {
        ebene == nil || anderer.ebene == nil || (ebene == anderer.ebene && rect.intersects(anderer.rect))
    }

    init(ebene: UUID?, rect: CGRect = ZeichenBereich.alles) {
        self.ebene = ebene
        self.rect = rect
    }

    init(_ schritt: UndoEntry) {
        switch schritt {
        case let .pixels(layerID, region, _, _):
            self.init(ebene: layerID, rect: CGRect(x: region.origin.x, y: region.origin.y, width: region.size.width, height: region.size.height))
        case .document:
            self.init(ebene: nil)
        }
    }

    /// Before an action ran: from its data, generously.
    init(_ aktion: ZeichnungAktion) {
        switch aktion {
        case let .strich(strich):
            let xs = strich.punkte.compactMap(\.first)
            let ys = strich.punkte.compactMap { $0.count > 1 ? $0[1] : nil }
            guard let layer = UUID(uuidString: strich.ebene), let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else {
                self.init(ebene: nil)
                return
            }
            var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -(strich.groesse + 4), dy: -(strich.groesse + 4))
            if let spiegel = strich.spiegel {
                rect = rect.union(CGRect(x: 2 * CGFloat(spiegel) - rect.maxX, y: rect.minY, width: rect.width, height: rect.height))
            }
            self.init(ebene: layer, rect: rect)
        case let .fuellen(_, _, _, _, alleEbenen, ebene):
            self.init(ebene: alleEbenen ? nil : UUID(uuidString: ebene))
        case let .pixel(ebene, x, y, breite, hoehe, _):
            self.init(ebene: UUID(uuidString: ebene), rect: CGRect(x: x, y: y, width: breite, height: hoehe))
        case .ebenen:
            self.init(ebene: nil)
        }
    }
}

/// History of one shared drawing: confirmed ops in `seq` order, then own unconfirmed ops.
/// Every step keeps the engine's undo data, so an op can be put in between or taken out later:
/// the later steps that overlap it are rolled back (region by region, newest first), then re-executed.
/// All of this is synchronous on the main actor, so no own input lands in the middle.
@MainActor
final class GemeinsamVerlauf {
    struct Eintrag {
        let id: String
        var seq: Int?
        let von: String
        var aktion: ZeichnungAktion
        /// Layer id → pixels for `.pixel` and the new layers of `.ebenen`. Only copied from, never drawn into.
        var texturen: [String: MTLTexture] = [:]
        /// Undo data of the last execution. Empty: undone, rejected, or it changed nothing.
        var schritte: [UndoEntry] = []
        var aus = false
        /// Own op the server hasn't confirmed yet. Always after every confirmed one.
        var offen = false

        var bytes: Int {
            schritte.reduce(0) { $0 + $1.bytes } + texturen.values.reduce(0) { $0 + $1.width * $1.height * 4 }
        }
    }

    let engine: CanvasEngine
    let ich: String
    let budget: Int
    private(set) var eintraege: [Eintrag] = []
    /// Highest `seq` contained.
    private(set) var basis: Int
    /// Own engine steps not yet claimed by an entry.
    private var puffer: [UndoEntry] = []
    /// Collects the steps while an entry executes.
    private var sammeln: [UndoEntry]?
    /// Own undone entries, newest last.
    private var wieder: [String] = []

    init(engine: CanvasEngine, ich: String, basis: Int, budget: Int = 256 << 20) {
        self.engine = engine
        self.ich = ich
        self.basis = basis
        self.budget = budget
        engine.undo.removeAll()
        engine.undo.umleiten = { [weak self] in self?.aufgenommen($0) }
    }

    /// True while an entry executes: the engine's `onAction` then is no own action.
    var wendetAn: Bool { sammeln != nil }
    var kannRueckgaengig: Bool { eintraege.contains { $0.von == ich && !$0.aus } }
    var kannWiederholen: Bool { !wieder.isEmpty }
    var offeneIDs: [String] { eintraege.filter(\.offen).map(\.id) }
    var hatOffene: Bool { eintraege.contains(where: \.offen) }

    func kennt(_ id: String) -> Bool {
        eintraege.contains { $0.id == id }
    }

    func eintrag(_ id: String) -> Eintrag? {
        eintraege.first { $0.id == id }
    }

    private func aufgenommen(_ schritt: UndoEntry) {
        if sammeln != nil {
            sammeln?.append(schritt)
        } else {
            puffer.append(schritt)
        }
    }

    // MARK: Own actions

    /// A finished own stroke: claims the step the engine just recorded.
    func eigene(_ aktion: ZeichnungAktion, offen: Bool) -> Eintrag? {
        guard !puffer.isEmpty else { return nil }
        let eintrag = Eintrag(id: UUID().uuidString, von: ich, aktion: aktion, schritte: puffer, offen: offen)
        puffer = []
        anhaengen(eintrag)
        return eintrag
    }

    /// Runs an own action through the same path as a replay (the fill), so both sides compute the same.
    func ausfuehrenEigene(_ aktion: ZeichnungAktion, offen: Bool) -> Eintrag? {
        eintraege.append(Eintrag(id: UUID().uuidString, von: ich, aktion: aktion, offen: offen))
        let index = eintraege.count - 1
        ausfuehren(index)
        guard !eintraege[index].schritte.isEmpty else {
            eintraege.removeLast()
            return nil
        }
        let eintrag = eintraege[index]
        eintraege.removeLast()
        anhaengen(eintrag)
        return eintrag
    }

    /// Every other own step since the last call, one entry each: pixels as `.pixel` (absolute, like
    /// a paste), layer changes as `.ebenen`. The sender fills in the medium ids after uploading.
    func eigeneSchritte(offen: Bool) -> [Eintrag] {
        let schritte = puffer
        puffer = []
        var neu: [Eintrag] = []
        for schritt in schritte {
            switch schritt {
            case let .pixels(layerID, region, _, after):
                neu.append(Eintrag(
                    id: UUID().uuidString, von: ich,
                    aktion: .pixel(ebene: layerID.uuidString, x: region.origin.x, y: region.origin.y,
                                   breite: region.size.width, hoehe: region.size.height, medienId: ""),
                    texturen: [layerID.uuidString: after], schritte: [schritt], offen: offen
                ))
            case let .document(before, after, _):
                let aenderung = EbenenAenderung(von: before.layers, zu: after.layers)
                guard !aenderung.istLeer else { continue }
                var texturen: [String: MTLTexture] = [:]
                for eintrag in aenderung.neu {
                    texturen[eintrag.ebene.id.uuidString] = engine.kopie(of: eintrag.ebene.id)
                }
                neu.append(Eintrag(id: UUID().uuidString, von: ich, aktion: .ebenen(aenderung), texturen: texturen,
                                   schritte: [schritt], offen: offen))
            }
        }
        for eintrag in neu { anhaengen(eintrag) }
        return neu
    }

    /// The op never reached the server (upload failed): no longer waiting for it.
    func nichtGesendet(_ id: String) {
        if let index = eintraege.firstIndex(where: { $0.id == id }) { eintraege[index].offen = false }
    }

    private func anhaengen(_ eintrag: Eintrag) {
        eintraege.append(eintrag)
        wieder.removeAll()
        kuerzen()
    }

    // MARK: Ops from the server

    /// A confirmed op. The own echo only confirms; anything else is placed by `seq`, in front of
    /// the own unconfirmed ops, which are rolled back and re-executed where they overlap.
    func empfangen(id: String, seq: Int, von: String, aktion: ZeichnungAktion, texturen: [String: MTLTexture]) {
        if let index = eintraege.firstIndex(where: { $0.id == id }) {
            eintraege[index].seq = seq
            eintraege[index].offen = false
            basis = max(basis, seq)
            return
        }
        guard seq > basis else { return }
        basis = seq
        let index = eintraege.firstIndex { $0.offen || ($0.seq ?? 0) > seq } ?? eintraege.count
        eintraege.insert(Eintrag(id: id, seq: seq, von: von, aktion: aktion, texturen: texturen), at: index)
        umbauen(ab: index + 1, zone: bereiche(eintraege[index])) { ausfuehren(index) }
        kuerzen()
    }

    /// An op this history leaves out (already in the loaded document).
    func basisErhoehen(_ seq: Int) {
        basis = max(basis, seq)
    }

    // MARK: Undo and redo (only own)

    /// Undoes the newest own step. Returns its id for `zeichnung.rueckgaengig`.
    func rueckgaengig() -> String? {
        guard let index = eintraege.lastIndex(where: { $0.von == ich && !$0.aus }) else { return nil }
        let id = eintraege[index].id
        umschalten(id, aus: true, von: ich)
        wieder.append(id)
        return id
    }

    func wiederholen() -> String? {
        guard let id = wieder.popLast(), umschalten(id, aus: false, von: ich) else { return nil }
        return id
    }

    /// Undo (`aus`) or redo of one step, only by its author, from anywhere in the history.
    /// False when the step isn't known here (made before this history started, or trimmed).
    @discardableResult
    func umschalten(_ id: String, aus: Bool, von: String) -> Bool {
        guard let index = eintraege.firstIndex(where: { $0.id == id && $0.von == von }) else { return false }
        guard eintraege[index].aus != aus else { return true }
        umbauen(ab: index + 1, zone: bereiche(eintraege[index])) {
            if aus {
                zurueck(index)
                eintraege[index].aus = true
            } else {
                eintraege[index].aus = false
                ausfuehren(index)
            }
        }
        return true
    }

    // MARK: Partner extras

    /// Radier-Alarm: a partner eraser at `x`/`y` (document pixels) touches one of my strokes on `ebene`.
    func trifftEigenenStrich(x: Double, y: Double, radius: Double, ebene: String) -> Bool {
        eintraege.contains { eintrag in
            guard eintrag.von == ich, !eintrag.aus, case let .strich(strich) = eintrag.aktion,
                  !strich.radierer, strich.ebene == ebene else { return false }
            let reichweite = radius + strich.groesse / 2
            return strich.punkte.contains { $0.count >= 2 && hypot($0[0] - x, $0[1] - y) <= reichweite }
        }
    }

    // MARK: Core

    /// Rolls back every entry from `start` on that overlaps `zone` (the zone grows with each one, since
    /// its undo data covers its own region), runs `mitte`, then re-executes them in order.
    private func umbauen(ab start: Int, zone: [ZeichenBereich], _ mitte: () -> Void) {
        var zone = zone
        var betroffen: [Int] = []
        if start < eintraege.count {
            for index in start..<eintraege.count where !eintraege[index].aus {
                let eigene = bereiche(eintraege[index])
                if eigene.contains(where: { bereich in zone.contains { $0.trifft(bereich) } }) {
                    betroffen.append(index)
                    zone += eigene
                }
            }
        }
        for index in betroffen.reversed() { zurueck(index) }
        mitte()
        for index in betroffen { ausfuehren(index) }
    }

    private func bereiche(_ eintrag: Eintrag) -> [ZeichenBereich] {
        [ZeichenBereich(eintrag.aktion)] + eintrag.schritte.map { ZeichenBereich($0) }
    }

    private func zurueck(_ index: Int) {
        for schritt in eintraege[index].schritte.reversed() { engine.apply(schritt, forward: false) }
        eintraege[index].schritte = []
    }

    private func ausfuehren(_ index: Int) {
        guard !eintraege[index].aus else { return }
        sammeln = []
        ausfuehrenOhneAufnahme(eintraege[index])
        eintraege[index].schritte = sammeln ?? []
        sammeln = nil
    }

    /// A layer locked by one person takes no op from the other (Z-13.3). Same decision on both
    /// phones, since both see the same layers at this point of the history.
    private func erlaubt(_ von: String, _ ebene: String) -> Bool {
        guard let id = UUID(uuidString: ebene), let sperre = engine.layer(id)?.gesperrtVon else { return true }
        return sperre == von
    }

    private func ausfuehrenOhneAufnahme(_ eintrag: Eintrag) {
        switch eintrag.aktion {
        case let .strich(strich):
            guard erlaubt(eintrag.von, strich.ebene) else { return }
            // A live stroke of the same id shows on its own scratch; the op lands it in seq order.
            if engine.hasRemoteStroke(strich.strichId) { engine.remoteCancel(id: strich.strichId) }
            var ganz = strich
            ganz.ende = true
            ganz.abbruch = nil
            ganz.anwenden(auf: engine, autor: eintrag.von)
        case let .fuellen(x, y, farbe, toleranz, alleEbenen, ebene):
            guard erlaubt(eintrag.von, ebene), let color = RGBAColor(hex8: farbe), let id = UUID(uuidString: ebene) else { return }
            engine.fillNow(at: CGPoint(x: x, y: y), color: color, tolerance: toleranz, allVisible: alleEbenen, layerID: id)
        case let .pixel(ebene, x, y, breite, hoehe, _):
            guard erlaubt(eintrag.von, ebene), let id = UUID(uuidString: ebene), engine.layer(id) != nil,
                  let textur = eintrag.texturen[ebene], textur.width == breite, textur.height == hoehe,
                  x >= 0, y >= 0, x + breite <= Int(engine.canvasSize.width), y + hoehe <= Int(engine.canvasSize.height)
            else { return }
            engine.editPixels(of: id, region: MTLRegionMake2D(x, y, breite, hoehe)) { command, target in
                GPU.copy(textur, to: target, at: MTLOrigin(x: x, y: y, z: 0), command: command)
            }
        case let .ebenen(aenderung):
            guard aenderung.betroffen.allSatisfy({ erlaubt(eintrag.von, $0) }) else { return }
            var texturen: [UUID: MTLTexture] = [:]
            for neu in aenderung.neu {
                if let textur = eintrag.texturen[neu.ebene.id.uuidString], let kopie = engine.kopie(textur) {
                    texturen[neu.ebene.id] = kopie
                } else if neu.ebene.kind == .paint, engine.texture(for: neu.ebene.id) == nil {
                    _ = engine.prepareTexture(for: neu.ebene)
                }
            }
            engine.updateDocument(removed: texturen) { aenderung.anwenden(auf: &$0.layers) }
        }
    }

    /// ponytail: keeps about `budget` bytes of undo data; older steps become permanent (no undo, no
    /// re-ordering behind them). A partner undo of such a step leaves the phones apart until the next stand.
    private func kuerzen() {
        var bytes = eintraege.reduce(0) { $0 + $1.bytes }
        while bytes > budget, let erster = eintraege.first, !erster.offen {
            bytes -= erster.bytes
            eintraege.removeFirst()
        }
    }
}
