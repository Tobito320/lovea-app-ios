import AVFoundation
import AVKit
import CoreMedia
import ImageIO
import SwiftUI
import UIKit

/// Photo/video bubble content (Z-5.1): "wird geladen" placeholder until the file is local, then a
/// thumbnail that opens a fullscreen zoomable/playable viewer. "In Galerie speichern" (Z-5.5) lives
/// in the bubble's long-press menu (`ChatNachrichtRow`) together with reply/react.
struct MedienNachrichtView: View {
    let medium: ChatModell.MedienEintrag
    let eigene: Bool

    @State private var localURL: URL?
    @State private var vollbild = false

    var body: some View {
        Group {
            if let localURL {
                Button { vollbild = true } label: {
                    MedienVorschau(url: localURL, istVideo: medium.typ == "video")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(medium.typ == "video" ? "Video" : "Foto")
                .accessibilityHint("Im Vollbild öffnen")
                .fullScreenCover(isPresented: $vollbild) {
                    MedienVollbild(url: localURL, istVideo: medium.typ == "video")
                }
            } else {
                LadePlatzhalter(istVideo: medium.typ == "video")
            }
        }
        .frame(width: 220, height: medium.hoehe > 0 ? 220 * medium.hoehe / max(medium.breite, 1) : 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: medium.id) { if let gefunden = await MedienDatei.url(medium, eigene: eigene) { localURL = gefunden } }
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
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            if let bild {
                Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
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

/// Fullscreen viewer (Z-5.1): pinch/drag zoom for photos, `VideoPlayer` for videos.
private struct MedienVollbild: View {
    let url: URL
    let istVideo: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var zoom = 1.0
    @State private var versatz: CGSize = .zero
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if istVideo {
                VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            } else if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .offset(versatz)
                    .gesture(MagnificationGesture().onChanged { zoom = max(1, $0) })
                    .gesture(DragGesture().onChanged { if zoom > 1 { versatz = $0.translation } })
                    .onTapGesture(count: 2) { withAnimation { zoom = zoom > 1 ? 1 : 2; versatz = .zero } }
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityLabel("Schließen")
                .padding()
        }
        .task {
            if !istVideo { bild = await Bilddatei.laden(url) }
            FigurenModell.shared.zustandSenden(.init(haupt: istVideo ? .schautVideo : .schautBild))
        }
        .onDisappear { FigurenModell.shared.zustandSenden(.init(haupt: .imChat)) }
    }
}

/// First-frame thumbnail for a local video file, off the main actor.
enum Videobild {
    static func erstesBild(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
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
    // ponytail: same reasoning as `AnimiertesGifCache`, `NSCache` is documented thread-safe, just not `Sendable`.
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
    // up there. That tab's already-open instance won't refresh until it re-`load()`s though — Chat
    // doesn't own Drawing/**, so this is reported instead of fixed here.
    static func inGaleriesSpeichern(bildURL: URL) {
        Task {
            // Decode + PNG encode off the main actor (Z-16.2); only the library calls stay on it.
            let geladen = await Task.detached(priority: .userInitiated) { () -> (png: Data, breite: Double, hoehe: Double)? in
                guard let image = UIImage(contentsOfFile: bildURL.path), let png = image.pngData() else { return nil }
                return (png, Double(image.size.width * image.scale), Double(image.size.height * image.scale))
            }.value
            guard let geladen else { return }
            speichern(png: geladen.png, pixelBreite: geladen.breite, pixelHoehe: geladen.hoehe)
        }
    }

    private static func speichern(png: Data, pixelBreite: Double, pixelHoehe: Double) {
        let library = ArtworkLibrary()
        let breite = ArtworkLibrary.clampDimension(pixelBreite)
        let hoehe = ArtworkLibrary.clampDimension(pixelHoehe)
        var artwork = library.createArtwork(name: "Aus dem Chat", projectID: nil, format: .custom, customWidth: breite, customHeight: hoehe, background: .white)
        let bildEbene = ArtworkLayer.image(name: "Bild")
        artwork.layers.append(bildEbene)
        library.saveLayerData(png, layer: bildEbene, artworkID: artwork.id)
        library.saveDocument(artwork)
    }
}
