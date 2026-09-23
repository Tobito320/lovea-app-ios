import AVFoundation
import CoreMedia
import SwiftUI
import UIKit

/// Z-34.4: the one serial queue that owns the capture session. Configuration, start, stop, mic
/// on/off, camera switch and recording start/stop all run here in call order, so `startRunning`
/// never overlaps a `begin/commitConfiguration` (the build-11 crash) and a stop is never
/// overtaken by an earlier start.
private let sessionSchlange = DispatchQueue(label: "lovea.snap.kamera", qos: .userInitiated)

/// Everything the capture session owns. The mutable inputs are touched only on `sessionSchlange`;
/// the main actor only reads the three `let`s (preview layer, photo capture).
private final class KameraSitzung: @unchecked Sendable {
    let session = AVCaptureSession()
    let foto = AVCapturePhotoOutput()
    let film = AVCaptureMovieFileOutput()
    private var kamera: AVCaptureDeviceInput?
    private var mikro: AVCaptureDeviceInput?

    /// Configures once, then runs. Idempotent.
    func starten(_ position: AVCaptureDevice.Position) {
        if kamera == nil {
            session.beginConfiguration()
            session.sessionPreset = .high
            kameraSetzen(position)
            if session.canAddOutput(foto) { session.addOutput(foto) }
            if session.canAddOutput(film) { session.addOutput(film) }
            session.commitConfiguration()
        }
        if !session.isRunning { session.startRunning() }
    }

    func stoppen() {
        mikroWeg()
        if session.isRunning { session.stopRunning() }
    }

    func wechseln(_ position: AVCaptureDevice.Position) {
        guard kamera != nil else { return } // not configured yet: `starten` picks up the new side
        session.beginConfiguration()
        kameraSetzen(position)
        session.commitConfiguration()
    }

    /// New input first; the old one stays if the new one can't be created or added.
    private func kameraSetzen(_ position: AVCaptureDevice.Position) {
        guard let geraet = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let neu = try? AVCaptureDeviceInput(device: geraet)
        else { return }
        if let alt = kamera { session.removeInput(alt) }
        if session.canAddInput(neu) {
            session.addInput(neu)
            kamera = neu
        } else if let alt = kamera {
            session.addInput(alt)
        }
    }

    /// Mic joins only for a video, inside its own configuration block on this queue.
    private func mikroDazu() {
        guard mikro == nil, let geraet = AVCaptureDevice.default(for: .audio),
              let neu = try? AVCaptureDeviceInput(device: geraet)
        else { return }
        session.beginConfiguration()
        if session.canAddInput(neu) {
            session.addInput(neu)
            mikro = neu
        }
        session.commitConfiguration()
    }

    func mikroWeg() {
        guard let mikro else { return }
        session.beginConfiguration()
        session.removeInput(mikro)
        session.commitConfiguration()
        self.mikro = nil
    }

    /// Adds the mic, then records. false when the session can't record yet (not running, no
    /// active video connection) — `startRecording` would throw "No active/enabled connections".
    func aufnehmen(nach ziel: URL, delegate: any AVCaptureFileOutputRecordingDelegate) -> Bool {
        guard session.isRunning, let verbindung = film.connection(with: .video), verbindung.isActive else { return false }
        mikroDazu()
        // App is portrait-only but a connection defaults to landscape (angle 0).
        if verbindung.isVideoRotationAngleSupported(90) { verbindung.videoRotationAngle = 90 }
        film.maxRecordedDuration = CMTime(seconds: 30, preferredTimescale: 600)
        film.startRecording(to: ziel, recordingDelegate: delegate)
        return true
    }
}

/// `AVCaptureSession` coordinator (Z-6.1, Z-34.4): photo + movie outputs, front/back, flash, zoom.
/// The main actor keeps UI state (flags, zoom, position); every session call goes through
/// `sessionSchlange`. Delegates fire on an AVFoundation queue and hop back to the main actor.
@MainActor
@Observable
final class SnapKameraSteuerung: NSObject {
    private let sitzung = KameraSitzung()
    /// For the preview layer, set once; it shows frames as soon as the session runs.
    var session: AVCaptureSession { sitzung.session }

    private(set) var laeuft = false
    private(set) var nimmtVideoAuf = false
    private(set) var videoFortschritt: Double = 0 // 0...1 of the 30s cap
    var blitzAn = false
    private(set) var zoom: CGFloat = 1

    private var position: AVCaptureDevice.Position = .back
    /// Main-actor handle on the active camera for zoom and torch (device settings, not session calls).
    private var geraet: AVCaptureDevice?
    private var fotoContinuation: CheckedContinuation<UIImage?, Never>?
    private var videoContinuation: CheckedContinuation<URL?, Never>?
    private var fortschrittTask: Task<Void, Never>?
    private var aufnahmeStart: Date?

    /// Shared instance (Z-26.5): the conversation prewarms it, `SnapKameraView` reuses the
    /// already-running session, so opening the camera has nothing left to wait for.
    static let geteilt = SnapKameraSteuerung()

    // MARK: - Warm hold (Z-26.5)

    private var haltungen = 0
    private var abkuehlTask: Task<Void, Never>?

    /// Ref-counted: the conversation view and the camera view each call this on appear/`loslassen()`
    /// on disappear. Needed because a `fullScreenCover` opening over the conversation re-fires ITS
    /// `onDisappear` too — without the counter and the grace period in `loslassen()`, that
    /// transition would stop the very session the camera view is about to reuse.
    func halten() {
        haltungen += 1
        abkuehlTask?.cancel()
        abkuehlTask = nil
    }

    func loslassen() {
        haltungen = max(0, haltungen - 1)
        guard haltungen == 0 else { return }
        abkuehlTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled, self.haltungen == 0 else { return }
            self.stop()
        }
    }

    /// Z-34.4: runs the session as soon as the chat is visible, so the viewfinder is live before
    /// the camera's open animation ends. Silent: only once access was granted, never a prompt
    /// just from opening the chat. Idempotent. (Running means the green camera dot shows.)
    func vorwaermen() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        laufenLassen()
    }

    /// Camera UI opening (Z-6.1): may prompt, then runs the (usually already warm) session.
    func start() async {
        // After the prompt: only if the camera is still wanted, else this start would land after a stop.
        guard await berechtigung(), !Task.isCancelled, haltungen > 0 else { return }
        laufenLassen()
        FigurenModell.shared.zustandSenden(.init(haupt: .kamera))
    }

    private func laufenLassen() {
        guard !laeuft else { return }
        laeuft = true
        if geraet == nil { geraet = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) }
        let sitzung = sitzung, position = position
        sessionSchlange.async { sitzung.starten(position) }
    }

    /// The camera UI itself closing, as opposed to the session merely staying warm for the chat:
    /// the mic goes right away (a warm session must never keep recording audio) and `.imChat` is
    /// signaled immediately instead of after `loslassen()`'s grace period.
    func kameraVerlassen() {
        let sitzung = sitzung
        sessionSchlange.async { sitzung.mikroWeg() }
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
        loslassen()
    }

    /// Only ever stops the session — no figure-state signal (`kameraVerlassen()` sent that already).
    func stop() {
        guard laeuft else { return }
        laeuft = false
        let sitzung = sitzung
        sessionSchlange.async { sitzung.stoppen() }
    }

    /// Camera is required; the mic (videos have sound) is asked too, but a "no" only means silent
    /// video, like the system Camera app.
    private func berechtigung() async -> Bool {
        let kamera = await berechtigungFuer(.video)
        _ = await berechtigungFuer(.audio)
        return kamera
    }

    private func berechtigungFuer(_ typ: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: typ) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: typ)
        default: false
        }
    }

    func kameraWechseln() {
        position = position == .back ? .front : .back
        geraet = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        zoom = 1
        let sitzung = sitzung, position = position
        sessionSchlange.async { sitzung.wechseln(position) }
    }

    func zoomSetzen(_ wert: CGFloat) {
        guard let geraet, (try? geraet.lockForConfiguration()) != nil else { return }
        let ziel = min(max(wert, geraet.minAvailableVideoZoomFactor), min(geraet.maxAvailableVideoZoomFactor, 8))
        geraet.videoZoomFactor = ziel
        geraet.unlockForConfiguration()
        zoom = ziel
    }

    /// The front camera has no torch; setting a mode without the device lock would throw.
    private func taschenlampeSchalten(an: Bool) {
        guard let geraet, geraet.hasTorch, geraet.isTorchModeSupported(an ? .on : .off),
              (try? geraet.lockForConfiguration()) != nil
        else { return }
        geraet.torchMode = an ? .on : .off
        geraet.unlockForConfiguration()
    }

    // MARK: - Foto (Z-6.1: Tippen)

    func fotoAufnehmen() async -> UIImage? {
        // A tap before the first frames (first open, mid camera switch) would throw inside
        // `capturePhoto`; a second tap while one is in flight would drop its continuation.
        guard fotoContinuation == nil, let verbindung = sitzung.foto.connection(with: .video), verbindung.isActive else { return nil }
        if verbindung.isVideoRotationAngleSupported(90) { verbindung.videoRotationAngle = 90 }
        return await withCheckedContinuation { continuation in
            fotoContinuation = continuation
            let einstellungen = AVCapturePhotoSettings()
            einstellungen.flashMode = blitzAn && sitzung.foto.supportedFlashModes.contains(.on) ? .on : .off
            sitzung.foto.capturePhoto(with: einstellungen, delegate: self)
        }
    }

    // MARK: - Video (Z-6.1: Halten, bis zu 30 s)

    func videoStarten() async -> URL? {
        guard !nimmtVideoAuf else { return nil }
        if blitzAn { taschenlampeSchalten(an: true) }
        nimmtVideoAuf = true
        aufnahmeStart = Date()
        fortschrittTask = Task { [weak self] in
            while let self, self.nimmtVideoAuf, !Task.isCancelled {
                self.videoFortschritt = min(Date().timeIntervalSince(self.aufnahmeStart ?? Date()) / 30, 1)
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        return await withCheckedContinuation { continuation in
            videoContinuation = continuation
            let sitzung = sitzung
            sessionSchlange.async {
                guard sitzung.aufnehmen(nach: ziel, delegate: self) else {
                    Task { @MainActor in self.aufnahmeBeendet(nil) }
                    return
                }
            }
        }
    }

    /// Through the queue too: a quick release right after the hold must not stop before the
    /// queued start ran (the recording would then run to the 30 s cap).
    func videoStoppen() {
        guard nimmtVideoAuf else { return }
        let sitzung = sitzung
        sessionSchlange.async { sitzung.film.stopRecording() }
    }

    /// Recording finished (or never started). The mic leaves only now, so the end of the audio
    /// isn't cut off.
    private func aufnahmeBeendet(_ url: URL?) {
        nimmtVideoAuf = false
        fortschrittTask?.cancel()
        videoFortschritt = 0
        taschenlampeSchalten(an: false)
        let sitzung = sitzung
        sessionSchlange.async { sitzung.mikroWeg() }
        videoContinuation?.resume(returning: url)
        videoContinuation = nil
    }
}

extension SnapKameraSteuerung: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let bild = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            fotoContinuation?.resume(returning: bild)
            fotoContinuation = nil
        }
    }
}

extension SnapKameraSteuerung: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Hitting `maxRecordedDuration` (our 30s cap) itself reports a non-nil error even though the
        // file is complete and valid — only treat every OTHER error as an actual failure.
        let erfolgreich = error == nil || (error as? AVError)?.code == .maximumDurationReached
        Task { @MainActor in aufnahmeBeendet(erfolgreich ? outputFileURL : nil) }
    }
}

/// `AVCaptureVideoPreviewLayer`-backed `UIView` — `layerClass` override auto-tracks the view's
/// bounds, simpler and more robust than a manually laid-out sublayer.
private final class KameraVorschauUIView: UIView {
    override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct KameraVorschau: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> KameraVorschauUIView {
        let view = KameraVorschauUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: KameraVorschauUIView, context: Context) {}
}

/// Full-screen camera (Z-6.1): tap for a photo, hold (≥0.3s) for video up to 30s with a progress
/// ring, haptic on shutter. Pinch anywhere zooms; while holding the shutter, dragging up also zooms
/// (the same finger that started the recording).
struct SnapKameraView: View {
    let onFoto: (UIImage) -> Void
    let onVideo: (URL) -> Void
    let onAbbrechen: () -> Void

    // Z-26.5: the conversation's own shared instance — reused so a prewarmed session is already
    // running by the time this view appears.
    @State private var steuerung = SnapKameraSteuerung.geteilt
    @State private var modus: Modus = .ruhe
    @State private var zoomStart: CGFloat = 1
    @State private var haltTask: Task<Void, Never>?

    private enum Modus { case ruhe, haltend }

    var body: some View {
        ZStack {
            KameraVorschau(session: steuerung.session)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { wert in steuerung.zoomSetzen(zoomStart * wert) }
                        .onEnded { _ in zoomStart = steuerung.zoom }
                )

            VStack {
                obereLeiste
                Spacer()
                untereLeiste
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .onAppear { steuerung.halten() }
        .task { await steuerung.start() }
        .onDisappear { steuerung.kameraVerlassen() }
    }

    private var obereLeiste: some View {
        HStack {
            Button { onAbbrechen() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("Abbrechen")
            Spacer()
            Button { steuerung.blitzAn.toggle() } label: { Image(systemName: steuerung.blitzAn ? "bolt.fill" : "bolt.slash.fill").frame(width: 44, height: 44) }
                .accessibilityLabel("Blitz")
                .accessibilityValue(steuerung.blitzAn ? "an" : "aus")
            Button { steuerung.kameraWechseln() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").frame(width: 44, height: 44) }
                .accessibilityLabel("Kamera wechseln")
        }
        .font(.title2)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 3) // stays readable over a bright scene
        .padding()
    }

    private var untereLeiste: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.4), lineWidth: 4).frame(width: 76, height: 76)
            Circle()
                .trim(from: 0, to: steuerung.videoFortschritt)
                .stroke(Color.loveaRose, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(-90))
            Circle().fill(.white).frame(width: 62, height: 62)
        }
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Auslöser")
        .accessibilityHint("Tippen für ein Foto, halten für ein Video")
        .accessibilityAddTraits(.isButton)
        // A drag gesture alone isn't reliably activatable by VoiceOver: the default action takes a photo.
        .accessibilityAction {
            guard modus == .ruhe, !steuerung.nimmtVideoAuf else { return }
            Task {
                if let bild = await steuerung.fotoAufnehmen() { onFoto(bild) }
            }
        }
        // One `DragGesture(minimumDistance: 0)` covers tap, hold-to-record AND the drag-up-to-zoom
        // while recording — deliberately not `onLongPressGesture` + a second `simultaneousGesture`:
        // `onLongPressGesture`'s `maximumDistance` cancels the whole press once the same finger
        // drags past it, which is exactly what dragging up to zoom while holding does.
        .gesture(shutterGeste)
        .padding(.bottom, 40)
    }

    private var shutterGeste: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                if modus == .ruhe {
                    modus = .haltend
                    zoomStart = steuerung.zoom
                    haltTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard modus == .haltend, !steuerung.nimmtVideoAuf else { return } // released early → tap
                        Haptik.mittel()
                        if let url = await steuerung.videoStarten() { onVideo(url) }
                    }
                }
                if steuerung.nimmtVideoAuf {
                    steuerung.zoomSetzen(zoomStart + max(0, -wert.translation.height) / 100)
                }
            }
            .onEnded { _ in
                guard modus == .haltend else { return }
                modus = .ruhe
                if steuerung.nimmtVideoAuf {
                    steuerung.videoStoppen()
                    return
                }
                haltTask?.cancel()
                Haptik.leicht()
                Task {
                    if let bild = await steuerung.fotoAufnehmen() { onFoto(bild) }
                }
            }
    }
}

/// Whole Snap flow (Z-6.1–Z-6.2): camera → editor → send, presented as one `fullScreenCover` from
/// `ChatEingabeleiste`. `onFertig` fires once, whether cancelled or sent.
struct SnapKameraFluss: View {
    let ich: Person
    let antwortAuf: String?
    let onFertig: () -> Void

    private enum Schritt {
        case kamera
        case editor(SnapInhalt)
    }
    @State private var schritt: Schritt = .kamera

    var body: some View {
        switch schritt {
        case .kamera:
            SnapKameraView(
                onFoto: { schritt = .editor(.foto($0)) },
                onVideo: { schritt = .editor(.video($0)) },
                onAbbrechen: onFertig
            )
        case .editor(let inhalt):
            // Never sent straight from the camera: the editor's send button is the only way out
            // that sends; its X goes back to the camera instead of closing everything.
            SnapEditor(inhalt: inhalt, ich: ich, antwortAuf: antwortAuf, onFertig: onFertig, onVerwerfen: { schritt = .kamera })
        }
    }
}
