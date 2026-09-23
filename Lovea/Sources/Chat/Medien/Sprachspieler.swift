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

    private(set) var spielendeID: String?
    private(set) var fortschritt: TimeInterval = 0
    private(set) var geschwindigkeit: Float = 1
    private var player: AVAudioPlayer?
    private var fortschrittTask: Task<Void, Never>?

    func spielen(id: String, url: URL) {
        if spielendeID == id, let player, !player.isPlaying {
            player.play()
            fortschrittVerfolgen()
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let neuerPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        neuerPlayer.enableRate = true
        neuerPlayer.rate = geschwindigkeit
        neuerPlayer.delegate = self
        neuerPlayer.prepareToPlay()
        neuerPlayer.play()
        player = neuerPlayer
        spielendeID = id
        fortschritt = 0
        fortschrittVerfolgen()
    }

    func pausieren() {
        player?.pause()
        fortschrittTask?.cancel()
    }

    func geschwindigkeitSchalten() {
        geschwindigkeit = geschwindigkeit >= 2 ? 1 : (geschwindigkeit == 1 ? 1.5 : 2)
        player?.rate = geschwindigkeit
    }

    private func fortschrittVerfolgen() {
        fortschrittTask?.cancel()
        fortschrittTask = Task { [weak self] in
            while let self, let player = self.player, player.isPlaying, !Task.isCancelled {
                self.fortschritt = player.currentTime
                try? await Task.sleep(for: .seconds(0.1))
            }
        }
    }

    /// `AVAudioPlayerDelegate` callbacks arrive nonisolated; hop back to the main actor before
    /// touching any state, then auto-advance to the next voice message (Z-5.2).
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, let beendeteID = self.spielendeID else { return }
            self.fortschrittTask?.cancel()
            self.spielendeID = nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button { schalten() } label: {
                    Image(systemName: spielt ? "pause.fill" : "play.fill")
                }
                .disabled(localURL == nil)

                WellenformAnsicht(pegel: medium.pegel ?? [], anteil: fortschrittAnteil)
                    .frame(width: 120, height: 22)

                Text(zeit(spielt ? SprachSpieler.shared.fortschritt : (medium.dauer ?? 0)))
                    .font(.caption2).monospacedDigit()

                Button { SprachSpieler.shared.geschwindigkeitSchalten() } label: {
                    Text(String(format: "%.3gx", SprachSpieler.shared.geschwindigkeit)).font(.caption2.bold())
                }
                .opacity(spielt ? 1 : 0.5)
                .disabled(!spielt)
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

    private var spielt: Bool { SprachSpieler.shared.spielendeID == medium.id }
    private var fortschrittAnteil: Double {
        guard spielt, let dauer = medium.dauer, dauer > 0 else { return 0 }
        return min(1, SprachSpieler.shared.fortschritt / dauer)
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

private struct WellenformAnsicht: View {
    let pegel: [Float]
    let anteil: Double

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array((pegel.isEmpty ? Array(repeating: Float(0.2), count: 24) : pegel).enumerated()), id: \.offset) { index, wert in
                    Capsule()
                        .fill(gefuellt(index) ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: max(1.5, geo.size.width / CGFloat(max(pegel.count, 24)) - 2), height: max(2, CGFloat(wert) * geo.size.height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private func gefuellt(_ index: Int) -> Bool {
        guard !pegel.isEmpty else { return false }
        return Double(index) / Double(pegel.count) <= anteil
    }
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
