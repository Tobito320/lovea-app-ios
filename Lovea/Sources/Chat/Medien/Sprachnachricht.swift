import AVFoundation
import SwiftUI
import UIKit

// MARK: - State machine (pure, tested)

/// Voice recording (voice round): idle → recording ⇄ review (paused) → sending.
enum SprachPhase: Equatable, Sendable {
    case bereit, nimmtAuf, pruefen, sendet
}

enum SprachEreignis: Sendable {
    /// Start, or continue after a pause (the new part is appended).
    case aufnehmen
    /// The pause button.
    case pausieren
    /// A call, Siri, another app, a lost route, the app leaving the foreground, the length cap.
    case unterbrechung
    /// Only the send button, or letting go in hold-to-talk. Nothing else ever sends.
    case senden
    case verwerfen
    case gesendet
}

enum SprachAblauf {
    /// An interruption can only ever pause; `.sendet` is reachable through `.senden` alone.
    static func weiter(_ phase: SprachPhase, _ ereignis: SprachEreignis) -> SprachPhase {
        switch (phase, ereignis) {
        case (.bereit, .aufnehmen), (.pruefen, .aufnehmen): .nimmtAuf
        case (.nimmtAuf, .pausieren), (.nimmtAuf, .unterbrechung): .pruefen
        case (.nimmtAuf, .senden), (.pruefen, .senden): .sendet
        case (.bereit, .verwerfen), (.nimmtAuf, .verwerfen), (.pruefen, .verwerfen): .bereit
        case (.sendet, .gesendet): .bereit
        default: phase
        }
    }
}

// MARK: - Recorder

/// `AVAudioRecorder` in segments (voice round): pausing finishes the current segment, so what was
/// recorded is kept, playable and can be continued; review and sending join the segments into one
/// `.m4a`. Interruptions pause, they never send.
@MainActor
@Observable
final class AufnahmeSteuerung {
    private(set) var laeuft = false
    /// All finished segments plus the running one.
    private(set) var dauer: TimeInterval = 0
    /// Normalized 0…1, the newest ~48 samples, for the live waveform.
    private(set) var pegelLive: [Float] = []
    @ObservationIgnored var onUnterbrochen: (() -> Void)?

    @ObservationIgnored private var segmente: [URL] = []
    @ObservationIgnored private var dauerBisher: TimeInterval = 0
    @ObservationIgnored private var pegelRoh: [Float] = []
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var aktuellesSegment: URL?
    @ObservationIgnored private var messTask: Task<Void, Never>?
    @ObservationIgnored private var beobachtet = false

    /// ponytail: length cap; it pauses (never sends).
    static let hoechstDauer: TimeInterval = 300

    var hatAufnahme: Bool { !segmente.isEmpty || laeuft }

    /// Starts or continues. Stops any playing voice message first, then sets `.playAndRecord` and
    /// waits until the session is active before the recorder starts. `basis` continues a restored
    /// draft or review file.
    func start(basis: SprachEntwurf? = nil) async -> Bool {
        SprachSpieler.shared.parken()
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        guard await Self.sitzungAktivieren() else { return false }
        beobachtenFallsNoetig()
        if let basis, segmente.isEmpty {
            segmente = [basis.url]
            dauerBisher = basis.dauer
            pegelRoh = basis.pegel.map { $0 * 50 - 50 } // back to dB, see `Wellenform`
        }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let einstellungen: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let neuer = try? AVAudioRecorder(url: ziel, settings: einstellungen) else { return false }
        neuer.isMeteringEnabled = true
        guard neuer.record() else { return false }
        recorder = neuer
        aktuellesSegment = ziel
        laeuft = true
        FigurenModell.shared.zustandSenden(.init(haupt: .sprache))
        messTask = Task { [weak self] in
            while let self, self.laeuft, !Task.isCancelled {
                guard let recorder = self.recorder else { return }
                recorder.updateMeters()
                let dB = recorder.averagePower(forChannel: 0)
                self.pegelRoh.append(dB)
                self.pegelLive = Array((self.pegelLive + [Wellenform.downsample([dB], ziel: 1).first ?? 0]).suffix(48))
                self.dauer = self.dauerBisher + recorder.currentTime
                if self.dauer >= Self.hoechstDauer { self.unterbrochen() }
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
        return true
    }

    /// Finishes the running segment; everything recorded so far is kept.
    func pausieren() {
        guard laeuft, let recorder else { return }
        dauerBisher += recorder.currentTime
        recorder.stop()
        if let aktuellesSegment { segmente.append(aktuellesSegment) }
        self.recorder = nil
        aktuellesSegment = nil
        laeuft = false
        messTask?.cancel()
        dauer = dauerBisher
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
    }

    /// One playable file for review and sending (the segments joined).
    func zusammenfuegen() async -> SprachEntwurf? {
        pausieren()
        guard !segmente.isEmpty else { return nil }
        let pegel = Wellenform.downsample(pegelRoh)
        if segmente.count > 1 {
            guard let verbunden = await Self.verbinden(segmente) else { return nil }
            segmente = [verbunden]
        }
        return SprachEntwurf(medienId: nil, url: segmente[0], dauer: dauerBisher, pegel: pegel)
    }

    /// Delete: the recorder stops and every segment file goes.
    func verwerfen() {
        pausieren()
        for teil in segmente { try? FileManager.default.removeItem(at: teil) }
        zuruecksetzen()
    }

    /// After sending: forget the segments (the joined file is being uploaded, not deleted).
    func zuruecksetzen() {
        segmente = []
        dauerBisher = 0
        dauer = 0
        pegelRoh = []
        pegelLive = []
    }

    private func unterbrochen() {
        guard laeuft else { return }
        pausieren()
        onUnterbrochen?()
    }

    /// Off the main thread: switching an active `.playback` session to `.playAndRecord` can take
    /// hundreds of milliseconds.
    private nonisolated static func sitzungAktivieren() async -> Bool {
        await Task.detached(priority: .userInitiated) { () -> Bool in
            let sitzung = AVAudioSession.sharedInstance()
            do {
                try sitzung.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try sitzung.setActive(true)
                return true
            } catch {
                return false
            }
        }.value
    }

    private static func verbinden(_ teile: [URL]) async -> URL? {
        let komposition = AVMutableComposition()
        guard let spur = komposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        var ende = CMTime.zero
        for teil in teile {
            let asset = AVURLAsset(url: teil)
            guard let quelle = try? await asset.loadTracks(withMediaType: .audio).first,
                  let laenge = try? await asset.load(.duration)
            else { continue }
            try? spur.insertTimeRange(CMTimeRange(start: .zero, duration: laenge), of: quelle, at: ende)
            ende = CMTimeAdd(ende, laenge)
        }
        guard let export = AVAssetExportSession(asset: komposition, presetName: AVAssetExportPresetAppleM4A) else { return nil }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        do {
            try await export.export(to: ziel, as: .m4a)
            return ziel
        } catch {
            return nil
        }
    }

    /// Calls, Siri, other apps, a lost route (headphones out) and leaving the foreground pause.
    private func beobachtenFallsNoetig() {
        guard !beobachtet else { return }
        beobachtet = true
        let zentrum = NotificationCenter.default
        zentrum.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let beginn = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            guard beginn else { return }
            Task { @MainActor in self?.unterbrochen() }
        }
        zentrum.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let grund = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard grund == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in self?.unterbrochen() }
        }
        zentrum.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.unterbrochen() }
        }
    }
}

/// A recorded-but-not-yet-sent voice note (Z-26.2): uploaded right away, just like a draft photo,
/// so it can round-trip through `entwurf.setzen {sprache: medienId}` — `medienId` is nil until
/// that upload finishes; sending falls back to the full encode-and-send pipeline until then
/// (Z-26.2's own contract: sending never waits for the upload).
struct SprachEntwurf: Sendable {
    var medienId: String?
    let url: URL
    let dauer: TimeInterval
    let pegel: [Float]
}

// MARK: - Input bar control

/// Mic in the input field (voice round). Tap: records until pause or send, never sends by itself.
/// Hold: records while held, letting go sends, sliding left cancels. Paused (by the button or an
/// interruption) → review: play/scrub, speed, delete, continue, send. `vorschau` is lifted into
/// the input bar (Z-26.2) so the draft can restore and clear it across relaunch.
struct SprachAufnahmeButton: View {
    let ich: Person
    let antwortAuf: String?
    let onGesendet: () -> Void
    @Binding var vorschau: SprachEntwurf?
    /// Z-26.2: called once the review file appears, is replaced, or is cleared.
    var onEntwurfAendern: () -> Void = {}
    /// Block 18: true while recording or reviewing, so the input bar gives this the whole field.
    var onBelegt: (Bool) -> Void = { _ in }

    @State private var steuerung = AufnahmeSteuerung()
    @State private var phase: SprachPhase = .bereit
    /// Hold-to-talk: when the finger went down, and whether it slid left to cancel.
    @State private var halteBeginn: Date?
    @State private var halteAbbruch = false
    /// False again when the touch ends or is cancelled (a system alert, e.g. the mic permission).
    @GestureState private var gedrueckt = false
    @State private var loeschenFragen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let abbruchWeg: CGFloat = -80

    var body: some View {
        // Trailing: the mic stays under the holding finger while the panel appears.
        VStack(alignment: .trailing, spacing: 8) {
            switch phase {
            case .nimmtAuf: aufnahmePanel
            case .pruefen: pruefPanel
            case .sendet: ProgressView().frame(maxWidth: .infinity, minHeight: 56)
            case .bereit: EmptyView()
            }
            // The mic keeps its place (and gesture) while held, so hold-to-talk sees the release.
            if phase == .bereit || halteBeginn != nil { mikrofon }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : Feder.federnd, value: phase)
        .onChange(of: phase != .bereit) { _, belegt in onBelegt(belegt) }
        .onChange(of: vorschau?.url, initial: true) { _, url in
            // A restored draft opens in review; a cleared one closes it.
            if url != nil, phase == .bereit { phase = .pruefen; onBelegt(true) }
            if url == nil, phase == .pruefen, !steuerung.hatAufnahme { phase = .bereit }
        }
        .onAppear { steuerung.onUnterbrochen = { unterbrochen() } }
        .confirmationDialog("Aufnahme löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { verwerfen() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func ereignis(_ e: SprachEreignis) {
        phase = SprachAblauf.weiter(phase, e)
    }

    // MARK: Mic (idle, and during hold-to-talk)

    private var mikrofon: some View {
        let haelt = halteBeginn != nil && phase == .nimmtAuf
        return Image(systemName: haelt ? "mic.fill" : "mic")
            .font(.system(size: haelt ? 24 : 20, weight: .semibold))
            .foregroundStyle(haelt ? Color.white : Color.secondary)
            .frame(width: haelt ? 56 : 44, height: haelt ? 56 : 44)
            .background(haelt ? Color.red : Color.clear, in: .circle)
            .overlay(alignment: .bottomTrailing) {
                if haelt {
                    Text(halteAbbruch ? "Loslassen zum Löschen" : "← Wischen zum Löschen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .offset(y: 18)
                }
            }
            .contentShape(.rect)
            .gesture(halteGeste)
            .onChange(of: gedrueckt) { _, jetzt in
                guard !jetzt else { return }
                // A cancelled touch never reaches `onEnded`: it counts as a tap (keeps recording).
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    halteBeginn = nil
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sprachnachricht aufnehmen")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { aufnehmen() }
    }

    /// Finger down starts; the gesture's own timestamps decide tap vs. hold, so a slow audio setup
    /// can never turn a tap into a "hold → send".
    private var halteGeste: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gedrueckt) { _, gedrueckt, _ in gedrueckt = true }
            .onChanged { wert in
                if halteBeginn == nil, phase == .bereit {
                    halteBeginn = wert.time
                    halteAbbruch = false
                    aufnehmen()
                }
                let abbruch = wert.translation.width < Self.abbruchWeg
                if abbruch != halteAbbruch {
                    halteAbbruch = abbruch
                    Haptik.auswahl()
                }
            }
            .onEnded { wert in
                guard let beginn = halteBeginn else { return }
                halteBeginn = nil
                let gehalten = wert.time.timeIntervalSince(beginn) >= 0.4
                guard gehalten else { return } // tap: keeps recording, never sends
                if halteAbbruch { verwerfen() } else { senden() }
            }
    }

    // MARK: Recording panel

    private var aufnahmePanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(.red).frame(width: 10, height: 10)
                    .opacity(steuerung.laeuft ? 1 : 0.3)
                    .accessibilityHidden(true)
                Text(zeit(steuerung.dauer))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
                WellenformAnsicht(pegel: steuerung.pegelLive, anteil: 1)
                    .frame(height: 28)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            }
            if halteBeginn == nil {
                HStack {
                    knopf("trash", "Aufnahme löschen", groesse: 44, farbe: .red.opacity(0.15), vordergrund: .red) { loeschenFragen = true }
                    Spacer()
                    knopf("pause.fill", "Aufnahme pausieren", groesse: 56, farbe: .red, vordergrund: .white) { pausieren() }
                        .disabled(!steuerung.laeuft)
                    Spacer()
                    sendenKnopf.disabled(!steuerung.laeuft)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aufnahme läuft, \(zeit(steuerung.dauer))")
    }

    // MARK: Review panel (paused)

    @ViewBuilder private var pruefPanel: some View {
        if let vorschau {
            let id = vorschau.url.lastPathComponent
            let spielt = SprachSpieler.shared.spielt(id)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        if spielt { SprachSpieler.shared.pausieren() } else { SprachSpieler.shared.spielen(id: id, url: vorschau.url) }
                    } label: {
                        Image(systemName: spielt ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.1), in: .circle)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityLabel(spielt ? "Anhören pausieren" : "Anhören")
                    WellenformAnsicht(pegel: vorschau.pegel, anteil: vorschau.dauer > 0 ? SprachSpieler.shared.position(id) / vorschau.dauer : 0) { anteil in
                        SprachSpieler.shared.springen(id: id, anteil: anteil, dauer: vorschau.dauer)
                    }
                    .frame(height: 30)
                    .accessibilityHidden(true)
                    Text(zeit(SprachSpieler.shared.position(id) > 0 ? SprachSpieler.shared.position(id) : vorschau.dauer))
                        .font(.caption.monospacedDigit())
                    Button { SprachSpieler.shared.geschwindigkeitSchalten() } label: {
                        Text(SprachTempo.text(SprachSpieler.shared.geschwindigkeit))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 8)
                            .frame(minHeight: 28)
                            .background(Color.primary.opacity(0.1), in: .capsule)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityLabel("Geschwindigkeit \(SprachTempo.text(SprachSpieler.shared.geschwindigkeit))")
                }
                HStack {
                    knopf("trash", "Aufnahme löschen", groesse: 44, farbe: .red.opacity(0.15), vordergrund: .red) { loeschenFragen = true }
                    Spacer()
                    knopf("mic.fill", "Weiter aufnehmen", groesse: 56, farbe: .red, vordergrund: .white) { aufnehmen() }
                    Spacer()
                    sendenKnopf
                }
            }
            .padding(.vertical, 6)
        } else {
            // Joining the parts takes a moment after a pause.
            ProgressView().frame(maxWidth: .infinity, minHeight: 56)
        }
    }

    private var sendenKnopf: some View {
        knopf("arrow.up", "Sprachnachricht senden", groesse: 56, farbe: .loveaRose, vordergrund: .white) { senden() }
    }

    private func knopf(_ symbol: String, _ label: String, groesse: CGFloat, farbe: Color, vordergrund: Color, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: groesse > 50 ? 22 : 17, weight: .bold))
                .foregroundStyle(vordergrund)
                .frame(width: groesse, height: groesse)
                .background(farbe, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    private func aufnehmen() {
        guard phase == .bereit || phase == .pruefen else { return }
        let basis = vorschau
        SprachSpieler.shared.parken()
        Haptik.mittel()
        ereignis(.aufnehmen)
        if basis != nil {
            vorschau = nil
            onEntwurfAendern()
        }
        Task {
            guard await steuerung.start(basis: basis) else {
                Haptik.warnung()
                halteBeginn = nil
                if let basis {
                    vorschau = basis
                    phase = .pruefen
                } else {
                    ereignis(.verwerfen)
                }
                return
            }
            // Let go, paused or cancelled while the session was still starting: nothing worth keeping.
            if phase != .nimmtAuf { steuerung.verwerfen() }
        }
    }

    private func pausieren() {
        Haptik.leicht()
        ereignis(.pausieren)
        zurPruefung()
    }

    /// Interruption: pause and keep everything, then review. Never sends.
    private func unterbrochen() {
        halteBeginn = nil
        guard phase == .nimmtAuf else { return }
        Haptik.warnung()
        ereignis(.unterbrechung)
        zurPruefung()
    }

    private func zurPruefung() {
        Task {
            guard let entwurf = await steuerung.zusammenfuegen() else {
                if vorschau == nil, phase == .pruefen { ereignis(.verwerfen) }
                return
            }
            vorschau = entwurf
            onEntwurfAendern()
            hochladenFuerEntwurf(entwurf)
        }
    }

    private func verwerfen() {
        Haptik.mittel()
        SprachSpieler.shared.parken()
        steuerung.verwerfen()
        if let vorschau { try? FileManager.default.removeItem(at: vorschau.url) }
        vorschau = nil
        halteBeginn = nil
        ereignis(.verwerfen)
        onEntwurfAendern()
    }

    /// The only way a voice message goes out: the send button, or letting go in hold-to-talk.
    private func senden() {
        guard phase == .nimmtAuf || phase == .pruefen else { return }
        let vorhanden = vorschau
        ereignis(.senden)
        SprachSpieler.shared.parken()
        Task {
            var entwurf = vorhanden
            if steuerung.laeuft || entwurf == nil { entwurf = await steuerung.zusammenfuegen() }
            if let entwurf, entwurf.dauer >= 0.3 {
                abschicken(entwurf)
            } else {
                Haptik.warnung()
            }
            steuerung.zuruecksetzen()
            vorschau = nil
            onEntwurfAendern()
            ereignis(.gesendet)
        }
    }

    /// Z-26.2: uploads the review file right away, off the send path, so its id can go into
    /// `entwurf.setzen`. Ignored if the user already discarded/replaced it by the time it finishes.
    private func hochladenFuerEntwurf(_ entwurf: SprachEntwurf) {
        Task {
            guard let id = await ChatMedien.entwurfSprachHochladen(entwurf.url) else { return }
            guard vorschau?.url == entwurf.url else { return }
            vorschau?.medienId = id
            onEntwurfAendern()
        }
    }

    private func abschicken(_ aufnahme: SprachEntwurf) {
        Haptik.leicht()
        Task {
            if let medienId = aufnahme.medienId {
                ChatModell.shared.medienSenden(
                    [ChatModell.MedienEintrag(id: medienId, typ: "sprache", breite: 0, hoehe: 0, dauer: aufnahme.dauer, pegel: aufnahme.pegel)],
                    antwortAuf: antwortAuf
                )
            } else {
                await ChatMedien.sprachSenden(aufnahme.url, dauer: aufnahme.dauer, pegel: aufnahme.pegel, antwortAuf: antwortAuf)
            }
            onGesendet()
        }
    }

    private func zeit(_ sekunden: TimeInterval) -> String {
        String(format: "%d:%02d", Int(sekunden) / 60, Int(sekunden) % 60)
    }
}
