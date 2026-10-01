import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
@preconcurrency import MetalKit
import SwiftUI

/// R9 LIVE: reine Entscheidung hinter der Akku-Regel — der Live-Renderer darf nur rendern, wenn ein
/// Filter ungleich `.original` gewählt ist UND der zusätzliche `AVCaptureVideoDataOutput` erfolgreich
/// zur Session hinzugefügt werden konnte (siehe `KameraSitzung.liveFilterVerfuegbar` in
/// `SnapKamera.swift`). Kein Gerät/`AVFoundation` hier — pure Funktion, per XCTest ohne Simulator
/// testbar.
enum SnapLiveFilterEntscheidung {
    static func aktiv(filter: SnapFilter, ausgabeVerfuegbar: Bool) -> Bool {
        filter != .original && ausgabeVerfuegbar
    }
}

/// Threadsicherer Zustand zwischen der Aufnahme-Queue (liefert Frames, nicht der MainActor) und dem
/// Renderer (rendert auf dem MainActor) — gleiche Technik wie `KameraSitzung` oben in
/// `SnapKamera.swift`: eine `@unchecked Sendable`-Klasse mit eigenem Lock statt eines Captures über
/// die Aktor-Grenze.
private final class LiveFilterZustand: @unchecked Sendable {
    private let lock = NSLock()
    private var filter: SnapFilter = .original
    private var verarbeitetGerade = false

    func filterLesen() -> SnapFilter {
        lock.lock(); defer { lock.unlock() }
        return filter
    }

    func filterSetzen(_ neu: SnapFilter) {
        lock.lock(); filter = neu; lock.unlock()
    }

    /// Akku-Regel: ein Frame, während das vorige noch rendert, wird verworfen statt sich zu stauen.
    /// `alwaysDiscardsLateVideoFrames` (gesetzt in `KameraSitzung.konfigurieren`) greift nur, solange
    /// der Delegate-Aufruf selbst noch läuft — der eigentliche Render-Hop zum MainActor ist
    /// asynchron, AVFoundation hält den Delegate-Aufruf dafür nicht für "noch beschäftigt". Dieser
    /// Zustand übernimmt das Verwerfen selbst.
    func versucheZuStarten() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !verarbeitetGerade else { return false }
        verarbeitetGerade = true
        return true
    }

    func fertig() {
        lock.lock(); verarbeitetGerade = false; lock.unlock()
    }
}

/// `CVPixelBuffer` ist nicht offiziell `Sendable`, aber wie `SendableCGImage` in `SnapFilter.swift`
/// in der Praxis sicher, ein Frame einmal über die `captureOutput`→`Task { @MainActor }`-Grenze zu
/// reichen.
private struct SendablePixelBuffer: @unchecked Sendable {
    let puffer: CVPixelBuffer
}

/// R9 LIVE: besitzt die `MTKView` fürs Live-Filterbild + den `AVCaptureVideoDataOutput`-Pfad.
/// `@MainActor`, wie `SnapKameraSteuerung` — nur der Delegate-Callback ist `nonisolated` (Frames
/// kommen auf einer eigenen Aufnahme-Queue an, siehe `SnapKameraSteuerung`s gleiches Muster mit
/// `AVCapturePhotoCaptureDelegate`/`AVCaptureFileOutputRecordingDelegate`).
///
/// Akku-Regel: bei `.original` oder wenn die Session den Output nicht zulässt, ist der Delegate der
/// `AVCaptureVideoDataOutput` `nil` (keine Frames fließen) und die `MTKView` ist versteckt+pausiert
/// (`isPaused = true`, kein Display-Link). Gerendert wird ausschließlich innerhalb des
/// Delegate-Callbacks, also nur wenn tatsächlich ein neues Frame da ist — kein Timer, keine
/// Polling-Schleife.
@MainActor
final class SnapLiveFilterRenderer: NSObject {
    let mtkView: MTKView
    private let context: CIContext
    private let commandQueue: MTLCommandQueue?
    private let zustand = LiveFilterZustand()
    private var ausgabe: AVCaptureVideoDataOutput?
    private(set) var verfuegbar = false

    private static let aufnahmeSchlange = DispatchQueue(label: "lovea.snap.kamera.filter", qos: .userInteractive)

    override init() {
        let geraet = MTLCreateSystemDefaultDevice()
        let view = MTKView(frame: .zero, device: geraet)
        view.isPaused = true // kein Display-Link — gerendert wird manuell pro Frame, siehe oben
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = false // Core Image rendert direkt in die Drawable-Textur
        view.isHidden = true
        view.isUserInteractionEnabled = false
        mtkView = view
        commandQueue = geraet?.makeCommandQueue()
        context = geraet.map { CIContext(mtlDevice: $0) } ?? CIContext()
        super.init()
    }

    /// Wird nach jedem (Re-)Konfigurieren der Session aufgerufen (Kamera-Öffnen, Warmlaufen) —
    /// `ausgabe` ist `nil`, wenn `KameraSitzung.liveFilterVerfuegbar` false war (Fallback: kein
    /// Live-Filter, Karussell bleibt nutzbar). Wendet den zuletzt gewählten Filter gleich neu an,
    /// damit ein Wiederöffnen der Kamera mit demselben Filter weiterläuft.
    func einrichten(ausgabe: AVCaptureVideoDataOutput?) {
        self.ausgabe = ausgabe
        verfuegbar = ausgabe != nil
        anwenden(zustand.filterLesen())
    }

    /// Kamera verlässt den Bildschirm: Delegate weg, `MTKView` versteckt — der gewählte Filter
    /// bleibt im Zustand gemerkt (siehe `einrichten`), nur Rendern und Frame-Lieferung stoppen.
    func anhalten() {
        ausgabe?.setSampleBufferDelegate(nil, queue: nil)
        mtkView.isHidden = true
    }

    /// Aufruf aus dem Karussell/Wisch (`SnapKameraView`).
    func filterWaehlen(_ filter: SnapFilter) {
        zustand.filterSetzen(filter)
        anwenden(filter)
    }

    private func anwenden(_ filter: SnapFilter) {
        // `commandQueue == nil` nur denkbar, wenn `MTLCreateSystemDefaultDevice()` nichts liefert
        // (auf echten iOS-26-Geräten praktisch ausgeschlossen) — ohne die zusätzliche Bedingung
        // bliebe die (dann leere) `MTKView` trotzdem sichtbar und würde die echte Vorschau verdecken.
        let aktiv = SnapLiveFilterEntscheidung.aktiv(filter: filter, ausgabeVerfuegbar: verfuegbar) && commandQueue != nil
        mtkView.isHidden = !aktiv
        if aktiv {
            ausgabe?.setSampleBufferDelegate(self, queue: Self.aufnahmeSchlange)
        } else {
            ausgabe?.setSampleBufferDelegate(nil, queue: nil)
        }
    }

    // MARK: - Rendering

    @MainActor
    private func rendern(pixelPuffer: CVPixelBuffer) {
        let filter = zustand.filterLesen()
        guard filter != .original, !mtkView.isHidden,
              let commandQueue, let drawable = mtkView.currentDrawable,
              mtkView.drawableSize.width > 0, mtkView.drawableSize.height > 0
        else { return }
        // `video: true` wie die Video-Komposition im Export/Editor (kein Filmkorn-Flackern, siehe
        // `SnapFilter.anwenden`'s Doku). Mirroring/Rotation kommen schon korrekt an: dieselbe
        // `automaticallyAdjustsVideoMirroring` wie beim Film-Output spiegelt die Frontkamera, und
        // `KameraSitzung.liveFilterVerbindungAktualisieren` setzt dieselbe `videoRotationAngle = 90`
        // wie Foto/Film — das Pixelbuffer kommt also bereits aufrecht und seitenrichtig an.
        let basis = CIImage(cvPixelBuffer: pixelPuffer)
        let gefiltert = filter.anwenden(auf: basis, video: true)
        let passend = Self.aspectFillZugeschnitten(gefiltert, ziel: mtkView.drawableSize)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        context.render(passend, to: drawable.texture, commandBuffer: commandBuffer, bounds: passend.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Reine Geometrie hinter "derselbe Ausschnitt wie die Vorschau" (`resizeAspectFill` auf dem
    /// `AVCaptureVideoPreviewLayer`): skaliert `bild` so, dass es `ziel` randlos füllt, und schneidet
    /// mittig auf `ziel` zu. `internal` + `nonisolated`, nicht `private` — greift auf keinen
    /// Actor-Zustand zu, per XCTest ohne Metal/Gerät/MainActor-Hop prüfbar.
    nonisolated static func aspectFillZugeschnitten(_ bild: CIImage, ziel: CGSize) -> CIImage {
        guard bild.extent.width > 0, bild.extent.height > 0, ziel.width > 0, ziel.height > 0 else { return bild }
        let skala = max(ziel.width / bild.extent.width, ziel.height / bild.extent.height)
        let skaliert = bild.transformed(by: CGAffineTransform(scaleX: skala, y: skala))
        let x = skaliert.extent.minX + (skaliert.extent.width - ziel.width) / 2
        let y = skaliert.extent.minY + (skaliert.extent.height - ziel.height) / 2
        return skaliert.cropped(to: CGRect(x: x, y: y, width: ziel.width, height: ziel.height))
    }
}

extension SnapLiveFilterRenderer: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelPuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let zustand = zustand // Sendable, kein `self`-Capture über die Aktor-Grenze nötig
        guard zustand.versucheZuStarten() else { return } // vorheriges Frame rendert noch: dieses verwerfen
        let huelle = SendablePixelBuffer(puffer: pixelPuffer)
        Task { @MainActor [weak self] in
            defer { zustand.fertig() }
            self?.rendern(pixelPuffer: huelle.puffer)
        }
    }
}

/// `MTKView` über dem `AVCaptureVideoPreviewLayer` (Z-R9 LIVE) — nimmt nie selbst Touches entgegen
/// (`isUserInteractionEnabled = false` oben, `.allowsHitTesting(false)` an der Aufrufstelle), damit
/// Pinch-Zoom und der Filter-Wisch weiter auf dem darunterliegenden Kamerabild landen.
struct KameraLiveFilterVorschau: UIViewRepresentable {
    let mtkView: MTKView

    func makeUIView(context: Context) -> MTKView { mtkView }
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

/// Filter-Karussell auf Höhe des Auslösers (Z-R9 LIVE): der Auslöser liegt in `SnapKameraView.untereLeiste`
/// als eigene Ebene über diesem Karussell, sodass er optisch mittig bleibt; der dort zentrierte Chip
/// (`.scrollPosition(id:anchor:.center)`, dieselbe einrastende `.viewAligned`-Mechanik wie
/// `SnapEditor`s eigenes Karussell) liegt direkt dahinter. Chips sind reine Text-Kreise statt
/// gerenderter Thumbnails — ein Live-Rendering aller 15 Filter gleichzeitig widerspräche der
/// Akku-Regel (gerendert wird immer nur der eine gewählte Filter).
struct KameraFilterKarussell: View {
    let ausgewaehlt: SnapFilter
    @Binding var scrollID: SnapFilter?
    let onWahl: (SnapFilter) -> Void

    static let chipGroesse: CGFloat = 46

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(SnapFilter.allCases) { filter in
                        chip(filter).id(filter)
                    }
                }
                .scrollTargetLayout()
                .safeAreaPadding(.horizontal, max(0, (geo.size.width - Self.chipGroesse) / 2))
            }
            .scrollPosition(id: $scrollID, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: Self.chipGroesse + 6)
    }

    private func chip(_ filter: SnapFilter) -> some View {
        let ist = filter == ausgewaehlt
        return Button { onWahl(filter) } label: {
            ZStack {
                Circle().fill(.black.opacity(0.35))
                Text(filter.anzeigename)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
            .frame(width: Self.chipGroesse, height: Self.chipGroesse)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: ist ? 3 : 1))
            .scaleEffect(ist ? 1.12 : 1)
        }
        .animation(.easeInOut(duration: 0.15), value: ist)
        .accessibilityLabel(filter.anzeigename)
        .accessibilityAddTraits(ist ? .isSelected : [])
    }
}
