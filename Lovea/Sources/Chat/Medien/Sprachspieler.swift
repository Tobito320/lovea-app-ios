import AVFoundation
import Foundation
import Speech
import SwiftUI

/// One shared `AVAudioPlayer` (Z-5.2): a per-row player would be re-created every time `LazyVStack`
/// recycles the row it scrolled off, and dropping/re-fetching the file mid-playback would stutter.
/// `.playback` session (not `.playAndRecord`) — keeps playing with the app backgrounded.
@MainActor
@Observable
final class SprachSpieler: NSObject, AVAudioPlayerDelegate {
    static let shared = SprachSpieler()

    /// The message loaded in the player, playing or paused.
    private(set) var spielendeID: String?
    /// Voice round fix: "is playing" is its own state. Before, `spielendeID` alone meant "playing",
    /// so a paused message still showed the pause button and a tap paused it again: no resume.
    private(set) var laeuft = false
    private(set) var fortschritt: TimeInterval = 0
    private(set) var geschwindigkeit: Float = 1
    private var player: AVAudioPlayer?
    /// Where each message not currently loaded was left, so switching messages keeps positions.
    private var positionen: [String: TimeInterval] = [:]
    private var fortschrittTask: Task<Void, Never>?

    /// 1× → 1,5× → 2× → 1×.
    nonisolated static func naechsteGeschwindigkeit(_ jetzt: Float) -> Float {
        jetzt >= 2 ? 1 : (jetzt == 1 ? 1.5 : 2)
    }

    func spielt(_ id: String) -> Bool { spielendeID == id && laeuft }

    func position(_ id: String) -> TimeInterval { spielendeID == id ? fortschritt : (positionen[id] ?? 0) }

    /// Plays `id` from where it was left. Only one message plays: the previous one pauses and keeps
    /// its position.
    func spielen(id: String, url: URL) {
        if spielendeID == id, let player {
            player.play()
            laeuft = true
            fortschrittVerfolgen()
            return
        }
        parken()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let neuerPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        neuerPlayer.enableRate = true
        neuerPlayer.rate = geschwindigkeit
        neuerPlayer.delegate = self
        neuerPlayer.prepareToPlay()
        neuerPlayer.currentTime = min(positionen[id] ?? 0, max(neuerPlayer.duration - 0.1, 0))
        neuerPlayer.play()
        player = neuerPlayer
        spielendeID = id
        fortschritt = neuerPlayer.currentTime
        laeuft = true
        fortschrittVerfolgen()
    }

    /// Pauses and keeps the position; play resumes from there.
    func pausieren() {
        player?.pause()
        laeuft = false
        fortschrittTask?.cancel()
        if let player { fortschritt = player.currentTime }
    }

    /// Scrubbing: seeks the loaded message, or remembers the spot for one that isn't loaded.
    func springen(id: String, anteil: Double, dauer: TimeInterval) {
        let ziel = max(0, min(1, anteil)) * dauer
        if spielendeID == id, let player {
            player.currentTime = min(ziel, player.duration)
            fortschritt = player.currentTime
        } else {
            positionen[id] = ziel
        }
    }

    func geschwindigkeitSchalten() {
        geschwindigkeit = Self.naechsteGeschwindigkeit(geschwindigkeit)
        player?.rate = geschwindigkeit
    }

    /// The loaded message steps aside (its position kept) for another one or for recording.
    func parken() {
        guard let alt = spielendeID, let player else { return }
        player.pause()
        positionen[alt] = player.currentTime
        self.player = nil
        spielendeID = nil
        laeuft = false
        fortschrittTask?.cancel()
    }

    private func fortschrittVerfolgen() {
        fortschrittTask?.cancel()
        fortschrittTask = Task { [weak self] in
            while let self, let player = self.player, player.isPlaying, !Task.isCancelled {
                self.fortschritt = player.currentTime
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
    }

    /// `AVAudioPlayerDelegate` callbacks arrive nonisolated; hop back to the main actor before
    /// touching any state. At the end the message resets to 0, then the next one plays (Z-5.2).
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, let beendeteID = self.spielendeID else { return }
            self.fortschrittTask?.cancel()
            self.positionen[beendeteID] = 0
            self.player = nil
            self.spielendeID = nil
            self.laeuft = false
            self.fortschritt = 0
            await self.naechsteAbspielen(nach: beendeteID)
        }
    }

    private func naechsteAbspielen(nach id: String) async {
        let nachrichten = ChatModell.shared.nachrichten
        guard let index = nachrichten.firstIndex(where: { $0.medien.contains { $0.id == id } }) else { return }
        for nachricht in nachrichten[(index + 1)...] {
            guard let medium = nachricht.medien.first(where: { $0.typ == "sprache" }) else { continue }
            guard let url = (try? await Medien.holen(medium.id)) else { return } // stop rather than skip a not-yet-local one
            spielen(id: medium.id, url: url)
            return
        }
    }
}

/// Voice-message bubble (Z-5.2): waveform, play/pause, speed, transcript on demand.
struct SprachBlase: View {
    let medium: ChatModell.MedienEintrag
    @State private var localURL: URL?
    @State private var zeigeAbschrift = false
    @State private var abschriftLaeuft = false

    private var abschrift: String? { ChatModell.shared.abschriften[medium.id] }

    /// Voice round: play button, waveform, time and speed each in their own space (the waveform's
    /// bars used to overflow its frame onto the play button, so the start couldn't be scrubbed).
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Button { schalten() } label: {
                    Image(systemName: spielt ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.22), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.federnd)
                .disabled(localURL == nil)
                .accessibilityLabel(spielt ? "Sprachnachricht pausieren" : "Sprachnachricht abspielen")

                WellenformAnsicht(pegel: medium.pegel ?? [], anteil: fortschrittAnteil) { anteil in
                    SprachSpieler.shared.springen(id: medium.id, anteil: anteil, dauer: medium.dauer ?? 0)
                }
                .frame(width: 128, height: 30)
                .accessibilityElement()
                .accessibilityLabel("Wiedergabeposition")
                .accessibilityValue(zeit(SprachSpieler.shared.position(medium.id)))
                .accessibilityAdjustableAction { richtung in
                    let dauer = max(medium.dauer ?? 0, 1)
                    let schritt = (richtung == .increment ? 5 : -5) / dauer
                    SprachSpieler.shared.springen(id: medium.id, anteil: fortschrittAnteil + schritt, dauer: dauer)
                }

                Text(zeit(aktiv ? SprachSpieler.shared.position(medium.id) : (medium.dauer ?? 0)))
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 34, alignment: .leading)

                Button { SprachSpieler.shared.geschwindigkeitSchalten() } label: {
                    Text(SprachTempo.text(SprachSpieler.shared.geschwindigkeit))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .frame(minHeight: 26)
                        .background(.white.opacity(0.22), in: .capsule)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Geschwindigkeit \(SprachTempo.text(SprachSpieler.shared.geschwindigkeit))")
            }

            if let abschrift, zeigeAbschrift {
                Text(abschrift).font(.caption).foregroundStyle(.secondary)
            } else {
                Button {
                    if abschrift != nil { zeigeAbschrift = true } else { starteAbschrift() }
                } label: {
                    if abschriftLaeuft {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text(abschrift != nil ? "Abschrift anzeigen" : "Abschreiben")
                    }
                }
                .font(.caption2)
                .disabled(abschriftLaeuft)
            }
        }
        .task(id: medium.id) { localURL = await warteAufLokal(medium.id) }
    }

    private var spielt: Bool { SprachSpieler.shared.spielt(medium.id) }
    /// Started before (playing, paused or scrubbed): show the position instead of the length.
    private var aktiv: Bool { SprachSpieler.shared.position(medium.id) > 0 || spielt }
    private var fortschrittAnteil: Double {
        guard let dauer = medium.dauer, dauer > 0 else { return 0 }
        return min(1, SprachSpieler.shared.position(medium.id) / dauer)
    }

    private func schalten() {
        guard let localURL else { return }
        if spielt { SprachSpieler.shared.pausieren() } else { SprachSpieler.shared.spielen(id: medium.id, url: localURL) }
    }

    private func zeit(_ sekunden: TimeInterval) -> String {
        String(format: "%d:%02d", Int(sekunden) / 60, Int(sekunden) % 60)
    }

    private func warteAufLokal(_ id: String) async -> URL? {
        if eigeneOderLokal(id) { return ChatMedien.eigeneQuellen[id] ?? Medien.lokal(id) }
        while !Task.isCancelled {
            if let geholt = try? await Medien.holen(id) { return geholt }
            try? await Task.sleep(for: .seconds(5))
        }
        return nil
    }

    private func eigeneOderLokal(_ id: String) -> Bool {
        ChatMedien.eigeneQuellen[id] != nil || Medien.lokal(id) != nil
    }

    private func starteAbschrift() {
        guard let localURL else { return }
        abschriftLaeuft = true
        Task {
            defer { abschriftLaeuft = false }
            if let text = await SprachAbschrift.abschreiben(localURL) {
                ChatModell.shared.abschriftSenden(medienId: medium.id, text: text)
                zeigeAbschrift = true
            }
        }
    }
}

/// 1×/1,5×/2× as shown on the chips.
enum SprachTempo {
    nonisolated static func text(_ tempo: Float) -> String {
        tempo == 1.5 ? "1,5×" : "\(Int(tempo))×"
    }
}

/// Waveform bars drawn to exactly the given width (Canvas), played part solid, the rest dimmed.
/// With `onSpringen`, tapping or dragging on it seeks.
struct WellenformAnsicht: View {
    let pegel: [Float]
    let anteil: Double
    var onSpringen: ((Double) -> Void)?

    var body: some View {
        GeometryReader { geo in
            Canvas { g, groesse in
                let werte = pegel.isEmpty ? Array(repeating: Float(0.2), count: 32) : pegel
                let luecke: CGFloat = 2
                let breite = max(1.5, (groesse.width - luecke * CGFloat(werte.count - 1)) / CGFloat(werte.count))
                for (index, wert) in werte.enumerated() {
                    let hoehe = max(3, CGFloat(wert) * groesse.height)
                    let x = CGFloat(index) * (breite + luecke)
                    let balken = Path(roundedRect: CGRect(x: x, y: (groesse.height - hoehe) / 2, width: breite, height: hoehe), cornerRadius: breite / 2)
                    let gespielt = !pegel.isEmpty && (Double(index) + 0.5) / Double(werte.count) <= anteil
                    var stift = g
                    stift.opacity = gespielt ? 1 : 0.4
                    stift.fill(balken, with: .foreground)
                }
            }
            .contentShape(.rect)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { wert in
                        guard let onSpringen, geo.size.width > 0 else { return }
                        ScrubSperre.aktiv = true
                        onSpringen(Double(wert.location.x / geo.size.width))
                    }
                    .onEnded { _ in ScrubSperre.aktiv = false },
                including: onSpringen == nil ? .none : .all
            )
        }
    }
}

/// While a waveform is scrubbed, the bubble's reply swipe keeps still.
@MainActor
enum ScrubSperre {
    static var aktiv = false
}

/// On-device transcription (Z-5.2): `SFSpeechRecognizer(locale: de-DE)`, `requiresOnDeviceRecognition`.
enum SprachAbschrift {
    static func abschreiben(_ url: URL) async -> String? {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition
        else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        // The result handler can fire more than once (partials, then the final result) — resuming a
        // `CheckedContinuation` twice crashes, so only `isFinal` (or an error) ever resumes it. A
        // plain captured `var` would be a strict-concurrency error if this handler is `@Sendable`
        // (mutating a captured var from concurrently-executing code) — `EinmalGuard` locks instead.
        let einmal = EinmalGuard()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    einmal.einmal { continuation.resume(returning: result.bestTranscription.formattedString) }
                } else if error != nil {
                    einmal.einmal { continuation.resume(returning: nil) }
                }
            }
        }
    }
}

/// Runs its closure at most once, safe to call from any thread/queue — a lock instead of a captured
/// `var` so a `@Sendable` callback (e.g. `SFSpeechRecognitionTask`'s result handler, which can be
/// invoked off the main thread) never triggers a "mutation of captured var" strict-concurrency error.
private final class EinmalGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var ausgefuehrt = false

    func einmal(_ aktion: () -> Void) {
        lock.lock()
        let schonDran = ausgefuehrt
        ausgefuehrt = true
        lock.unlock()
        guard !schonDran else { return }
        aktion()
    }
}
