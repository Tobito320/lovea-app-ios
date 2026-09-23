import CoreGraphics
import Foundation
import Observation

// MARK: Live messages (`fl`, never stored)

/// `strich.live`: points of one stroke, sent about every 33 ms. Every packet carries the full brush,
/// so a viewer who joins mid-stroke can still draw the rest.
struct LiveStrich: Codable, Sendable {
    var zeichnungId: String
    var strichId: String
    var ebene: String
    /// `BrushPreset` raw value.
    var werkzeug: String
    /// `#RRGGBBAA`. ponytail: 8 bit per channel, so a remote stroke can differ from the local one by 1/255
    /// in color; send the doubles if Block 13 needs bit-exact convergence.
    var farbe: String
    var groesse: Double
    /// `[x, y, druck, hoehe]` in document pixels; `hoehe` is the Pencil altitude.
    var punkte: [[Double]]
    var deckkraft: Double
    var druckGroesse: Bool
    var druckDeckkraft: Bool
    var ruhe: Int
    var radierer: Bool
    var spiegel: Double?
    /// First packet of the stroke.
    var anfang: Bool?
    /// The sender had a selection, so this stroke is clipped there and the viewer needs the next stand.
    var auswahl: Bool?
    var ende: Bool?
    var abbruch: Bool?

    init(zeichnungId: String, strichId: String, ebene: UUID, settings: BrushSettings, punkte: [StrokeInput],
         spiegel: Float?, auswahl: Bool, anfang: Bool, ende: Bool = false, abbruch: Bool = false) {
        self.zeichnungId = zeichnungId
        self.strichId = strichId
        self.ebene = ebene.uuidString
        werkzeug = settings.preset.rawValue
        farbe = settings.color.hex8
        groesse = settings.size
        self.punkte = punkte.map { [Double($0.location.x), Double($0.location.y), $0.pressure, $0.altitude] }
        deckkraft = settings.opacity
        druckGroesse = settings.pressureSize
        druckDeckkraft = settings.pressureOpacity
        ruhe = settings.stabilizer
        radierer = settings.isEraser
        self.spiegel = spiegel.map { Double($0) }
        self.anfang = anfang ? true : nil
        self.auswahl = auswahl ? true : nil
        self.ende = ende ? true : nil
        self.abbruch = abbruch ? true : nil
    }

    var pinsel: BrushSettings? {
        guard let preset = BrushPreset(rawValue: werkzeug), let color = RGBAColor(hex8: farbe) else { return nil }
        return BrushSettings(
            preset: preset, size: groesse, opacity: deckkraft, color: color,
            pressureSize: druckGroesse, pressureOpacity: druckDeckkraft, stabilizer: ruhe, isEraser: radierer
        )
    }

    var eingaben: [StrokeInput] {
        punkte.compactMap { p in
            guard p.count >= 2 else { return nil }
            return StrokeInput(
                location: CGPoint(x: p[0], y: p[1]),
                pressure: p.count > 2 ? p[2] : 1,
                altitude: p.count > 3 ? p[3] : .pi / 2
            )
        }
    }

    var istZuEnde: Bool { ende == true || abbruch == true }

    /// Feeds this packet into the engine's remote stroke with the same id.
    @MainActor
    func anwenden(auf engine: CanvasEngine, autor: String?) {
        var inputs = eingaben
        if !engine.hasRemoteStroke(strichId), !inputs.isEmpty, let settings = pinsel, let layerID = UUID(uuidString: ebene) {
            engine.remoteBegin(id: strichId, layerID: layerID, settings: settings, first: inputs.removeFirst(),
                               mirrorX: spiegel.map { Float($0) }, autor: autor)
        }
        if !inputs.isEmpty { engine.remoteContinue(id: strichId, inputs) }
        if abbruch == true {
            engine.remoteCancel(id: strichId)
        } else if ende == true {
            engine.remoteEnd(id: strichId)
        }
    }
}

/// `stift`: where the partner's pen is, in document pixels.
struct StiftNachricht: Codable, Equatable, Sendable {
    var zeichnungId: String
    var x: Double
    var y: Double
    /// `BrushPreset` raw value for the brush, else `StudioTool` raw value.
    var werkzeug: String
    var farbe: String
    var groesse: Double
    var schwebt: Bool
    var aktiv: Bool

    var symbol: String {
        switch werkzeug {
        case "pen", "gPen", "pencil": "pencil.tip"
        case "marker", "highlighter": "highlighter"
        case "airbrush", "watercolor": "paintbrush"
        case "eraser": "eraser"
        case "fill": "drop"
        case "lasso": "lasso"
        default: "paintbrush.pointed"
        }
    }
}

/// `zeichnung.drin`: which drawing someone has open, nil when they leave.
/// `antwort`: reply to an announce; never answered again, so the handshake stays two messages.
struct DrinNachricht: Codable, Sendable {
    var zeichnungId: String?
    var antwort: Bool?
}

/// `ansicht` (new fl kind, Level 2): the drawer's view, for "Folgen".
/// `x`/`y` is the document point in the screen center, `spanne` the document pixels across the short screen side.
struct AnsichtNachricht: Codable, Sendable {
    struct Transform: Codable, Equatable, Sendable {
        var x: Double
        var y: Double
        var spanne: Double
        var drehung: Double
    }

    var zeichnungId: String
    var transform: Transform
}

extension RGBAColor {
    var hex8: String {
        hex + String(format: "%02X", Int((min(max(alpha, 0), 1) * 255).rounded()))
    }

    init?(hex8: String) {
        guard hex8.count == 9, var color = RGBAColor(hex: String(hex8.prefix(7))),
              let alpha = UInt8(hex8.suffix(2), radix: 16) else { return nil }
        color.alpha = Double(alpha) / 255
        self = color
    }
}

// MARK: Hub

/// Receives the live messages once for the whole app and hands them to the open drawing.
@MainActor @Observable
final class LiveZeichnung {
    static let shared = LiveZeichnung()

    /// Drawing the partner has open, from `zeichnung.drin`.
    private(set) var partnerDrin: String?
    /// Partner pen to show, nil = hidden. Never the own pen: `fl` only goes to the partner.
    private(set) var partnerStift: StiftNachricht?
    /// Strong on purpose (no `weak` inside `@Observable`); `verlassen()` clears it. It holds the session only weakly.
    @ObservationIgnored var offen: ZeichnungLive?
    @ObservationIgnored private var stiftAus: Task<Void, Never>?

    private init() {
        let raum = Raum.shared
        raum.fluechtigBeobachten("zeichnung.drin") { [weak self] _, data in
            self?.drinEmpfangen((try? JSONDecoder().decode(DrinNachricht.self, from: data)) ?? DrinNachricht())
        }
        raum.fluechtigBeobachten("strich.live") { [weak self] _, data in
            guard let strich = try? JSONDecoder().decode(LiveStrich.self, from: data) else { return }
            self?.offen?.strichEmpfangen(strich)
        }
        raum.fluechtigBeobachten("stift") { [weak self] _, data in
            guard let stift = try? JSONDecoder().decode(StiftNachricht.self, from: data) else { return }
            self?.stiftZeigen(stift)
        }
        raum.fluechtigBeobachten("ansicht") { [weak self] _, data in
            guard let ansicht = try? JSONDecoder().decode(AnsichtNachricht.self, from: data) else { return }
            self?.offen?.ansichtEmpfangen(ansicht)
        }
    }

    /// The partner is online and has this drawing open. Gates all outgoing live traffic.
    func partnerIstDrin(_ zeichnungId: String) -> Bool {
        partnerDrin == zeichnungId && Raum.shared.partnerDa
    }

    private func drinEmpfangen(_ nachricht: DrinNachricht) {
        if nachricht.zeichnungId != partnerDrin { partnerStift = nil }
        partnerDrin = nachricht.zeichnungId
        // Answer every announce for the drawing open here, also a repeated one (the partner's app may
        // have restarted and forgotten us), so whoever came second knows the other one is there.
        if nachricht.antwort != true, let id = nachricht.zeichnungId, offen?.zeichnungId == id {
            Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: id, antwort: true))
        }
    }

    /// Shows the pen while it draws or hovers. An explicit "off" hides it after 0.3 s,
    /// silence after 1.5 s (lost connection).
    func stiftZeigen(_ stift: StiftNachricht) {
        guard stift.zeichnungId == offen?.zeichnungId else { return }
        let an = stift.aktiv || stift.schwebt
        if an { partnerStift = stift }
        stiftAus?.cancel()
        stiftAus = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(an ? 1500 : 300))
            guard !Task.isCancelled else { return }
            self?.partnerStift = nil
        }
    }
}

// MARK: One open drawing

/// Live side of one open drawing, both directions. The owner sends strokes, pen, view and actions;
/// a viewer receives them on top of the last stand. Block 13 lets both sides do both.
@MainActor
final class ZeichnungLive {
    let zeichnungId: String
    let nurAnsehen: Bool
    weak var session: DrawingSession?

    // Outgoing
    private var strich: (id: String, ebene: UUID, settings: BrushSettings, spiegel: Float?, auswahl: Bool)?
    private var punkte: [StrokeInput] = []
    private var istAnfang = false
    private var strichTask: Task<Void, Never>?
    private var letzterStift: TimeInterval = 0
    private var ansicht: AnsichtNachricht.Transform?
    private var ansichtTask: Task<Void, Never>?
    /// Last own stroke sent live. Goes into the next stand as `strich`.
    private(set) var letzterStrich: String?
    /// Set by the session right before `engine.fill`, so its `onAction` becomes `.fuellen`.
    var fuellung: ZeichnungAktion?

    // Incoming (viewer)
    /// Stand currently shown. Set by `GeteiltStudioView` before the studio opens.
    var geladen: ZeichnungStand?
    private var laufend: [String: [LiveStrich]] = [:]
    /// Finished partner strokes, oldest first, not yet known to be in `geladen`.
    private var fertig: [[LiveStrich]] = []
    private var angewendet: Set<String> = []
    /// Something happened that live data can't show (other action, selection-clipped or partial stroke).
    private var veraltet = true
    private var laedt = false
    private var wartenderStand: ZeichnungStand?
    /// Set once the studio appeared. Keeps a bare session (tests, previews) away from the network.
    private var geoeffnet = false

    init(zeichnungId: String, nurAnsehen: Bool) {
        self.zeichnungId = zeichnungId
        self.nurAnsehen = nurAnsehen
    }

    private var partnerSchaut: Bool {
        geoeffnet && !nurAnsehen && LiveZeichnung.shared.partnerIstDrin(zeichnungId)
    }

    private var autor: String? { Raum.shared.ich?.partner.rawValue }

    // MARK: Enter and leave

    func betreten() {
        geoeffnet = true
        LiveZeichnung.shared.offen = self
        FigurenModell.shared.zustandSenden(.init(haupt: .zeichnet))
        ankuendigen()
        guard let session else { return }
        if nurAnsehen {
            Task { [weak self] in
                await self?.session?.engine?.loading?.value
                self?.opsNachholen()
            }
        } else if TeilenModell.shared.stand.istGeteilt(session.document) {
            StandPaket.planen(session.document.id, library: session.library, strich: letzterStrich)
        }
    }

    /// Tells the partner this drawing is open. Again after a reconnect: `fl` without a socket is dropped.
    func ankuendigen() {
        guard geoeffnet, let session, nurAnsehen || TeilenModell.shared.stand.istGeteilt(session.document) else { return }
        Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: zeichnungId))
    }

    func verlassen() {
        strichTask?.cancel()
        ansichtTask?.cancel()
        if LiveZeichnung.shared.offen === self { LiveZeichnung.shared.offen = nil }
        Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: nil))
        FigurenModell.shared.zustandSenden(.init(haupt: .ruhig))
    }

    /// "Zum Mitzeichnen einladen": push and chat hint for the partner (server side), shares this drawing.
    func einladen() {
        guard !nurAnsehen, let session else { return }
        Raum.shared.senden("zeichnung.einladung", ZeichnungEinladung(zeichnungId: zeichnungId, name: session.document.name))
        Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: zeichnungId))
        StandPaket.planen(session.document.id, library: session.library, strich: letzterStrich)
    }

    // MARK: Outgoing (owner)

    func strichBeginnen(_ input: StrokeInput, settings: BrushSettings, ebene: UUID, spiegel: Float?, auswahl: Bool) {
        strichTask?.cancel()
        strichTask = nil
        guard partnerSchaut else {
            strich = nil
            return
        }
        strich = (UUID().uuidString, ebene, settings, spiegel, auswahl)
        punkte = [input]
        istAnfang = true
        strichPlanen()
    }

    func strichWeiter(_ inputs: [StrokeInput]) {
        guard strich != nil else { return }
        punkte += inputs
        strichPlanen()
    }

    func strichEnde(abbruch: Bool = false) {
        guard let aktuell = strich else { return }
        strichTask?.cancel()
        strichTask = nil
        strichSenden(ende: !abbruch, abbruch: abbruch)
        if !abbruch { letzterStrich = aktuell.id }
        strich = nil
    }

    private func strichPlanen() {
        guard strichTask == nil else { return }
        strichTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(33))
            guard !Task.isCancelled, let self else { return }
            self.strichTask = nil
            self.strichSenden(ende: false, abbruch: false)
        }
    }

    private func strichSenden(ende: Bool, abbruch: Bool) {
        guard let aktuell = strich, !punkte.isEmpty || ende || abbruch else { return }
        Raum.shared.fluechtig("strich.live", LiveStrich(
            zeichnungId: zeichnungId, strichId: aktuell.id, ebene: aktuell.ebene, settings: aktuell.settings,
            punkte: punkte, spiegel: aktuell.spiegel, auswahl: aktuell.auswahl, anfang: istAnfang,
            ende: ende, abbruch: abbruch
        ))
        punkte = []
        istAnfang = false
    }

    /// Pen position for tools without a live stroke, and Pencil hover. At most 30 per second,
    /// "off" always goes out. During a stroke the viewer takes the pen from `strich.live`.
    func stift(_ punkt: CGPoint, werkzeug: String, farbe: RGBAColor, groesse: Double, schwebt: Bool, aktiv: Bool) {
        guard partnerSchaut, strich == nil else { return }
        let jetzt = ProcessInfo.processInfo.systemUptime
        if schwebt || aktiv {
            guard jetzt - letzterStift >= 1.0 / 30 else { return }
        }
        letzterStift = jetzt
        Raum.shared.fluechtig("stift", StiftNachricht(
            zeichnungId: zeichnungId, x: Double(punkt.x), y: Double(punkt.y), werkzeug: werkzeug,
            farbe: farbe.hex8, groesse: groesse, schwebt: schwebt, aktiv: aktiv
        ))
    }

    /// Own view changed. Sent at most 10 times per second, the last state always.
    func ansichtGeaendert(_ viewport: ArtworkCanvasViewport, screen: CGSize) {
        guard partnerSchaut, screen.width > 0, screen.height > 0, viewport.scale > 0 else { return }
        let mitte = viewport.documentPoint(CGPoint(x: screen.width / 2, y: screen.height / 2))
        ansicht = AnsichtNachricht.Transform(
            x: Double(mitte.x), y: Double(mitte.y),
            spanne: Double(min(screen.width, screen.height) / viewport.scale), drehung: Double(viewport.rotation)
        )
        guard ansichtTask == nil else { return }
        ansichtTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            self.ansichtTask = nil
            if let transform = self.ansicht {
                Raum.shared.fluechtig("ansicht", AnsichtNachricht(zeichnungId: self.zeichnungId, transform: transform))
            }
        }
    }

    /// Engine `onAction`: one finished own non-stroke action.
    func aktionGeschehen() {
        let aktion = fuellung ?? .anderes
        fuellung = nil
        guard partnerSchaut else { return }
        // ponytail: only while the partner watches. Otherwise the next stand (≤ 30 s) carries the change.
        let basis = TeilenModell.shared.stand.letzteOpSeq[zeichnungId] ?? 0
        Raum.shared.senden("zeichnung.op", ZeichnungOp(zeichnungId: zeichnungId, basis: basis, aktion: aktion))
    }

    /// After every own autosave. `strich` is `letzterStrich` from before the save started.
    func gespeichert(strich: String?) {
        guard geoeffnet, !nurAnsehen, let session, TeilenModell.shared.stand.istGeteilt(session.document) else { return }
        StandPaket.planen(session.document.id, library: session.library, strich: strich)
    }

    // MARK: Incoming (viewer)

    func strichEmpfangen(_ strich: LiveStrich) {
        guard strich.zeichnungId == zeichnungId, let session, let engine = session.engine else { return }
        // The viewer's active layer follows the partner: keeps the compositor caches valid and shows the layer.
        if nurAnsehen, let layerID = UUID(uuidString: strich.ebene), session.activeLayerID != layerID,
           session.document.layers.contains(where: { $0.id == layerID }) {
            session.activeLayerID = layerID
        }
        if laufend[strich.strichId] == nil, strich.anfang != true { veraltet = true }
        if strich.auswahl == true { veraltet = true }
        laufend[strich.strichId, default: []].append(strich)
        strich.anwenden(auf: engine, autor: autor)
        if strich.istZuEnde {
            let pakete = laufend.removeValue(forKey: strich.strichId) ?? []
            if strich.abbruch != true { fertig.append(pakete) }
        }
        if let punkt = strich.punkte.last, punkt.count >= 2 {
            LiveZeichnung.shared.stiftZeigen(StiftNachricht(
                zeichnungId: zeichnungId, x: punkt[0], y: punkt[1],
                werkzeug: strich.radierer ? StudioTool.eraser.rawValue : strich.werkzeug,
                farbe: strich.farbe, groesse: strich.groesse, schwebt: false, aktiv: !strich.istZuEnde
            ))
        }
        session.requestRedraw()
    }

    func opEmpfangen(_ op: Op) {
        guard nurAnsehen, let seq = op.seq, seq > geladen?.basis ?? 0, let d = op.daten(ZeichnungOp.self),
              d.zeichnungId == zeichnungId, angewendet.insert(op.id).inserted else { return }
        switch d.aktion {
        case let .fuellen(x, y, farbe, toleranz, alleEbenen, ebene):
            guard let engine = session?.engine, let color = RGBAColor(hex8: farbe), let layerID = UUID(uuidString: ebene) else { return }
            Task {
                await engine.fill(at: CGPoint(x: x, y: y), color: color, tolerance: toleranz,
                                  reference: alleEbenen ? .allVisible : .activeLayer, layerID: layerID)
            }
        case .anderes:
            veraltet = true
        }
    }

    func ansichtEmpfangen(_ ansicht: AnsichtNachricht) {
        guard ansicht.zeichnungId == zeichnungId, let state = session?.canvasState, state.folgen else { return }
        state.canvas?.folgen(ansicht.transform)
    }

    /// A newer stand of this drawing. Reloads only when live data can't be trusted; live strokes
    /// keep the canvas current otherwise, and every reload downloads the changed layers again.
    func standEmpfangen(_ stand: ZeichnungStand) {
        guard nurAnsehen, stand.zeichnungId == zeichnungId, stand.medienId != geladen?.medienId else { return }
        if let id = stand.strich, let index = fertig.firstIndex(where: { $0.first?.strichId == id }) {
            fertig.removeFirst(index + 1)
        }
        guard veraltet else { return }
        guard !laedt else {
            wartenderStand = stand
            return
        }
        Task { await laden(stand) }
    }

    private func laden(_ stand: ZeichnungStand) async {
        guard let session, let engine = session.engine else { return }
        laedt = true
        if let document = try? await StandPaket.laden(stand, into: session.library) {
            await engine.reload(document)
            geladen = stand
            veraltet = false
            angewendet = []
            // Strokes that finished after the stand was saved, then the actions after its basis.
            for pakete in fertig {
                for paket in pakete { paket.anwenden(auf: engine, autor: autor) }
            }
            opsNachholen()
            session.requestRedraw()
        }
        laedt = false
        if let naechster = wartenderStand {
            wartenderStand = nil
            standEmpfangen(naechster)
        }
    }

    private func opsNachholen() {
        guard nurAnsehen else { return }
        for op in TeilenModell.shared.stand.ops(nach: geladen?.basis ?? 0, zeichnungId: zeichnungId) { opEmpfangen(op) }
    }
}
