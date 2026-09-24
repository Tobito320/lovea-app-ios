import AVFoundation
import AVKit
import CoreMedia
import ImageIO
import SwiftUI
import UIKit

/// Photo/video in the chat (Z-5.1, Z-33.4): "wird geladen" until the file is local, then the
/// picture without a bubble, at most 240 pt tall and 70 % wide. Taller than 3:4 shows a 3:4 window
/// from the top with a "ganzes Bild" hint. Tap zooms into the full-screen viewer; swiping down
/// zooms back into the bubble. Save/reply live in the long-press menu.
struct MedienNachrichtView: View {
    let medium: ChatModell.MedienEintrag
    let eigene: Bool

    @State private var localURL: URL?
    @State private var vollbild = false
    @Namespace private var zoomRaum
    @Environment(\.chatBreite) private var chatBreite

    private var istVideo: Bool { medium.typ == "video" }
    private var beschnitten: Bool { Self.istHoch(breite: medium.breite, hoehe: medium.hoehe) }

    var body: some View {
        Group {
            if let localURL {
                // A tap gesture, not a Button: a Button inside the bubble would swallow the long press.
                MedienVorschau(url: localURL, istVideo: istVideo, oben: beschnitten)
                    .overlay(alignment: .bottomLeading) { if beschnitten { ganzesBildHinweis } }
                    .contentShape(.rect)
                    .onTapGesture {
                        guard !LangDruck.geradeEben else { return }
                        Haptik.leicht()
                        vollbild = true
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(istVideo ? "Video" : "Foto")
                    .accessibilityHint("Im Vollbild öffnen")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { vollbild = true }
                    .matchedTransitionSource(id: medium.id, in: zoomRaum)
                    .fullScreenCover(isPresented: $vollbild) {
                        MedienVollbild(url: localURL, istVideo: istVideo, eigene: eigene)
                            .navigationTransition(.zoom(sourceID: medium.id, in: zoomRaum))
                    }
            } else {
                LadePlatzhalter(istVideo: istVideo)
            }
        }
        .frame(width: groesse.width, height: groesse.height)
        .clipShape(.rect(cornerRadius: 18))
        .task(id: medium.id) { if let gefunden = await MedienDatei.url(medium, eigene: eigene) { localURL = gefunden } }
    }

    private var ganzesBildHinweis: some View {
        Label("ganzes Bild", systemImage: "arrow.up.left.and.arrow.down.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55), in: .capsule)
            .padding(8)
            .accessibilityHidden(true)
    }

    private var groesse: CGSize {
        Self.bildGroesse(breite: medium.breite, hoehe: medium.hoehe, maxBreite: chatBreite * 0.7)
    }

    /// Taller than 3:4 (portrait screenshots, long scrolls).
    nonisolated static func istHoch(breite: Double, hoehe: Double) -> Bool {
        breite > 0 && hoehe / breite > 4.0 / 3.0
    }

    /// Pure geometry: fits the picture into maxBreite × maxHoehe; a tall one counts as 3:4 (the
    /// view crops from the top), a very wide one keeps `minSeite` height (the view crops the sides).
    nonisolated static func bildGroesse(breite: Double, hoehe: Double, maxBreite: CGFloat, maxHoehe: CGFloat = 240, minSeite: CGFloat = 120) -> CGSize {
        guard breite > 0, hoehe > 0 else { return CGSize(width: maxBreite, height: maxHoehe) }
        let verhaeltnis: CGFloat = istHoch(breite: breite, hoehe: hoehe) ? 0.75 : CGFloat(breite / hoehe)
        var b = maxBreite
        var h = b / verhaeltnis
        if h > maxHoehe {
            h = maxHoehe
            b = h * verhaeltnis
        }
        return CGSize(width: max(b, minSeite), height: max(h, minSeite))
    }
}

/// Where a chat medium's file is, waiting for it if needed.
@MainActor
enum MedienDatei {
    /// Retries while the caller's `.task(id:)` runs (it cancels when the row scrolls away and
    /// restarts when it reappears) — never caches a failed attempt as final, Review-Fokus #5.
    static func url(_ medium: ChatModell.MedienEintrag, eigene: Bool) async -> URL? {
        if eigene, let quelle = ChatMedien.eigeneQuellen[medium.id] { return quelle }
        if let vorhanden = Medien.lokal(medium.id) { return vorhanden }
        while !Task.isCancelled {
            if let geholt = try? await Medien.holen(medium.id) { return geholt }
            try? await Task.sleep(for: .seconds(5))
        }
        return nil
    }

    /// Already-local file only (for menu actions that must not wait).
    static func lokal(_ medium: ChatModell.MedienEintrag) -> URL? {
        ChatMedien.eigeneQuellen[medium.id] ?? Medien.lokal(medium.id)
    }
}

/// Bare thumbnail of one medium (photo stack cards, Block 18): no button, no viewer.
struct MedienKachel: View {
    let medium: ChatModell.MedienEintrag
    let eigene: Bool
    @State private var url: URL?

    var body: some View {
        ZStack {
            if let url {
                MedienVorschau(url: url, istVideo: medium.typ == "video")
            } else {
                Rectangle().fill(.thinMaterial)
                ProgressView()
            }
        }
        .task(id: medium.id) { if let gefunden = await MedienDatei.url(medium, eigene: eigene) { url = gefunden } }
    }
}

private struct LadePlatzhalter: View {
    let istVideo: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(.thinMaterial)
            VStack(spacing: 6) {
                ProgressView()
                Text("wird geladen").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .topLeading) {
            if istVideo {
                Image(systemName: "video.fill").font(.caption).padding(6).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MedienVorschau: View {
    let url: URL
    let istVideo: Bool
    /// Crop anchored at the top (tall pictures, Z-33.4) instead of the centre.
    var oben = false
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            if let bild {
                Color.clear
                    .overlay(alignment: oben ? .top : .center) {
                        Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            } else {
                Rectangle().fill(.thinMaterial)
            }
            if istVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
        }
        .task(id: url) {
            bild = istVideo ? await Videobild.erstesBild(url) : await Bilddatei.laden(url, maxPixel: 700)
        }
    }
}

/// Fullscreen viewer (Z-5.1, Z-33.4): pinch and double tap zoom, pan while zoomed, swipe down
/// closes (the zoom transition carries it back into the bubble), `VideoPlayer` for videos.
private struct MedienVollbild: View {
    let url: URL
    let istVideo: Bool
    let eigene: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var versatz: CGSize = .zero
    @State private var versatzStart: CGSize = .zero
    @State private var zieh: CGFloat = 0
    @State private var bild: UIImage?
    /// Held in state: a player built in `body` restarted the video on every redraw.
    @State private var spieler: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(zieh / 400, 0.6)).ignoresSafeArea()
            if let spieler {
                VideoPlayer(player: spieler).ignoresSafeArea().offset(y: zieh)
            } else if let bild {
                foto(bild)
            } else {
                ProgressView().tint(.white)
            }
        }
        .simultaneousGesture(ziehGeste)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityLabel("Schließen")
                .padding()
                .opacity(zieh > 0 ? 0 : 1)
        }
        .interactiveDismissDisabled(zoom > 1)
        .statusBarHidden()
        .screenshotKontext(.medium(video: istVideo, eigen: eigene))
        .task {
            if istVideo { spieler = AVPlayer(url: Videobild.abspielbar(url)) } else { bild = await Bilddatei.laden(url) }
            FigurenModell.shared.zustandSenden(.init(haupt: istVideo ? .schautVideo : .schautBild))
        }
        .onDisappear {
            spieler?.pause()
            FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
        }
    }

    private func foto(_ bild: UIImage) -> some View {
        Image(uiImage: bild)
            .resizable()
            .scaledToFit()
            .scaleEffect(zoom)
            .offset(x: versatz.width, y: versatz.height + zieh)
            .gesture(
                MagnifyGesture()
                    .onChanged { wert in zoom = min(max(zoomStart * wert.magnification, 1), 4) }
                    .onEnded { _ in
                        zoomStart = zoom
                        if zoom < 1.05 { zuruecksetzen() }
                    }
            )
            .onTapGesture(count: 2) {
                Haptik.leicht()
                if zoom > 1 { zuruecksetzen() } else { withAnimation(Feder.federnd) { zoom = 2.5; zoomStart = 2.5 } }
            }
            .accessibilityLabel("Foto")
    }

    /// Zoomed in: pans the photo. Not zoomed: drags the viewer down, far enough closes it.
    private var ziehGeste: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { wert in
                if zoom > 1 {
                    versatz = CGSize(width: versatzStart.width + wert.translation.width, height: versatzStart.height + wert.translation.height)
                } else if wert.translation.height > 0, wert.translation.height > abs(wert.translation.width) {
                    zieh = wert.translation.height
                }
            }
            .onEnded { _ in
                if zoom > 1 {
                    versatzStart = versatz
                } else if zieh > 120 {
                    Haptik.leicht()
                    dismiss()
                } else {
                    withAnimation(Feder.schnell) { zieh = 0 }
                }
            }
    }

    private func zuruecksetzen() {
        withAnimation(Feder.weich) {
            zoom = 1
            zoomStart = 1
            versatz = .zero
            versatzStart = .zero
        }
    }
}

/// First-frame thumbnail for a local video file, off the main actor.
enum Videobild {
    /// AVFoundation picks the container parser from the file extension, and cached media have none
    /// (`Medien.cacheURL`), so a received video loaded as nothing: black poster, black player.
    /// Returns a `.mov` hard link next to such a file (instant, no copy); anything else unchanged.
    static func abspielbar(_ url: URL) -> URL {
        guard url.pathExtension.isEmpty else { return url }
        let link = url.appendingPathExtension("mov")
        if !FileManager.default.fileExists(atPath: link.path) { try? FileManager.default.linkItem(at: url, to: link) }
        return FileManager.default.fileExists(atPath: link.path) ? link : url
    }

    static func erstesBild(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: Videobild.abspielbar(url)))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 700, height: 700)
            guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

/// Decodes an image file off the main actor (Z-16.2). ImageIO downsamples to `maxPixel` on the long
/// edge (never upscales), so a chat bubble never decodes a 12 MP camera original on the main thread.
/// Small previews are cached, so scrolling back up doesn't flash placeholders.
enum Bilddatei {
    // ponytail: `NSCache` is documented thread-safe, just not `Sendable`.
    nonisolated(unsafe) private static let vorschauen: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        return cache
    }()

    static func laden(_ url: URL, maxPixel: Int = 4096) async -> UIImage? {
        let schluessel = "\(url.path)#\(maxPixel)" as NSString
        if let bild = vorschauen.object(forKey: schluessel) { return bild }
        let bild = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let quelle = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(quelle, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceShouldCacheImmediately: true,
                      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  ] as CFDictionary)
            else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
        if let bild, maxPixel <= 1024 { vorschauen.setObject(bild, forKey: schluessel) }
        return bild
    }
}

/// "In Galerie speichern" (Z-5.5): imports a received photo as a new drawing with an image layer.
@MainActor
enum ChatGalerie {
    // ponytail: a fresh `ArtworkLibrary()` pointed at its default Application Support folder — the
    // same file on disk Drawing's own `@StateObject ArtworkLibrary` uses, so this survives and shows
    // up there. `DrawingView` reloads that instance on `.artworkLibraryGeaendert` (Brief I.4), so an
    // already-open Zeichnen tab picks this up without a restart.
    static func inGaleriesSpeichern(bildURL: URL) {
        Task {
            guard await speichernUndWarten(bildURL: bildURL, name: "Aus dem Chat") else { return }
            NotificationCenter.default.post(name: .artworkLibraryGeaendert, object: nil)
        }
    }

    /// Awaitable variant (Z-26.4's umzug cleanup needs to know the write finished before deleting
    /// the chat message it came from). `true` once the artwork is fully on disk. `library` lets a
    /// batch caller (Z-26.4) reuse one instance instead of paying `ArtworkLibrary.init`'s
    /// synchronous library.json/document.json reads (Main Thread frei) once per message.
    static func speichernUndWarten(bildURL: URL, name: String, library: ArtworkLibrary? = nil) async -> Bool {
        // Decode + PNG encode off the main actor (Z-16.2); only the library calls stay on it.
        let geladen = await Task.detached(priority: .userInitiated) { () -> (png: Data, breite: Double, hoehe: Double)? in
            guard let image = UIImage(contentsOfFile: bildURL.path), let png = image.pngData() else { return nil }
            return (png, Double(image.size.width * image.scale), Double(image.size.height * image.scale))
        }.value
        guard let geladen else { return false }
        let library = library ?? ArtworkLibrary()
        let breite = ArtworkLibrary.clampDimension(geladen.breite)
        let hoehe = ArtworkLibrary.clampDimension(geladen.hoehe)
        var artwork = library.createArtwork(name: name, projectID: nil, format: .custom, customWidth: breite, customHeight: hoehe, background: .white)
        let bildEbene = ArtworkLayer.image(name: "Bild")
        artwork.layers.append(bildEbene)
        library.saveLayerData(geladen.png, layer: bildEbene, artworkID: artwork.id)
        library.saveDocument(artwork)
        await library.waitForWrites()
        return true
    }
}
