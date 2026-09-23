import AVFoundation
import SwiftUI

/// `AVAudioRecorder` wrapper (Z-5.2): AAC `.m4a`, samples `averagePower` every 0.1s while
/// recording for the waveform, `.playAndRecord` session so a Snap/voice call can duck it later.
@MainActor
@Observable
final class AufnahmeSteuerung {
    private(set) var laeuft = false
    private(set) var dauer: TimeInterval = 0
    private(set) var url: URL?
    private var recorder: AVAudioRecorder?
    private var messTask: Task<Void, Never>?
    private var pegelRoh: [Float] = []

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let einstellungen: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let recorder = try? AVAudioRecorder(url: ziel, settings: einstellungen) else { return }
        recorder.isMeteringEnabled = true
        guard recorder.record() else { return }
        self.recorder = recorder
        self.url = ziel
        laeuft = true
        dauer = 0
        pegelRoh = []
        FigurenModell.shared.zustandSenden(.init(haupt: .sprache))
        messTask = Task { [weak self] in
            while let self, self.laeuft, !Task.isCancelled {
                self.recorder?.updateMeters()
                self.pegelRoh.append(self.recorder?.averagePower(forChannel: 0) ?? -160)
                self.dauer += 0.1
                if self.dauer >= 120 { self.stopIntern(); return } // ponytail: hard cap, no UI countdown
                try? await Task.sleep(for: .seconds(0.1))
            }
        }
    }

    @discardableResult
    func stop() -> (url: URL, dauer: TimeInterval, pegel: [Float])? {
        guard let url, laeuft || recorder != nil else { return nil }
        let ergebnisDauer = dauer
        let pegel = Wellenform.downsample(pegelRoh)
        stopIntern()
        return (url, ergebnisDauer, pegel)
    }

    func verwerfen() {
        if let url { try? FileManager.default.removeItem(at: url) }
        stopIntern()
        url = nil
    }

    private func stopIntern() {
        recorder?.stop()
        messTask?.cancel(); messTask = nil
        laeuft = false
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
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

/// Mic/send button (Z-5.2): a quick tap starts recording, a second quick tap stops it into a
/// preview bar (Vorhören mit 1×/1,5×/2×, Verwerfen/Senden); holding it down and releasing sends
/// immediately. `vorschau` is lifted into the input bar (Z-26.2) so the draft can restore and
/// clear it across relaunch.
struct SprachAufnahmeButton: View {
    let ich: Person
    let antwortAuf: String?
    let onGesendet: () -> Void
    @Binding var vorschau: SprachEntwurf?
    /// Z-26.2: called once the preview starts, is replaced, or is cleared, so the input bar can
    /// push an updated `entwurf.setzen`.
    var onEntwurfAendern: () -> Void = {}
    /// Block 18: true while recording or previewing, so the input bar can give this the whole field.
    var onBelegt: (Bool) -> Void = { _ in }

    private enum Modus { case ruhe, haltend, tippModus }

    @State private var steuerung = AufnahmeSteuerung()
    @State private var modus: Modus = .ruhe
    @State private var druckBeginn: Date?

    var body: some View {
        Group {
            if let vorschau {
                VorschauLeiste(
                    aufnahme: vorschau,
                    onSenden: { senden(vorschau); self.vorschau = nil; onEntwurfAendern() },
                    onVerwerfen: { try? FileManager.default.removeItem(at: vorschau.url); self.vorschau = nil; onEntwurfAendern() }
                )
            } else {
                aufnahmeKnopf
            }
        }
        .onChange(of: modus != .ruhe || vorschau != nil) { _, belegt in onBelegt(belegt) }
    }

    // The gesture stays on ONE view across the whole recording — swapping to a different view
    // (e.g. a plain `HStack` once recording starts) would drop the recognizer and the required
    // second tap of tap+tap mode could never arrive.
    private var aufnahmeKnopf: some View {
        Group {
            if modus == .ruhe {
                Image(systemName: "mic.fill")
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "waveform").foregroundStyle(.red)
                    Text(zeit(steuerung.dauer)).font(.caption2).monospacedDigit()
                }
            }
        }
        .frame(minWidth: 34, minHeight: 36) // Block 18: same height as the input bar icons
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 40) {} onPressingChanged: { druecken in
            handlePress(druecken)
        }
        // VoiceOver (Z-16.3): a double tap is one short press, so the first activation starts
        // tap+tap mode and the second stops into the preview bar.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(modus == .ruhe ? "Sprachnachricht aufnehmen" : "Aufnahme beenden")
        .accessibilityValue(modus == .ruhe ? "" : zeit(steuerung.dauer))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            handlePress(true)
            handlePress(false)
        }
    }

    /// Both interaction styles (Z-5.2 "halten+loslassen oder tippen+tippen") share one gesture:
    /// `onPressingChanged` fires true/false around every touch, short or long. A short first
    /// touch leaves the recording running (`tippModus`, waiting for the second tap); a touch held
    /// past 0.3s sends on release; the second tap of tap+tap mode stops into the preview bar.
    private func handlePress(_ druecken: Bool) {
        if druecken {
            if modus == .ruhe {
                druckBeginn = Date()
                ChatHaptik.mittel()
                steuerung.start()
                modus = .haltend
            }
            return
        }
        switch modus {
        case .haltend:
            if Date().timeIntervalSince(druckBeginn ?? Date()) > 0.3 {
                if let ergebnis = steuerung.stop() {
                    senden(SprachEntwurf(medienId: nil, url: ergebnis.url, dauer: ergebnis.dauer, pegel: ergebnis.pegel))
                }
                modus = .ruhe
            } else {
                modus = .tippModus
            }
        case .tippModus:
            if let ergebnis = steuerung.stop() {
                let entwurf = SprachEntwurf(medienId: nil, url: ergebnis.url, dauer: ergebnis.dauer, pegel: ergebnis.pegel)
                vorschau = entwurf
                onEntwurfAendern()
                hochladenFuerEntwurf(entwurf)
            }
            modus = .ruhe
        case .ruhe:
            break
        }
    }

    /// Z-26.2: uploads the preview right away, off the send path, so its id can go into
    /// `entwurf.setzen`. Ignored if the user already discarded/replaced this recording by the time
    /// it finishes.
    private func hochladenFuerEntwurf(_ entwurf: SprachEntwurf) {
        Task {
            guard let id = await ChatMedien.entwurfSprachHochladen(entwurf.url) else { return }
            guard vorschau?.url == entwurf.url else { return }
            vorschau?.medienId = id
            onEntwurfAendern()
        }
    }

    private func senden(_ aufnahme: SprachEntwurf) {
        ChatHaptik.leicht()
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

private struct VorschauLeiste: View {
    let aufnahme: SprachEntwurf
    let onSenden: () -> Void
    let onVerwerfen: () -> Void

    // Z-26.2: the file's own name, not a constant "vorschau" — a fixed id would make
    // `SprachSpieler.shared` think a re-recorded (or sent/discarded and freshly recorded) preview
    // is still the previous file and resume it instead of restarting.
    private var vorschauID: String { aufnahme.url.lastPathComponent }
    private var spielt: Bool { SprachSpieler.shared.spielendeID == vorschauID }

    var body: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) { onVerwerfen() } label: { Image(systemName: "trash") }
                .accessibilityLabel("Aufnahme verwerfen")
            Button {
                if spielt { SprachSpieler.shared.pausieren() } else { SprachSpieler.shared.spielen(id: vorschauID, url: aufnahme.url) }
            } label: { Image(systemName: spielt ? "pause.fill" : "play.fill") }
                .accessibilityLabel(spielt ? "Anhören pausieren" : "Anhören")
            // Z-26.2: "vor dem Senden anhören mit 1×/1,5×/2×" — same cycling speed `SprachSpieler`
            // already uses for sent voice messages.
            Button { SprachSpieler.shared.geschwindigkeitSchalten() } label: {
                Text(String(format: "%.3gx", SprachSpieler.shared.geschwindigkeit)).font(.caption2.bold())
            }
            .accessibilityLabel("Geschwindigkeit")
            Text(String(format: "%d:%02d", Int(aufnahme.dauer) / 60, Int(aufnahme.dauer) % 60))
                .font(.caption2).monospacedDigit()
            Spacer()
            Button { onSenden() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                .accessibilityLabel("Sprachnachricht senden")
        }
        .frame(minHeight: 36)
        .padding(.horizontal, 4)
    }
}
