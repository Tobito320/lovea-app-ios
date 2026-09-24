import CoreGraphics
import Foundation
@preconcurrency import Metal
import Observation
import UIKit

// MARK: Live messages (`fl`, never stored)

/// `strich.live`: points of one stroke, sent about every 33 ms. Every packet carries the full brush,
/// so a viewer who joins mid-stroke can still draw the rest.
struct LiveStrich: Codable, Equatable, Sendable {
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
    /// The sender had a selection, so this stroke is clipped there; it lands as a `.pixel` op instead.
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
        // C-1: a tenth of a pixel and a thousandth of pressure make a stroke op about three times smaller.
        // ponytail: the replay can differ from the local stroke by up to 0.05 px; send the exact doubles
        // again if bit-exact convergence between the phones ever matters.
        self.punkte = punkte.map {
            [Self.runden(Double($0.location.x), 10), Self.runden(Double($0.location.y), 10),
             Self.runden($0.pressure, 1000), Self.runden($0.altitude, 100)]
        }
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

    private static func runden(_ wert: Double, _ faktor: Double) -> Double {
        (wert * faktor).rounded() / faktor
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

/// `emoji`: floats up where it was put for 2 s, never part of the drawing.
struct EmojiNachricht: Codable, Sendable {
    var zeichnungId: String
    var x: Double
    var y: Double
    var e: String
}

/// `fertig` and `stupser`.
struct ZeichnungNachricht: Codable, Sendable {
    var zeichnungId: String
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
/// Also holds the extras of Spec 10.3 for the overlays.
@MainActor @Observable
final class LiveZeichnung {
    static let shared = LiveZeichnung()

    struct SchwebendesEmoji: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let e: String
    }

    /// Drawing the partner has open, from `zeichnung.drin`.
    private(set) var partnerDrin: String?
    /// Partner pen to show, nil = hidden. Never the own pen: `fl` only goes to the partner.
    private(set) var partnerStift: StiftNachricht?
    private(set) var emojis: [SchwebendesEmoji] = []
    /// Heart spark where the pens met, document pixels.
    private(set) var kuss: CGPoint?
    private(set) var ichFertig = false
    private(set) var partnerFertig = false
    private(set) var konfetti = false
    /// Counts the partner's pokes; the overlay wiggles the own pen on every change.
    private(set) var stupser = 0
    /// The partner's eraser is on one of my strokes.
    private(set) var radierAlarm = false
    /// Own pen tip in document pixels, the last one also after lifting (where the poke wiggles).
    @ObservationIgnored private(set) var letzterEigenerStift: CGPoint?
    @ObservationIgnored private var eigenerStift: CGPoint?
    @ObservationIgnored private var letzterKuss: TimeInterval = -10
    @ObservationIgnored private var alarmAus: Task<Void, Never>?
    /// Strong on purpose (no `weak` inside `@Observable`); `verlassen()` clears it. It holds the session only weakly.
    @ObservationIgnored var offen: ZeichnungLive? {
        didSet {
            guard offen !== oldValue else { return }
            ichFertig = false
            partnerFertig = false
        }
    }
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
        raum.fluechtigBeobachten("emoji") { [weak self] _, data in
            guard let emoji = try? JSONDecoder().decode(EmojiNachricht.self, from: data) else { return }
            self?.emojiZeigen(emoji)
        }
        raum.fluechtigBeobachten("fertig") { [weak self] _, data in
            guard let self, let nachricht = try? JSONDecoder().decode(ZeichnungNachricht.self, from: data),
                  nachricht.zeichnungId == self.offen?.zeichnungId else { return }
            self.partnerFertig = true
            self.fertigPruefen()
        }
        raum.fluechtigBeobachten("stupser") { [weak self] _, data in
            guard let self, let nachricht = try? JSONDecoder().decode(ZeichnungNachricht.self, from: data),
                  nachricht.zeichnungId == self.offen?.zeichnungId else { return }
            self.stupser += 1
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    /// The partner is online and has this drawing open. Gates all outgoing live traffic.
    func partnerIstDrin(_ zeichnungId: String) -> Bool {
        partnerDrin == zeichnungId && Raum.shared.partnerDa
    }

    private func drinEmpfangen(_ nachricht: DrinNachricht) {
        if nachricht.zeichnungId != partnerDrin {
            partnerStift = nil
            partnerFertig = false
        }
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
        if an {
            partnerStift = stift
            kussPruefen()
        }
        stiftAus?.cancel()
        stiftAus = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(an ? 1500 : 300))
            guard !Task.isCancelled else { return }
            self?.partnerStift = nil
        }
    }

    // MARK: Extras (Spec 10.3)

    func emojiZeigen(_ nachricht: EmojiNachricht) {
        guard nachricht.zeichnungId == offen?.zeichnungId else { return }
        let emoji = SchwebendesEmoji(x: nachricht.x, y: nachricht.y, e: String(nachricht.e.prefix(4)))
        let id = emoji.id
        emojis.append(emoji)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.emojis.removeAll { $0.id == id }
        }
    }

    /// Own pen while it draws or hovers, nil when lifted.
    func eigenerStiftSetzen(_ punkt: CGPoint?) {
        eigenerStift = punkt
        if let punkt {
            letzterEigenerStift = punkt
            kussPruefen()
        }
    }

    /// Stifte küssen: both pens closer than 12 pt on this screen. Both phones check on their own,
    /// since both know both pens. At most every 5 s.
    private func kussPruefen() {
        guard let eigen = eigenerStift, let partner = partnerStift,
              let scale = offen?.session?.canvasState.viewport.scale else { return }
        let andere = CGPoint(x: partner.x, y: partner.y)
        let jetzt = ProcessInfo.processInfo.systemUptime
        guard hypot(eigen.x - andere.x, eigen.y - andere.y) * scale < 12, jetzt - letzterKuss >= 5 else { return }
        letzterKuss = jetzt
        kuss = CGPoint(x: (eigen.x + andere.x) / 2, y: (eigen.y + andere.y) / 2)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            self?.kuss = nil
        }
    }

    func fertigDruecken() {
        guard let offen else { return }
        ichFertig = true
        Raum.shared.fluechtig("fertig", ZeichnungNachricht(zeichnungId: offen.zeichnungId))
        fertigPruefen()
    }

    /// Both pressed "Fertig": confetti on both phones, the owner sends the picture to the chat.
    private func fertigPruefen() {
        guard ichFertig, partnerFertig, let offen else { return }
        ichFertig = false
        partnerFertig = false
        konfetti = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        offen.gemeinsamFertig()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            self?.konfetti = false
        }
    }

    /// Radier-Alarm: shows the guilty eraser for a moment.
    func radiert() {
        radierAlarm = true
        alarmAus?.cancel()
        alarmAus = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.radierAlarm = false
        }
    }
}

// MARK: One open drawing

/// Live side of one open drawing, both directions: strokes, pen and view go out as `fl`, every
/// finished action as `zeichnung.op`; incoming ops go through the shared history in `seq` order.
@MainActor
final class ZeichnungLive {
    let zeichnungId: String
    /// The partner's drawing (shared library): never saved or published from here.
    let fremd: Bool
    weak var session: DrawingSession?
    /// Shared history, from the moment the drawing is shared or a partner drawing opens.
    private(set) var verlauf: GemeinsamVerlauf?

    // Outgoing
    private var strich: (id: String, ebene: UUID, settings: BrushSettings, spiegel: Float?, auswahl: Bool)?
    /// The whole current stroke, for its op.
    private var alle: [StrokeInput] = []
    /// Points not yet sent live.
    private var punkte: [StrokeInput] = []
    private var istAnfang = false
    private var strichTask: Task<Void, Never>?
    private var letzterStift: TimeInterval = 0
    private var ansicht: AnsichtNachricht.Transform?
    private var ansichtTask: Task<Void, Never>?
    /// Own ops leave strictly in canvas order; a pixel op waits for its upload.
    private var sendeKette: Task<Void, Never>?

    // Incoming
    /// Stand currently shown (partner drawing). Set by `GeteiltStudioView` before the studio opens.
    var geladen: ZeichnungStand?
    private var eingangKette: Task<Void, Never>?
    /// Own ops the loaded document contains although they were unconfirmed at saving.
    private var ausgelassen: Set<String> = []
    /// Live strokes already landed by their op; late packets are dropped.
    private var gelandet: Set<String> = []
    /// The canvas may miss something (view-only share, unknown undo, failed download): take the next stand.
    private var veraltet = false
    private var laedt = false
    private var wartenderStand: ZeichnungStand?
    private var aktiviert = false
    /// Set once the studio appeared. Keeps a bare session (tests, previews) away from the network.
    private var geoeffnet = false

    init(zeichnungId: String, fremd: Bool) {
        self.zeichnungId = zeichnungId
        self.fremd = fremd
    }

    private var darf: Bool {
        guard let session else { return false }
        return TeilenModell.shared.stand.darfBearbeiten(zeichnungId: zeichnungId, projektId: session.document.projectID?.uuidString)
    }

    /// Partner drawing without the right to edit: tools locked.
    var nurAnsehen: Bool { fremd && !darf }

    private var geteilt: Bool {
        guard let session else { return false }
        return fremd || TeilenModell.shared.stand.istGeteilt(session.document)
    }

    private var partnerSchaut: Bool {
        geoeffnet && !nurAnsehen && LiveZeichnung.shared.partnerIstDrin(zeichnungId)
    }

    /// Own actions become ops: always when the partner may edit (the op log is the truth then),
    /// otherwise only while the partner watches; the next stand carries the rest.
    private var sendetOps: Bool {
        guard geoeffnet else { return false }
        if fremd { return darf }
        return geteilt && (darf || LiveZeichnung.shared.partnerIstDrin(zeichnungId))
    }

    private var autor: String? { Raum.shared.ich?.partner.rawValue }

    // MARK: Enter and leave

    func betreten() {
        geoeffnet = true
        LiveZeichnung.shared.offen = self
        FigurenModell.shared.zustandSenden(.init(haupt: .zeichnet))
        ankuendigen()
        guard let session else { return }
        // View-only: the owner sends no ops while nobody watches, so the stand may be behind.
        // Offline copy: the fold may have dropped ops it misses. Both take the next stand.
        veraltet = nurAnsehen || (fremd && geladen == nil)
        if geteilt { aktivieren() }
        if !fremd, geteilt { StandPaket.planen(session.document.id, library: session.library) }
    }

    /// Tells the partner this drawing is open. Again after a reconnect: `fl` without a socket is dropped.
    func ankuendigen() {
        guard geoeffnet, geteilt else { return }
        Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: zeichnungId))
    }

    func verlassen() {
        strichTask?.cancel()
        ansichtTask?.cancel()
        if LiveZeichnung.shared.offen === self { LiveZeichnung.shared.offen = nil }
        Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: nil))
        Anwesenheit.shared.appEnde(.zeichnet)
    }

    /// "Zum Mitzeichnen einladen": push (server side) and chat line (`ChatModell` folds the op), shares this drawing to edit.
    func einladen() {
        guard !fremd, let session else { return }
        Raum.shared.senden("zeichnung.einladung", ZeichnungEinladung(zeichnungId: zeichnungId, name: session.document.name))
        TeilenModell.shared.bearbeitenErlauben(session.document.id, true)
        Raum.shared.fluechtig("zeichnung.drin", DrinNachricht(zeichnungId: zeichnungId))
        aktivieren()
        StandPaket.planen(session.document.id, library: session.library)
    }

    /// Starts the shared history once the canvas is loaded.
    /// ponytail: Level 1 undo steps from before sharing are dropped.
    private func aktivieren() {
        guard !aktiviert else { return }
        aktiviert = true
        Task { [weak self] in
            await self?.session?.engine?.loading?.value
            self?.verlaufStarten()
        }
    }

    /// New history on the document as loaded, then the ops after its basis (without the owner's
    /// ops it already contained unconfirmed).
    private func verlaufStarten() {
        guard let engine = session?.engine, let ich = Raum.shared.ich else { return }
        let basis = engine.document.basis ?? 0
        verlauf = GemeinsamVerlauf(engine: engine, ich: ich.rawValue, basis: basis)
        ausgelassen = Set(engine.document.offen ?? [])
        for op in TeilenModell.shared.stand.ops(nach: basis, zeichnungId: zeichnungId) { opEmpfangen(op) }
        session?.requestRedraw()
    }

    // MARK: Outgoing strokes

    func strichBeginnen(_ input: StrokeInput, settings: BrushSettings, ebene: UUID, spiegel: Float?, auswahl: Bool) {
        LiveZeichnung.shared.eigenerStiftSetzen(input.location)
        strichTask?.cancel()
        strichTask = nil
        guard verlauf != nil || partnerSchaut else {
            strich = nil
            return
        }
        strich = (UUID().uuidString, ebene, settings, spiegel, auswahl)
        alle = [input]
        punkte = [input]
        istAnfang = true
        if partnerSchaut { strichPlanen() }
    }

    func strichWeiter(_ inputs: [StrokeInput]) {
        if let punkt = inputs.last?.location { LiveZeichnung.shared.eigenerStiftSetzen(punkt) }
        guard strich != nil else { return }
        alle += inputs
        punkte += inputs
        if partnerSchaut { strichPlanen() }
    }

    func strichEnde(abbruch: Bool = false) {
        LiveZeichnung.shared.eigenerStiftSetzen(nil)
        guard let aktuell = strich else { return }
        strichTask?.cancel()
        strichTask = nil
        if partnerSchaut { strichSenden(ende: !abbruch, abbruch: abbruch) }
        strich = nil
        guard !abbruch, let verlauf else { return }
        // Clipped by the own selection: the replay can't know it, so the pixels travel instead.
        guard !aktuell.auswahl else {
            aktionGeschehen()
            return
        }
        let ganz = LiveStrich(
            zeichnungId: zeichnungId, strichId: aktuell.id, ebene: aktuell.ebene, settings: aktuell.settings,
            punkte: alle, spiegel: aktuell.spiegel, auswahl: false, anfang: true, ende: true
        )
        alle = []
        let mitSenden = sendetOps
        if let eintrag = verlauf.eigene(.strich(ganz), offen: mitSenden), mitSenden { senden(eintrag.id) }
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
        LiveZeichnung.shared.eigenerStiftSetzen(schwebt || aktiv ? punkt : nil)
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

    // MARK: Outgoing actions

    /// Engine `onAction` and shape outlines: the own non-stroke steps since the last call.
    func aktionGeschehen() {
        guard let verlauf, !verlauf.wendetAn else { return }
        let mitSenden = sendetOps
        for eintrag in verlauf.eigeneSchritte(offen: mitSenden) where mitSenden { senden(eintrag.id) }
    }

    /// Own fill in a shared drawing: runs through the history, so it is computed like the replays.
    func fuellen(_ aktion: ZeichnungAktion) {
        guard let verlauf else { return }
        let mitSenden = sendetOps
        if let eintrag = verlauf.ausfuehrenEigene(aktion, offen: mitSenden), mitSenden { senden(eintrag.id) }
    }

    /// Undo or redo of the newest own step, for everyone (Z-13.2).
    func rueckgaengig(wieder: Bool) {
        guard let verlauf, let id = wieder ? verlauf.wiederholen() : verlauf.rueckgaengig(), sendetOps else { return }
        let vorher = sendeKette
        sendeKette = Task { [zeichnungId] in
            await vorher?.value
            Raum.shared.senden("zeichnung.rueckgaengig", ZeichnungRueckgaengig(zeichnungId: zeichnungId, opId: id, wieder: wieder ? true : nil))
        }
    }

    private func senden(_ id: String) {
        let basis = verlauf?.basis ?? 0
        let vorher = sendeKette
        sendeKette = Task { [weak self, zeichnungId] in
            await vorher?.value
            guard let eintrag = self?.verlauf?.eintrag(id) else { return }
            do {
                let aktion = try await StandPaket.medienHochladen(eintrag.aktion, texturen: eintrag.texturen)
                Raum.shared.senden("zeichnung.op", ZeichnungOp(id: id, zeichnungId: zeichnungId, basis: basis, aktion: aktion))
            } catch {
                // ponytail: no retry; the partner misses this step until the next stand.
                self?.verlauf?.nichtGesendet(id)
            }
        }
    }

    /// After every own autosave.
    func gespeichert() {
        guard geoeffnet, !fremd, let session, geteilt else { return }
        StandPaket.planen(session.document.id, library: session.library)
    }

    // MARK: Extras

    func emojiSenden(_ punkt: CGPoint, _ e: String) {
        let nachricht = EmojiNachricht(zeichnungId: zeichnungId, x: Double(punkt.x), y: Double(punkt.y), e: e)
        LiveZeichnung.shared.emojiZeigen(nachricht)
        Raum.shared.fluechtig("emoji", nachricht)
    }

    func anstupsen() {
        Raum.shared.fluechtig("stupser", ZeichnungNachricht(zeichnungId: zeichnungId))
    }

    /// Both pressed "Fertig": the owner sends the picture to the chat, so it arrives once.
    func gemeinsamFertig() {
        guard !fremd, let engine = session?.engine else { return }
        Task {
            try? await StandPaket.alsBildSenden(engine, text: "Gemeinsam gemalt von Ahmed & Annika")
        }
    }

    // MARK: Incoming

    func strichEmpfangen(_ strich: LiveStrich) {
        guard strich.zeichnungId == zeichnungId, !gelandet.contains(strich.strichId),
              let session, let engine = session.engine else { return }
        // The viewer's active layer follows the partner: keeps the compositor caches valid and shows the layer.
        if nurAnsehen, let layerID = UUID(uuidString: strich.ebene), session.activeLayerID != layerID,
           session.document.layers.contains(where: { $0.id == layerID }) {
            session.activeLayerID = layerID
        }
        if strich.abbruch == true {
            engine.remoteCancel(id: strich.strichId)
        } else {
            // Shown on its own scratch; it lands with its op, in seq order.
            var paket = strich
            paket.ende = nil
            paket.anwenden(auf: engine, autor: autor)
        }
        if let punkt = strich.punkte.last, punkt.count >= 2 {
            if strich.radierer, !strich.istZuEnde,
               verlauf?.trifftEigenenStrich(x: punkt[0], y: punkt[1], radius: strich.groesse / 2, ebene: strich.ebene) == true {
                LiveZeichnung.shared.radiert()
            }
            LiveZeichnung.shared.stiftZeigen(StiftNachricht(
                zeichnungId: zeichnungId, x: punkt[0], y: punkt[1],
                werkzeug: strich.radierer ? StudioTool.eraser.rawValue : strich.werkzeug,
                farbe: strich.farbe, groesse: strich.groesse, schwebt: false, aktiv: !strich.istZuEnde
            ))
        }
        session.requestRedraw()
    }

    /// `zeichnung.op` and `zeichnung.rueckgaengig` of this drawing, own echoes included, one after the other.
    func opEmpfangen(_ op: Op) {
        // Before the history starts, its catch-up picks everything up from the fold.
        guard let seq = op.seq, verlauf != nil else { return }
        let vorher = eingangKette
        eingangKette = Task { [weak self] in
            await vorher?.value
            await self?.verarbeiten(op, seq: seq)
        }
    }

    private func verarbeiten(_ op: Op, seq: Int) async {
        guard let verlauf else { return }
        let von = op.von.rawValue
        if op.art == "zeichnung.rueckgaengig" {
            guard let d = op.daten(ZeichnungRueckgaengig.self), d.zeichnungId == zeichnungId else { return }
            if !verlauf.umschalten(d.opId, aus: d.wieder != true, von: von) { veraltet = true }
            verlauf.basisErhoehen(seq)
        } else {
            guard let d = op.daten(ZeichnungOp.self), d.zeichnungId == zeichnungId else { return }
            let bekannt = verlauf.kennt(d.id)
            if ausgelassen.contains(d.id) || (!bekannt && seq <= verlauf.basis) {
                verlauf.basisErhoehen(seq)
                return
            }
            var texturen: [String: MTLTexture] = [:]
            if !bekannt {
                do {
                    texturen = try await StandPaket.medienLaden(d.aktion)
                } catch {
                    // ponytail: the owner has no stand to fall back on; the step stays missing there.
                    veraltet = true
                    return
                }
            }
            // A stand reload may have replaced the history meanwhile.
            self.verlauf?.empfangen(id: d.id, seq: seq, von: von, aktion: d.aktion, texturen: texturen)
            if case let .strich(strich) = d.aktion { gelandet.insert(strich.strichId) }
        }
        session?.requestRedraw()
    }

    func ansichtEmpfangen(_ ansicht: AnsichtNachricht) {
        guard ansicht.zeichnungId == zeichnungId, let state = session?.canvasState, state.folgen else { return }
        state.canvas?.folgen(ansicht.transform)
    }

    /// A newer stand of the partner's drawing. Reloads only when the canvas may miss something and
    /// no own step is still on its way; otherwise the ops keep it current.
    func standEmpfangen(_ stand: ZeichnungStand) {
        guard fremd, stand.zeichnungId == zeichnungId, stand.medienId != geladen?.medienId, veraltet else { return }
        guard !laedt else {
            wartenderStand = stand
            return
        }
        Task { await laden(stand) }
    }

    private func laden(_ stand: ZeichnungStand) async {
        guard let session, let engine = session.engine else { return }
        laedt = true
        if let document = try? await StandPaket.laden(stand, into: session.library),
           !(verlauf?.hatOffene ?? false), !engine.isStroking {
            await engine.reload(document)
            geladen = stand
            veraltet = false
            gelandet = []
            verlaufStarten()
            session.requestRedraw()
        }
        laedt = false
        if let naechster = wartenderStand {
            wartenderStand = nil
            standEmpfangen(naechster)
        }
    }
}
