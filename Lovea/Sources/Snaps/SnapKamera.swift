import AVFoundation
import CoreMedia
import SwiftUI
import UIKit

/// `startRunning()`/`stopRunning()` block until the camera is up or down; Apple says to call them
/// off the main thread. One serial queue keeps start and stop in order (Z-16.2).
private let sessionSchlange = DispatchQueue(label: "lovea.snap.kamera", qos: .userInitiated)

/// Carries the session onto `sessionSchlange`. Only start/stop run there, and the session is
/// documented safe to start/stop from its own queue.
private struct SessionBox: @unchecked Sendable { let session: AVCaptureSession }

/// `AVCaptureSession` coordinator (Z-6.1): photo + movie file outputs, front/back, flash, zoom.
/// Delegates fire on an AVFoundation-internal queue, not necessarily the main actor — every
/// callback hops back explicitly, same pattern as `SprachSpieler`/`AVAudioPlayerDelegate`.
@MainActor
@Observable
final class SnapKameraSteuerung: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var eingang: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back

    private(set) var laeuft = false
    private(set) var nimmtVideoAuf = false
    private(set) var videoFortschritt: Double = 0 // 0...1 of the 30s cap
    var blitzAn = false
    private(set) var zoom: CGFloat = 1

    private var fotoContinuation: CheckedContinuation<UIImage?, Never>?
    private var videoContinuation: CheckedContinuation<URL?, Never>?
    private var fortschrittTask: Task<Void, Never>?
    private var aufnahmeStart: Date?

    func start() async {
        guard !laeuft, await berechtigung() else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        einrichtenEingang(position: position)
        einrichtenAudioEingang()
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        session.commitConfiguration()
        laeuft = true
        let box = SessionBox(session: session)
        sessionSchlange.async { box.session.startRunning() }
        FigurenModell.shared.zustandSenden(.init(haupt: .kamera))
    }

    func stop() {
        guard laeuft else { return }
        laeuft = false
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
        let box = SessionBox(session: session)
        sessionSchlange.async { box.session.stopRunning() }
    }

    /// Camera access is required; microphone (Z-6.1 videos have sound) is requested too but a "no"
    /// there doesn't block the camera itself — it just records silent video, same as the system
    /// Camera app does when mic access is denied.
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

    private func einrichtenEingang(position: AVCaptureDevice.Position) {
        if let eingang { session.removeInput(eingang) }
        guard let geraet = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let neuerEingang = try? AVCaptureDeviceInput(device: geraet),
              session.canAddInput(neuerEingang)
        else { return }
        session.addInput(neuerEingang)
        eingang = neuerEingang
        self.position = position
        zoom = 1
    }

    private func einrichtenAudioEingang() {
        guard let geraet = AVCaptureDevice.default(for: .audio),
              let eingang = try? AVCaptureDeviceInput(device: geraet),
              session.canAddInput(eingang)
        else { return }
        session.addInput(eingang)
    }

    func kameraWechseln() {
        session.beginConfiguration()
        einrichtenEingang(position: position == .back ? .front : .back)
        session.commitConfiguration()
    }

    func zoomSetzen(_ wert: CGFloat) {
        guard let geraet = eingang?.device else { return }
        let ziel = min(max(wert, geraet.minAvailableVideoZoomFactor), min(geraet.maxAvailableVideoZoomFactor, 8))
        try? geraet.lockForConfiguration()
        geraet.videoZoomFactor = ziel
        geraet.unlockForConfiguration()
        zoom = ziel
    }

    /// App is locked to portrait (`project.yml`) but a capture connection defaults to landscape
    /// (rotation angle 0) — without this, every photo/video comes out sideways.
    private func aufAufrechtAusrichten(_ verbindung: AVCaptureConnection?) {
        guard let verbindung, verbindung.isVideoRotationAngleSupported(90) else { return }
        verbindung.videoRotationAngle = 90
    }

    /// The front camera has no flash — `capturePhoto` throws if `flashMode` isn't one of
    /// `supportedFlashModes`, so this checks rather than assuming `.on` always works.
    private func taschenlampeSchalten(an: Bool) {
        guard let geraet = eingang?.device, geraet.hasTorch, geraet.isTorchModeSupported(an ? .on : .off) else { return }
        try? geraet.lockForConfiguration()
        geraet.torchMode = an ? .on : .off
        geraet.unlockForConfiguration()
    }

    // MARK: - Foto (Z-6.1: Tippen)

    func fotoAufnehmen() async -> UIImage? {
        aufAufrechtAusrichten(photoOutput.connection(with: .video))
        return await withCheckedContinuation { continuation in
            fotoContinuation = continuation
            let einstellungen = AVCapturePhotoSettings()
            einstellungen.flashMode = blitzAn && photoOutput.supportedFlashModes.contains(.on) ? .on : .off
            photoOutput.capturePhoto(with: einstellungen, delegate: self)
        }
    }

    // MARK: - Video (Z-6.1: Halten, bis zu 30 s)

    func videoStarten() async -> URL? {
        aufAufrechtAusrichten(movieOutput.connection(with: .video))
        if blitzAn { taschenlampeSchalten(an: true) }
        movieOutput.maxRecordedDuration = CMTime(seconds: 30, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            videoContinuation = continuation
            let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            nimmtVideoAuf = true
            aufnahmeStart = Date()
            movieOutput.startRecording(to: ziel, recordingDelegate: self)
            fortschrittTask = Task { [weak self] in
                while let self, self.nimmtVideoAuf, !Task.isCancelled {
                    self.videoFortschritt = min(Date().timeIntervalSince(self.aufnahmeStart ?? Date()) / 30, 1)
                    try? await Task.sleep(for: .seconds(0.05))
                }
            }
        }
    }

    func videoStoppen() {
        guard nimmtVideoAuf else { return }
        movieOutput.stopRecording()
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
        Task { @MainActor in
            nimmtVideoAuf = false
            fortschrittTask?.cancel()
            videoFortschritt = 0
            taschenlampeSchalten(an: false)
            videoContinuation?.resume(returning: erfolgreich ? outputFileURL : nil)
            videoContinuation = nil
        }
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

    @State private var steuerung = SnapKameraSteuerung()
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
        .task { await steuerung.start() }
        .onDisappear { steuerung.stop() }
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
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
