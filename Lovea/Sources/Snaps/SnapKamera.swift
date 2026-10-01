import AVFoundation
import CoreMedia
import PhotosUI
import SwiftUI
import UIKit

/// Z-34.4: the one serial queue that owns the capture session. Configuration, start, stop, mic
/// on/off, camera switch and recording start/stop all run here in call order, so `startRunning`
/// never overlaps a `begin/commitConfiguration` (the build-11 crash) and a stop is never
/// overtaken by an earlier start.
private let sessionSchlange = DispatchQueue(label: "lovea.snap.kamera", qos: .userInitiated)

/// Device pick (Z-R9: Linsen-Pille): back camera prefers a virtual multi-camera device (ultra-wide +
/// wide + tele under one `videoZoomFactor`, Snapchat-style lens switching), falling back lens by lens
/// down to the plain wide camera on older/simulator hardware. Front stays single-lens (wide only —
/// Ahmed's spec: "Front camera: 1x only").
enum SnapKameraGeraet {
    static func waehlen(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        guard position == .back else { return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) }
        let typen: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        for typ in typen {
            if let geraet = AVCaptureDevice.default(typ, for: .video, position: position) { return geraet }
        }
        return nil
    }
}

/// Everything the capture session owns. The mutable inputs are touched only on `sessionSchlange`;
/// the main actor only reads the three `let`s (preview layer, photo capture).
private final class KameraSitzung: @unchecked Sendable {
    let session = AVCaptureSession()
    let foto = AVCapturePhotoOutput()
    let film = AVCaptureMovieFileOutput()
    private var kamera: AVCaptureDeviceInput?
    private var mikro: AVCaptureDeviceInput?

    /// Inputs and outputs ready, not running (no camera dot). Idempotent.
    func konfigurieren(_ position: AVCaptureDevice.Position) {
        guard kamera == nil else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        kameraSetzen(position)
        if session.canAddOutput(foto) { session.addOutput(foto) }
        if session.canAddOutput(film) { session.addOutput(film) }
        session.commitConfiguration()
    }

    /// Configures if still needed, then runs. Returns once frames flow. Idempotent. `stabilisierung`
    /// is re-applied here too (Review Important fix, 2026-10-01), not only when the menu toggle
    /// fires — `starten` can (re-)create the movie connection via `konfigurieren`/`kameraSetzen`.
    func starten(_ position: AVCaptureDevice.Position, stabilisierung: Bool) {
        konfigurieren(position)
        stabilisierungSetzen(an: stabilisierung)
        if !session.isRunning { session.startRunning() }
    }

    func stoppen() {
        mikroWeg()
        if session.isRunning { session.stopRunning() }
    }

    /// `stabilisierung` is re-applied after the switch (Review Important fix): `kameraSetzen` tears
    /// down and re-adds the camera input, which can rebuild the movie connection — the toggle would
    /// otherwise silently stop applying after a camera switch (menu still shows "an", recording runs
    /// unstabilized).
    func wechseln(_ position: AVCaptureDevice.Position, stabilisierung: Bool) {
        guard kamera != nil else { return } // not configured yet: `starten` picks up the new side
        session.beginConfiguration()
        kameraSetzen(position)
        session.commitConfiguration()
        stabilisierungSetzen(an: stabilisierung)
    }

    /// New input first; the old one stays if the new one can't be created or added.
    private func kameraSetzen(_ position: AVCaptureDevice.Position) {
        guard let geraet = SnapKameraGeraet.waehlen(position: position),
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

    /// Z-R9: `.standard` smooths handheld video, `.off` matches the raw feed (default, like the
    /// Snapchat reference's "Stabilisierung: Aus"). The connection only exists once `konfigurieren`
    /// added `film` as an output, which has always happened before the UI can reach this toggle.
    func stabilisierungSetzen(an: Bool) {
        film.connection(with: .video)?.preferredVideoStabilizationMode = an ? .standard : .off
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
    func aufnehmen(nach ziel: URL, spiegeln: Bool, delegate: any AVCaptureFileOutputRecordingDelegate) -> Bool {
        guard session.isRunning, let verbindung = film.connection(with: .video), verbindung.isActive else { return false }
        mikroDazu()
        // App is portrait-only but a connection defaults to landscape (angle 0).
        if verbindung.isVideoRotationAngleSupported(90) { verbindung.videoRotationAngle = 90 }
        // Only this OUTPUT connection: the preview mirrors the front camera on its own connection.
        SnapBildAusrichtung.anwenden(auf: verbindung, spiegeln: spiegeln)
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
    /// True once `startRunning` returned (frames flow); the preview fades in on it.
    private(set) var bildDa = false
    private var vorbereitet = false
    private(set) var nimmtVideoAuf = false
    private(set) var videoFortschritt: Double = 0 // 0...1 of the 30s cap
    var blitzAn = false
    private(set) var zoom: CGFloat = 1
    /// Z-R9: front-only "Blitz" equivalent — the front camera has no torch/flash hardware, so a
    /// bright white frame (`KameraRinglichtRahmen`) plus max screen brightness stands in for it.
    /// `fotoAufnehmen`/`videoStarten` turn it on, their completions always turn it back off.
    private(set) var ringlichtAktiv = false
    private var ringlichtUrsprungsHelligkeit: CGFloat?
    /// Z-R9: off by default (matches the Snapchat reference's "Stabilisierung: Aus"); toggled from
    /// `KameraSeitenMenu`.
    var stabilisierungAn = false { didSet { let sitzung = sitzung, an = stabilisierungAn; sessionSchlange.async { sitzung.stabilisierungSetzen(an: an) } } }
    /// Z-R9: default on (Ahmed's spec). Applied once per front-camera photo, after capture, never live.
    var schoenheitAn = true

    private var position: AVCaptureDevice.Position = .back
    /// Main-actor handle on the active camera for zoom and torch (device settings, not session calls).
    private var geraet: AVCaptureDevice?
    private var fotoContinuation: CheckedContinuation<UIImage?, Never>?
    private var videoContinuation: CheckedContinuation<URL?, Never>?
    private var fortschrittTask: Task<Void, Never>?
    private var aufnahmeStart: Date?
    /// Set by `KameraVorschau` once its layer exists (Z-R7: WYSIWYG-Zuschnitt). Weak: the view, not
    /// this shared singleton, owns the layer's lifetime. Stays set for the whole time the camera is
    /// visible (`KameraVorschauUIView` isn't recreated while `SnapKameraView` is on screen, only its
    /// `session`/`videoGravity` get re-applied), so it's non-nil by the time a tap can happen.
    private weak var vorschauEbene: AVCaptureVideoPreviewLayer?
    /// The preview's visible rect AND camera position for the photo currently in flight — both read
    /// right before `capturePhoto`, not in the delegate, so the crop never depends on `vorschauEbene`
    /// (or `position`) still being what they were at tap time once the delegate callback fires later.
    private var zuschnittAusstehend: CGRect?
    private var ausrichtungAusstehend: UIImage.Orientation = .up
    /// Z-R9: frozen at tap time, same reasoning as the crop/orientation above — the delegate must
    /// not re-read `position`/`schoenheitAn`, which could have changed by the time it fires.
    private var schoenheitAusstehend = false

    func vorschauEbeneSetzen(_ ebene: AVCaptureVideoPreviewLayer) {
        vorschauEbene = ebene
    }

    /// Shared instance (Z-26.5): the conversation configures it ahead of time, `SnapKameraView`
    /// reuses that session and only has to start it running.
    static let geteilt = SnapKameraSteuerung()

    // MARK: - Warm hold (Z-26.5)

    private var haltungen = 0
    private var abkuehlTask: Task<Void, Never>?

    /// Ref-counted: the conversation view and the camera view each call this on appear/`loslassen()`
    /// on disappear. Needed because a `fullScreenCover` opening over the conversation re-fires ITS
    /// `onDisappear` too — without the counter and the grace period in `loslassen()`, that
    /// transition could stop the session the camera view is just starting. The camera closing itself
    /// stops at once (`kameraVerlassen()`); the hold only covers these hand-overs.
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

    /// Z-34.4: configures the session (inputs and outputs, the slow part) as soon as the chat is
    /// visible, but does not run it: no green camera dot while chatting. Silent: only once access
    /// was granted, never a prompt just from opening the chat. Idempotent.
    func vorwaermen() async {
        guard !vorbereitet, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        vorbereitet = true
        let sitzung = sitzung, position = position
        sessionSchlange.async { sitzung.konfigurieren(position) }
    }

    /// Camera UI opening (Z-6.1): may prompt, then runs the (usually already configured) session.
    func start() async {
        // After the prompt: only if the camera is still wanted, else this start would land after a stop.
        guard await berechtigung(), !Task.isCancelled, haltungen > 0 else { return }
        laufenLassen()
        FigurenModell.shared.zustandSenden(.init(haupt: .kamera))
    }

    private func laufenLassen() {
        guard !laeuft else { return }
        laeuft = true
        vorbereitet = true
        if geraet == nil { geraet = SnapKameraGeraet.waehlen(position: position) }
        let sitzung = sitzung, position = position, stabil = stabilisierungAn
        sessionSchlange.async {
            sitzung.starten(position, stabilisierung: stabil)
            Task { @MainActor in self.bildBereit() }
        }
    }

    /// A stop requested meanwhile wins: the queue already stopped the session again.
    private func bildBereit() {
        guard laeuft else { return }
        bildDa = true
    }

    /// The camera UI closing: the session stops right away (camera dot off, mic gone) and
    /// `.imChat` is signaled. The configuration stays, so the next open only has to start running.
    func kameraVerlassen() {
        stop()
        ringlichtSetzen(an: false)
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
        loslassen()
    }

    /// Stops running (mic removed first); the configuration stays. No figure-state signal.
    func stop() {
        guard laeuft else { return }
        laeuft = false
        bildDa = false
        let sitzung = sitzung
        sessionSchlange.async { sitzung.stoppen() }
    }

    /// Always restores screen brightness, even if `an` is already false (Ahmed's rule: "always
    /// restore, also on cancel/disappear") — cheap no-op when there's nothing to restore.
    private func ringlichtSetzen(an: Bool) {
        let an = an && position == .front
        guard an != ringlichtAktiv else { return }
        ringlichtAktiv = an
        if an {
            ringlichtUrsprungsHelligkeit = UIScreen.main.brightness
            UIScreen.main.brightness = 1
        } else if let ursprung = ringlichtUrsprungsHelligkeit {
            UIScreen.main.brightness = ursprung
            ringlichtUrsprungsHelligkeit = nil
        }
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
        ringlichtSetzen(an: false) // the ring light only ever makes sense on the side we're leaving
        position = position == .back ? .front : .back
        geraet = SnapKameraGeraet.waehlen(position: position)
        zoom = 1
        let sitzung = sitzung, position = position, stabil = stabilisierungAn
        sessionSchlange.async { sitzung.wechseln(position, stabilisierung: stabil) }
    }

    func zoomSetzen(_ wert: CGFloat) {
        guard let geraet, (try? geraet.lockForConfiguration()) != nil else { return }
        let ziel = min(max(wert, geraet.minAvailableVideoZoomFactor), min(geraet.maxAvailableVideoZoomFactor, 8))
        geraet.videoZoomFactor = ziel
        geraet.unlockForConfiguration()
        zoom = ziel
    }

    /// Z-R9: chips the lens pill shows (ultra-wide/wide/tele). Empty on the front camera (single
    /// lens, no pill — Ahmed's spec) and on back hardware without a virtual multi-camera device.
    var linsenWerte: [CGFloat] {
        guard let geraet, geraet.isVirtualDevice else { return [] }
        let switchOver = geraet.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        return KameraLinse.werte(minZoom: geraet.minAvailableVideoZoomFactor, switchOverFaktoren: switchOver, maxZoom: min(geraet.maxAvailableVideoZoomFactor, 8))
    }

    /// Tapping a lens chip ramps to it (smooth, unlike the instant jump `zoomSetzen` does for pinch).
    func linseWaehlen(_ wert: CGFloat) {
        guard let geraet, (try? geraet.lockForConfiguration()) != nil else { return }
        geraet.ramp(toVideoZoomFactor: wert, withRate: 8)
        geraet.unlockForConfiguration()
        zoom = wert
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
        // "Selfie spiegeln": read once at tap time and frozen for the delegate (like the crop).
        // The connection flag AND the orientation tag below both follow it — unclear without a
        // device whether the flag also changes the pixels of `cgImageRepresentation()`, so both are
        // set to agree either way.
        let spiegeln = SnapBildAusrichtung.spiegeln()
        SnapBildAusrichtung.anwenden(auf: verbindung, spiegeln: spiegeln)
        // Visible rect the preview showed (aspectFill crops the sensor image to the screen) —
        // captured now, while the layer's bounds are still the ones Ahmed framed by. This rect is in
        // `metadataOutputRectConverted`'s coordinate space: the capture device's native SENSOR
        // orientation (landscape, unrotated, unmirrored) — not the portrait/mirrored space the
        // preview displays in. `photoOutput(didFinishProcessingPhoto:)` below crops the delegate's
        // `cgImageRepresentation()` with it, which is that exact same sensor-native buffer, so no
        // rect rotation is needed; only the final `UIImage` orientation tag (set from `position`,
        // not the rect) turns it upright and mirrored for display.
        zuschnittAusstehend = vorschauEbene.map { $0.metadataOutputRectConverted(fromLayerRect: $0.bounds) }
        ausrichtungAusstehend = SnapBildAusrichtung.fuer(position: position, spiegeln: spiegeln)
        schoenheitAusstehend = schoenheitAn && position == .front
        // Front has no flash hardware, so `supportedFlashModes` never includes `.on` there — the
        // ring light is the front's stand-in, triggered here instead. Review Important fix
        // (2026-10-01): a real flash is effectively instant, but raising `UIScreen.main.brightness`
        // and fading `KameraRinglichtRahmen` in (`Feder.schnell`) are not — without a wait,
        // `capturePhoto` below could fire before the screen has actually brightened, so the photo
        // would show little to no extra light. Only wait when the ring light actually turned on
        // (back camera / flash off: `ringlichtAktiv` stays false, no wasted 250ms per photo).
        ringlichtSetzen(an: blitzAn)
        if ringlichtAktiv { try? await Task.sleep(for: .milliseconds(250)) }
        return await withCheckedContinuation { continuation in
            fotoContinuation = continuation
            let einstellungen = AVCapturePhotoSettings()
            einstellungen.flashMode = blitzAn && sitzung.foto.supportedFlashModes.contains(.on) ? .on : .off
            sitzung.foto.capturePhoto(with: einstellungen, delegate: self)
        }
    }

    /// Z-R9 Multi-Snap: captures a short, fixed burst back-to-back. Reduced scope (see report): the
    /// photos go to the existing one-photo-at-a-time editor flow in sequence (`SnapKameraFluss`),
    /// not a custom picker strip — a full picker UI touches `SnapEditor`, which this task may not
    /// change (another agent owns its filter carousel work). Stops early on a capture failure.
    func mehrfachAufnehmen(anzahl: Int = 4, abstand: Duration = .milliseconds(450)) async -> [UIImage] {
        var bilder: [UIImage] = []
        for i in 0..<anzahl {
            guard let bild = await fotoAufnehmen() else { break }
            bilder.append(bild)
            if i < anzahl - 1 { try? await Task.sleep(for: abstand) }
        }
        return bilder
    }

    // MARK: - Video (Z-6.1: Halten, bis zu 30 s)

    func videoStarten() async -> URL? {
        guard !nimmtVideoAuf else { return nil }
        if blitzAn {
            taschenlampeSchalten(an: true) // back: real torch (no-ops on front, no torch hardware)
            ringlichtSetzen(an: true) // front: ring light instead (no-ops on back, see the guard inside)
        }
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
            let sitzung = sitzung, spiegeln = SnapBildAusrichtung.spiegeln()
            sessionSchlange.async {
                guard sitzung.aufnehmen(nach: ziel, spiegeln: spiegeln, delegate: self) else {
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
        ringlichtSetzen(an: false)
        let sitzung = sitzung
        sessionSchlange.async { sitzung.mikroWeg() }
        videoContinuation?.resume(returning: url)
        videoContinuation = nil
    }
}

extension SnapKameraSteuerung: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // `cgImageRepresentation()`, not `fileDataRepresentation()` + `UIImage(data:)`: the latter
        // decodes a JPEG that already carries an EXIF orientation tag, i.e. an image whose *pixel*
        // axes no longer match `zuschnittAusstehend`'s sensor-native coordinate space. This raw
        // representation is the sensor buffer itself (unrotated, unmirrored) — the same space the
        // preview-derived rect is in (see `fotoAufnehmen`), so cropping it needs no rect conversion.
        let roh = photo.cgImageRepresentation()
        Task { @MainActor in
            // Crop to what the preview actually showed (aspectFill) — the full sensor image is
            // wider/taller than the screen, so uncropped it reopened in the editor letterboxed
            // and framed differently than what Ahmed saw and tapped the shutter on. No live layer
            // read here: both the rect and the orientation were captured at tap time in
            // `fotoAufnehmen`, so a layer that's since gone can't silently drop the crop.
            var bild = roh.map { zugeschnittenesBild(von: $0, zuschnitt: zuschnittAusstehend, ausrichtung: ausrichtungAusstehend) }
            zuschnittAusstehend = nil
            ringlichtSetzen(an: false) // flash-equivalent: only on for the instant of capture
            // Z-R9 Schönheit: after capture, off the main thread, front only, flag frozen at tap
            // time (see `schoenheitAusstehend`). The live preview stays untouched (battery, and
            // Ahmed only asked for the captured photo).
            if schoenheitAusstehend, let urspruenglich = bild {
                bild = await Task.detached(priority: .userInitiated) { SnapSchoenheit.angewendet(auf: urspruenglich) }.value
            }
            fotoContinuation?.resume(returning: bild)
            fotoContinuation = nil
        }
    }

    private func zugeschnittenesBild(von sensorBild: CGImage, zuschnitt: CGRect?, ausrichtung: UIImage.Orientation) -> UIImage {
        guard let zuschnitt else { return UIImage(cgImage: sensorBild, scale: 1, orientation: ausrichtung) }
        let rechteck = SnapZuschnitt.pixelRechteck(einheitsRechteck: zuschnitt, bildGroesse: CGSize(width: sensorBild.width, height: sensorBild.height))
        guard rechteck.width > 0, rechteck.height > 0, let zugeschnitten = sensorBild.cropping(to: rechteck) else {
            return UIImage(cgImage: sensorBild, scale: 1, orientation: ausrichtung)
        }
        return UIImage(cgImage: zugeschnitten, scale: 1, orientation: ausrichtung)
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
    /// Hands the layer to the steuerung once, so a capture can read its visible rect (Z-R7).
    let aufEbene: (AVCaptureVideoPreviewLayer) -> Void

    func makeUIView(context: Context) -> KameraVorschauUIView {
        let view = KameraVorschauUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        aufEbene(view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: KameraVorschauUIView, context: Context) {}
}

/// Pure crop math (Z-R7): AVFoundation's `metadataOutputRectConverted` gives a unit rect (0...1,
/// origin top-left) of the SENSOR-native image (landscape, unrotated, unmirrored — see
/// `fotoAufnehmen`) that the preview actually showed under `resizeAspectFill` — this turns it into
/// pixel bounds on that same sensor-native image, clamped so a rounding edge never asks
/// `CGImage.cropping` for a rect outside the image (which returns nil).
enum SnapZuschnitt {
    static func pixelRechteck(einheitsRechteck: CGRect, bildGroesse: CGSize) -> CGRect {
        guard bildGroesse.width > 0, bildGroesse.height > 0 else { return .zero }
        let roh = CGRect(
            x: einheitsRechteck.minX * bildGroesse.width,
            y: einheitsRechteck.minY * bildGroesse.height,
            width: einheitsRechteck.width * bildGroesse.width,
            height: einheitsRechteck.height * bildGroesse.height
        )
        return roh.integral.intersection(CGRect(origin: .zero, size: bildGroesse))
    }
}

/// Pure orientation mapping (Z-R7): turns the sensor-native `CGImage` from
/// `AVCapturePhoto.cgImageRepresentation()` upright, exactly like `verbindung.videoRotationAngle =
/// 90` (always set, for portrait) plus the connection's mirroring would tag the EXIF-oriented file.
/// Portrait-only, so the orientation only depends on `position` and the switch below — no per-photo
/// metadata lookup needed.
///
/// Schalter "Selfie spiegeln" (Einstellungen, Standard AUS, Ahmed 01.10.): AUS = Foto und Video von der
/// Frontkamera ungespiegelt wie in der iOS-Kamera, nur die Live-Vorschau bleibt gespiegelt. AN = die
/// alte Spiegelung wie die Vorschau. Die Rückkamera ändert der Schalter nie.
enum SnapBildAusrichtung {
    static let schluessel = "lovea.selfieSpiegeln"

    static func spiegeln(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: schluessel)
    }

    static func fuer(position: AVCaptureDevice.Position, spiegeln: Bool) -> UIImage.Orientation {
        position == .front && spiegeln ? .leftMirrored : .right
    }

    /// Setzt die Spiegelung einer Ausgabe-Connection (Foto oder Film), die Vorschau hat ihre eigene.
    /// AN: Automatik wie früher. AUS: Automatik aus, dann erst `isVideoMirrored` (andersherum wirft
    /// AVFoundation). Immer ausdrücklich gesetzt, weil die Connection zwischen Aufnahmen bleibt.
    static func anwenden(auf verbindung: AVCaptureConnection, spiegeln: Bool) {
        if spiegeln {
            verbindung.automaticallyAdjustsVideoMirroring = true
        } else {
            verbindung.automaticallyAdjustsVideoMirroring = false
            if verbindung.isVideoMirroringSupported { verbindung.isVideoMirrored = false }
        }
    }
}

/// Full-screen camera (Z-6.1): tap for a photo, hold (≥0.3s) for video up to 30s with a progress
/// ring, haptic on shutter. Pinch anywhere zooms; while holding the shutter, dragging up also zooms
/// (the same finger that started the recording).
struct SnapKameraView: View {
    let onFoto: (UIImage) -> Void
    let onVideo: (URL) -> Void
    /// Z-R9 Multi-Snap: a non-empty burst, handed to `SnapKameraFluss` to run through the editor
    /// one photo after another (see `mehrfachAufnehmen`'s doc comment for the reduced scope).
    let onMultiFoto: ([UIImage]) -> Void
    let onAbbrechen: () -> Void

    // Z-26.5/Z-34.4: the conversation's shared instance, already configured, so this view only
    // has to start it running.
    @State private var steuerung = SnapKameraSteuerung.geteilt
    @State private var modus: Modus = .ruhe
    @State private var zoomStart: CGFloat = 1
    @State private var haltTask: Task<Void, Never>?
    @State private var galerieAuswahl: PhotosPickerItem?
    @State private var galerieLaedt = false

    // Z-R9: menu toggles. Plain view state — none of these reach into AVFoundation except
    // indirectly (freihand/multiSnap change which gesture branch runs; timer delays the capture
    // call that's already there).
    @State private var menueErweitert = false
    @State private var timer: KameraTimer = .aus
    @State private var rasterAn = false
    @State private var freihandAn = false
    @State private var multiSnapAn = false
    @State private var countdown: Int?
    /// Review Important fix (2026-10-01): the countdown's own cancel handle — without it nothing
    /// could stop a running timer (a second tap started an overlapping one, `onDisappear` left it
    /// running and it still fired `fotoAufnehmen()` on an already-left camera).
    @State private var timerTask: Task<Void, Never>?
    /// Review Minor fix (2026-10-01): without this, a second tap while a burst was still running
    /// started a second `mehrfachAufnehmen()` — harmless (`fotoAufnehmen`'s own continuation guard
    /// just dropped the overlapping calls as `nil`), but visibly unclean on a fast double-tap.
    @State private var mehrfachLaeuft = false

    private enum Modus { case ruhe, haltend }

    var body: some View {
        ZStack {
            KameraVorschau(session: steuerung.session, aufEbene: { steuerung.vorschauEbeneSetzen($0) })
                .ignoresSafeArea()
                .opacity(steuerung.bildDa ? 1 : 0) // fades in with the first frames, no black flash
                .animation(Feder.weich, value: steuerung.bildDa)
                .overlay { if rasterAn { KameraRasterOverlay() } }
                .gesture(
                    MagnificationGesture()
                        .onChanged { wert in steuerung.zoomSetzen(zoomStart * wert) }
                        .onEnded { _ in zoomStart = steuerung.zoom }
                )

            KameraRinglichtRahmen(aktiv: steuerung.ringlichtAktiv)
                .ignoresSafeArea()

            VStack {
                obereLeiste
                Spacer()
                KameraLinsenPille(werte: steuerung.linsenWerte, aktuellerZoom: steuerung.zoom, onWahl: { wert in
                    // Review Important fix (2026-10-01): without this, `zoomStart` (the pinch
                    // baseline) stayed at the lens we left — the next pinch's first frame would jump
                    // relative to that stale value. Also replaces the bare `steuerung.linseWaehlen`
                    // method reference with an explicit closure (Review Minor fix).
                    steuerung.linseWaehlen(wert)
                    zoomStart = wert
                })
                    .padding(.bottom, 14)
                untereLeiste
            }

            HStack {
                Spacer()
                menu
            }

            if let countdown {
                KameraCountdownOverlay(sekunden: countdown)
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .onAppear {
            StartProtokoll.marke("screen.kamera")
            steuerung.halten()
        }
        .task { await steuerung.start() }
        .onDisappear {
            timerTask?.cancel() // Review Important fix: no dangling countdown after we've left
            timerTask = nil
            steuerung.kameraVerlassen()
        }
    }

    private var obereLeiste: some View {
        HStack {
            Button { onAbbrechen() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("Abbrechen")
            Spacer()
        }
        .font(.title2)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 3) // stays readable over a bright scene
        .padding()
    }

    /// Z-R9: Wechseln/Blitz/Timer/Raster/Freihand/Multi-Snap/Stabilisierung/Schönheit, vertically
    /// centred on the right edge like `snap-01`/`snap-03`.
    private var menu: some View {
        KameraSeitenMenu(
            steuerung: steuerung,
            onWechseln: {
                // Review Important fix: a countdown running when Ahmed switches cameras must not
                // fire on the side he just left.
                timerTask?.cancel()
                timerTask = nil
                countdown = nil
                steuerung.kameraWechseln()
            },
            erweitert: $menueErweitert,
            timer: $timer,
            rasterAn: $rasterAn,
            freihandAn: $freihandAn,
            multiSnapAn: $multiSnapAn,
            nimmtVideoAuf: steuerung.nimmtVideoAuf
        )
    }

    /// Gallery button left of the shutter, nothing on the right so the shutter stays centred.
    private var untereLeiste: some View {
        HStack {
            galerieKnopf.frame(maxWidth: .infinity)
            ausloeser
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
        .padding(.bottom, 40)
    }

    /// A photo or video from the gallery goes through the same editor and snap path as a capture.
    private var galerieKnopf: some View {
        PhotosPicker(selection: $galerieAuswahl, matching: .any(of: [.images, .videos])) {
            Group {
                if galerieLaedt {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "photo.on.rectangle")
                }
            }
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(.black.opacity(0.35), in: .rect(cornerRadius: 14))
        }
        .disabled(galerieLaedt || steuerung.nimmtVideoAuf)
        .accessibilityLabel("Foto oder Video aus der Galerie")
        .onChange(of: galerieAuswahl) { _, item in galerieLaden(item) }
    }

    private func galerieLaden(_ item: PhotosPickerItem?) {
        guard let item else { return }
        galerieLaedt = true
        Task {
            defer {
                galerieLaedt = false
                galerieAuswahl = nil
            }
            let video = try? await item.loadTransferable(type: VideoDatei.self)
            var daten: Data?
            if video == nil { daten = try? await item.loadTransferable(type: Data.self) }
            switch SnapGalerie.inhalt(videoURL: video?.url, bildDaten: daten) {
            case .foto(let bild)?:
                Haptik.leicht()
                onFoto(bild)
            case .video(let url)?:
                Haptik.leicht()
                onVideo(url)
            case nil:
                Haptik.warnung()
            }
        }
    }

    private var ausloeser: some View {
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
            ausloesen()
        }
        // One `DragGesture(minimumDistance: 0)` covers tap, hold-to-record AND the drag-up-to-zoom
        // while recording — deliberately not `onLongPressGesture` + a second `simultaneousGesture`:
        // `onLongPressGesture`'s `maximumDistance` cancels the whole press once the same finger
        // drags past it, which is exactly what dragging up to zoom while holding does.
        .gesture(shutterGeste)
    }

    /// Tap behaviour, shared by the drag gesture's tap path and the VoiceOver action. Freihand wins
    /// over Multi-Snap (both only make sense as the tap action, see `freihandAn`'s doc comment);
    /// a timer only delays a plain photo — Ahmed's spec doesn't ask for it on video/Multi-Snap too.
    /// `freihandAn`/`multiSnapAn` are this view's own `@State` (Review Critical fix, 2026-10-01):
    /// they're pure UI toggles with no AVFoundation link, `SnapKameraSteuerung` never declared them —
    /// reading `steuerung.freihandAn`/`steuerung.multiSnapAn` here referenced members that don't
    /// exist on that type and didn't build.
    private func ausloesen() {
        // Review Important fix: a tap during a running countdown cancels it instead of layering a
        // second one on top (the old code had no handle on the countdown `Task` at all).
        if timerTask != nil {
            timerTask?.cancel()
            timerTask = nil
            countdown = nil
            return
        }
        if freihandAn {
            if steuerung.nimmtVideoAuf {
                steuerung.videoStoppen()
            } else {
                Haptik.mittel()
                Task { if let url = await steuerung.videoStarten() { onVideo(url) } }
            }
        } else if multiSnapAn {
            guard !mehrfachLaeuft else { return }
            mehrfachLaeuft = true
            Haptik.mittel()
            Task {
                let bilder = await steuerung.mehrfachAufnehmen()
                mehrfachLaeuft = false
                if !bilder.isEmpty { onMultiFoto(bilder) }
            }
        } else if timer != .aus {
            fotoMitTimer()
        } else {
            Haptik.leicht()
            Task { if let bild = await steuerung.fotoAufnehmen() { onFoto(bild) } }
        }
    }

    /// Counts down in the UI, then captures — the countdown itself needs no AVFoundation, so it
    /// lives here rather than in `SnapKameraSteuerung`. Review Important fix: the `Task` is now kept
    /// in `timerTask` (cancelled on a second tap — see `ausloesen` — on camera switch, and on
    /// `onDisappear`), checks `Task.isCancelled` after every sleep instead of swallowing it via
    /// `try?`, AND re-checks after the loop so a cancel mid-last-second can't still fall through to
    /// `fotoAufnehmen()`.
    private func fotoMitTimer() {
        timerTask = Task {
            for sekunde in stride(from: timer.sekunden, through: 1, by: -1) {
                countdown = sekunde
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
            }
            countdown = nil
            guard !Task.isCancelled else { return }
            Haptik.mittel()
            if let bild = await steuerung.fotoAufnehmen() { onFoto(bild) }
            timerTask = nil
        }
    }

    private var shutterGeste: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { wert in
                // Freihand/Multi-Snap/Timer all act on tap (`onEnded`), not on a hold — skip the
                // 300ms hold-to-record timer and the hold-drag-to-zoom entirely in that case.
                guard !freihandAn, !multiSnapAn else { return }
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
                if freihandAn || multiSnapAn {
                    ausloesen()
                    return
                }
                guard modus == .haltend else { return }
                modus = .ruhe
                if steuerung.nimmtVideoAuf {
                    steuerung.videoStoppen()
                    return
                }
                haltTask?.cancel()
                ausloesen()
            }
    }
}

/// Gallery pick → the same editor input as a camera capture: a video wins, else a decodable photo.
enum SnapGalerie {
    static func inhalt(videoURL: URL?, bildDaten: Data?) -> SnapInhalt? {
        if let videoURL { return .video(videoURL) }
        if let bildDaten, let bild = UIImage(data: bildDaten) { return .foto(bild) }
        return nil
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
    /// Z-R9 Multi-Snap: photos still waiting for their turn in the editor, after the one on screen.
    @State private var warteschlange: [SnapInhalt] = []

    var body: some View {
        switch schritt {
        case .kamera:
            SnapKameraView(
                onFoto: { schritt = .editor(.foto($0)) },
                onVideo: { schritt = .editor(.video($0)) },
                onMultiFoto: { bilder in
                    var inhalte = bilder.map(SnapInhalt.foto)
                    guard !inhalte.isEmpty else { return }
                    schritt = .editor(inhalte.removeFirst())
                    warteschlange = inhalte
                },
                onAbbrechen: onFertig
            )
        case .editor(let inhalt):
            // Never sent straight from the camera: the editor's send button is the only way out
            // that sends; its X goes back to the camera instead of closing everything. Multi-Snap:
            // "fertig" (sent, or the check-mark path) advances to the next queued photo instead of
            // closing the whole flow, until the queue is empty.
            SnapEditor(
                inhalt: inhalt, ich: ich, antwortAuf: antwortAuf,
                onFertig: naechstesAusWarteschlangeOderFertig,
                onVerwerfen: { warteschlange = []; schritt = .kamera }
            )
        }
    }

    private func naechstesAusWarteschlangeOderFertig() {
        guard !warteschlange.isEmpty else { onFertig(); return }
        schritt = .editor(warteschlange.removeFirst())
    }
}
