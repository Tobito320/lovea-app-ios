import AVFoundation
import SwiftUI
import UIKit

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
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        session.commitConfiguration()
        laeuft = true
        // ponytail: starts on the main actor instead of Apple's usual dedicated session queue —
        // hopping `session.startRunning()` (a non-`Sendable` `AVCaptureSession`) onto a background
        // `Task` isn't something to guess at with no local compiler to check it against, and
        // `startRunning()` only blocks for a session's brief setup, not indefinitely.
        session.startRunning()
        FigurenModell.shared.zustandSenden(.init(haupt: .kamera))
    }

    func stop() {
        guard laeuft else { return }
        laeuft = false
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
        session.stopRunning()
    }

    private func berechtigung() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
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

    // MARK: - Foto (Z-6.1: Tippen)

    func fotoAufnehmen() async -> UIImage? {
        await withCheckedContinuation { continuation in
            fotoContinuation = continuation
            let einstellungen = AVCapturePhotoSettings()
            einstellungen.flashMode = blitzAn ? .on : .off
            photoOutput.capturePhoto(with: einstellungen, delegate: self)
        }
    }

    // MARK: - Video (Z-6.1: Halten, bis zu 30 s)

    func videoStarten() async -> URL? {
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
/// (the same finger that started the recording). Tap-vs-hold uses the same proven timing pattern
/// as `SprachAufnahmeButton` (Chat/Medien/Sprachnachricht.swift).
struct SnapKameraView: View {
    let onFoto: (UIImage) -> Void
    let onVideo: (URL) -> Void
    let onAbbrechen: () -> Void

    @State private var steuerung = SnapKameraSteuerung()
    @State private var modus: Modus = .ruhe
    @State private var zoomStart: CGFloat = 1

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
            Button { onAbbrechen() } label: { Image(systemName: "xmark") }
            Spacer()
            Button { steuerung.blitzAn.toggle() } label: { Image(systemName: steuerung.blitzAn ? "bolt.fill" : "bolt.slash.fill") }
            Button { steuerung.kameraWechseln() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera") }
        }
        .font(.title2)
        .foregroundStyle(.white)
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
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 60) {} onPressingChanged: { druecken in
            handleDruck(druecken)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { wert in
                    guard modus == .haltend else { return }
                    steuerung.zoomSetzen(zoomStart + max(0, -wert.translation.height) / 100)
                }
        )
        .padding(.bottom, 40)
    }

    private func handleDruck(_ druecken: Bool) {
        if druecken {
            modus = .haltend
            zoomStart = steuerung.zoom
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard modus == .haltend else { return } // released early → handled as a tap below
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if let url = await steuerung.videoStarten() { onVideo(url) }
            }
            return
        }
        guard modus == .haltend else { return }
        modus = .ruhe
        if steuerung.nimmtVideoAuf {
            steuerung.videoStoppen()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            if let bild = await steuerung.fotoAufnehmen() { onFoto(bild) }
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
            SnapEditor(inhalt: inhalt, ich: ich, antwortAuf: antwortAuf, onFertig: onFertig)
        }
    }
}
